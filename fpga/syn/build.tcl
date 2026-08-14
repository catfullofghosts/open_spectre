# Open Spec — Vivado incremental project build (Windows / batch-friendly)
#
# Reuses an existing project, BD, PS, and OOC IP runs when possible.
# Only sources that changed (typically RTL VHDL) trigger synth/impl refresh.
#
# Run:
#   vivado -mode batch -source build.tcl -tclargs synth
#   vivado -mode batch -source build.tcl -tclargs route
#   vivado -mode batch -source build.tcl -tclargs bitstream
#   vivado -mode batch -source build.tcl -tclargs all
#   vivado -mode batch -source build.tcl -tclargs clean
#   (skip_impl is accepted as an alias for synth)

# -----------------------------------------------------------------------------
# Build settings
# -----------------------------------------------------------------------------
# NOTE: do not use the name "design_name" here — hdmi_in.tcl declares
# `variable design_name` and will fail if that name already exists.
set bd_name        "hdmi_in"
set top_name       "hdmi_in_wrapper"
set fpga_part      "xc7z020clg400-1"
set jobs           4

set script_dir [file normalize [file dirname [info script]]]
set fpga_dir   [file normalize [file join $script_dir ".."]]

set bd_tcl         [file normalize [file join $script_dir "hdmi_in.tcl"]]
set xdc_file       [file normalize [file join $script_dir "open_spec.xdc"]]
set vhdl_src_tcl   [file normalize [file join $script_dir "vhdl_sources.tcl"]]
set build_dir      [file normalize [file join $script_dir "build"]]
set project_name   "open_spec"
set project_dir    [file normalize [file join $build_dir $project_name]]
set project_file   [file normalize [file join $project_dir "${project_name}.xpr"]]
set bitstream_out  [file normalize [file join $build_dir "${bd_name}.bit"]]
set xsa_out        [file normalize [file join $build_dir "${bd_name}.xsa"]]

# Args: clean | synth | route | bitstream | all
#   synth     - stop after synthesis
#   route     - stop after route_design
#   bitstream - write bitstream (no XSA)
#   all       - bitstream + export fixed XSA (default)
set build_stage "all"
set do_clean    0
foreach arg $argv {
  switch -- $arg {
    clean       { set do_clean 1 }
    synth       -
    skip_impl   { set build_stage "synth" }
    route       { set build_stage "route" }
    bitstream   { set build_stage "bitstream" }
    all         -
    full        { set build_stage "all" }
    default {
      puts "WARNING: unknown arg '$arg' (ignored)"
    }
  }
}

puts "============================================================"
puts " Open Spec Vivado build (incremental)"
puts "  part      : $fpga_part"
puts "  BD script : $bd_tcl"
puts "  XDC       : $xdc_file"
puts "  VHDL list : $vhdl_src_tcl"
puts "  project   : $project_dir"
puts "  stage     : $build_stage"
puts "  clean     : $do_clean"
puts "============================================================"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
proc open_spec_find_bd {bd_name} {
  set bd_file [get_files -quiet ${bd_name}.bd]
  if {$bd_file eq ""} {
    set bd_file [lindex [get_files -quiet *.bd] 0]
  }
  return $bd_file
}

proc open_spec_bd_cell_count {bd_file} {
  if {$bd_file eq "" || ![file exists $bd_file]} {
    return 0
  }
  set cur [current_bd_design -quiet]
  if {$cur ne ""} {
    catch {close_bd_design $cur}
  }
  if {[catch {open_bd_design $bd_file} err]} {
    puts "WARNING: could not open BD ($err)"
    return 0
  }
  return [llength [get_bd_cells -quiet]]
}

proc open_spec_remove_bd {bd_name bd_file} {
  puts "Removing incomplete block design: $bd_file"
  catch {close_bd_design [current_bd_design -quiet]}
  catch {export_ip_user_files -of_objects [get_files $bd_file] -no_script -reset -force -quiet}
  catch {remove_files [get_files -quiet ${bd_name}.bd]}
  catch {remove_files [get_files -quiet "*${bd_name}_wrapper*"]}

  set bd_dir [file dirname $bd_file]
  # .../open_spec.srcs/sources_1/bd/hdmi_in -> project root is 4 levels up
  set proj_root [file normalize [file join $bd_dir ".." ".." ".." ".."]]
  set proj_name [file tail $proj_root]
  set gen_dir [file normalize [file join $proj_root "${proj_name}.gen" "sources_1" "bd" $bd_name]]
  if {[file isdirectory $gen_dir]} {
    puts "Removing generated BD tree: $gen_dir"
    file delete -force $gen_dir
  }
  if {[file exists $bd_file]} {
    file delete -force $bd_file
  }
  if {[file isdirectory $bd_dir]} {
    catch {file delete -force $bd_dir}
  }
}

proc open_spec_wrapper_ok {top_name} {
  set wrappers [get_files -quiet "*${top_name}*"]
  if {[llength $wrappers] == 0} {
    return 0
  }
  set wrapper_path [lindex $wrappers 0]
  if {![file exists $wrapper_path]} {
    return 0
  }
  set fh [open $wrapper_path r]
  set text [read $fh]
  close $fh
  # Stub wrappers look like: entity <top> is / end <top>;  (no port list)
  if {[regexp -nocase [format {entity\s+%s\s+is\s+end} $top_name] $text]} {
    return 0
  }
  if {![regexp -nocase {port\s*\(} $text]} {
    return 0
  }
  return 1
}

proc open_spec_create_bd {bd_tcl bd_name} {
  puts "Creating block design from $bd_tcl ..."
  # Preflight: module ref used by the BD must resolve
  if {[can_resolve_reference spector_wrapper_zynq] == 0} {
    puts "ERROR: module reference 'spector_wrapper_zynq' is not in the project sources."
    puts "  Ensure fpga/src VHDL was added before creating the BD."
    return ""
  }

  # hdmi_in.tcl does `variable design_name` — must not already exist in this scope
  catch {unset design_name}

  set rc 0
  if {[catch {set rc [source $bd_tcl]} err]} {
    puts "ERROR: sourcing BD Tcl failed: $err"
    return ""
  }
  # Exported BD scripts often `return 3` after creating an empty BD when IP/module checks fail
  if {$rc ne "" && $rc != 0} {
    puts "ERROR: $bd_tcl returned status $rc (IP/module checks likely failed)."
    puts "  An empty BD may have been left behind; build will refuse to continue."
    return ""
  }

  set bd_file [open_spec_find_bd $bd_name]
  if {$bd_file eq ""} {
    puts "ERROR: block design ${bd_name}.bd was not created."
    return ""
  }
  set ncells [open_spec_bd_cell_count $bd_file]
  puts "BD cell count after create: $ncells"
  if {$ncells < 5} {
    puts "ERROR: block design is empty/incomplete ($ncells cells)."
    puts "  Usually hdmi_in.tcl failed Digilent IP or module-ref checks"
    puts "  before create_root_design populated the design."
    return ""
  }
  foreach cell {processing_system7_0 spector_wrapper_zynq_0} {
    if {[get_bd_cells -quiet $cell] eq ""} {
      puts "ERROR: expected BD cell missing: $cell"
      return ""
    }
  }
  return $bd_file
}

# -----------------------------------------------------------------------------
# Digilent IP repo (dvi2rgb / rgb2dvi / axi_dynclk)
# -----------------------------------------------------------------------------
set digilent_ip_repo ""
set default_ip_repo [file normalize [file join $fpga_dir "deps" "vivado-library"]]
if {[info exists ::env(DIGILENT_IP_REPO)] && $::env(DIGILENT_IP_REPO) ne ""} {
  set digilent_ip_repo [file normalize $::env(DIGILENT_IP_REPO)]
} elseif {[file isdirectory $default_ip_repo]} {
  set digilent_ip_repo $default_ip_repo
} elseif {[file isdirectory "C:/vivado-library"]} {
  set digilent_ip_repo [file normalize "C:/vivado-library"]
}

if {$digilent_ip_repo eq "" || ![file isdirectory $digilent_ip_repo]} {
  puts "ERROR: Digilent IP repo not found."
  puts "  Clone https://github.com/Digilent/vivado-library"
  puts "  then set DIGILENT_IP_REPO to that folder before running."
  exit 1
}
puts "  IP repo   : $digilent_ip_repo"

foreach req [list $bd_tcl $xdc_file $vhdl_src_tcl] {
  if {![file exists $req]} {
    puts "ERROR: required file missing: $req"
    if {$req eq $vhdl_src_tcl} {
      puts "  Run: python gen_vhdl_sources.py"
    }
    exit 1
  }
}

file mkdir $build_dir
cd $build_dir

# -----------------------------------------------------------------------------
# Open existing project, or create once
# -----------------------------------------------------------------------------
if {$do_clean && [file exists $project_dir]} {
  puts "clean: removing project directory $project_dir"
  catch {close_project}
  file delete -force $project_dir
}

if {[file exists $project_file]} {
  puts "Opening existing project: $project_file"
  open_project $project_file
} else {
  puts "Creating new project: $project_dir"
  create_project $project_name $project_dir -part $fpga_part -force
}

# Part-only (no Digilent board files required)
set_property target_language VHDL [current_project]
set_property default_lib work [current_project]
set_property part $fpga_part [current_project]

set_property ip_repo_paths $digilent_ip_repo [current_project]
update_ip_catalog -rebuild

# -----------------------------------------------------------------------------
# Refresh RTL VHDL list (add new / set FILE_TYPE; does not touch BD/IP)
# -----------------------------------------------------------------------------
puts "Refreshing VHDL sources..."
source $vhdl_src_tcl
update_compile_order -fileset sources_1

# Module-ref OOC scripts bake in read_vhdl [-vhdl2008] at generation time.
# Always reset the spector OOC run after refreshing FILE_TYPE so the child
# script is regenerated from current project properties.
foreach r [get_runs -quiet "*spector_wrapper*_synth_1"] {
  puts "Resetting module-ref OOC run: [get_property NAME $r]"
  catch {reset_run $r}
}

# -----------------------------------------------------------------------------
# Block design: reuse only if populated; recreate stub/empty BD
# -----------------------------------------------------------------------------
set bd_rebuilt 0
set bd_file [open_spec_find_bd $bd_name]

if {$bd_file ne ""} {
  set ncells [open_spec_bd_cell_count $bd_file]
  puts "Found BD: $bd_file ($ncells cells)"
  if {$ncells < 5} {
    puts "WARNING: existing BD is empty/incomplete — recreating"
    open_spec_remove_bd $bd_name $bd_file
    set bd_file ""
  }
}

if {$bd_file eq ""} {
  set bd_file [open_spec_create_bd $bd_tcl $bd_name]
  if {$bd_file eq ""} {
    exit 1
  }
  set bd_rebuilt 1
} else {
  puts "Reusing populated block design: $bd_file"
}

# Wrapper / generate_target: rebuild if missing OR stub (empty ports)
set bd_obj [get_files $bd_file]
set need_gen 0
if {![open_spec_wrapper_ok $top_name]} {
  set need_gen 1
}
if {$bd_rebuilt} {
  set need_gen 1
}

if {$need_gen} {
  puts "Generating BD targets + HDL wrapper..."
  generate_target all $bd_obj
  # Remove any stub wrapper files first
  foreach w [get_files -quiet "*${top_name}*"] {
    catch {remove_files $w}
  }
  set wrapper_file [make_wrapper -files $bd_obj -top]
  add_files -norecurse $wrapper_file
  if {![open_spec_wrapper_ok $top_name]} {
    puts "ERROR: hdmi_in_wrapper is still a stub (no ports)."
    puts "  BD was not fully generated. Inspect $bd_file in Vivado."
    exit 1
  }
  puts "Wrapper OK: [lindex [get_files -quiet "*${top_name}*"] 0]"
} else {
  puts "BD wrapper already valid — skipping generate_target"
}

set_property top $top_name [current_fileset]
update_compile_order -fileset sources_1

# Digilent rgb2dvi/dvi2rgb: disable OOC if possible, and always re-assert
# after generate_target (which can recreate IP runs).
update_ip_catalog -rebuild
foreach ip [get_ips -quiet {*rgb2dvi* *dvi2rgb*}] {
  puts "Regenerating Digilent IP: $ip"
  catch {reset_target all $ip}
  catch {generate_target -force all $ip}
}
# Re-copy component-style Digilent sources after generate_target (may overwrite)
catch {exec python [file join $script_dir "patch_digilent_ip.py"] \
  --repo $digilent_ip_repo \
  --project [get_property DIRECTORY [current_project]]}

foreach xci [get_files -quiet *.xci] {
  set xn [string tolower $xci]
  if {[string match *rgb2dvi* $xn] || [string match *dvi2rgb* $xn]} {
    catch {set_property generate_synth_checkpoint false $xci}
    puts "generate_synth_checkpoint([file tail $xci])=[get_property generate_synth_checkpoint $xci]"
  }
}
foreach f [get_files -quiet {
  */OutputSERDES.vhd */TMDS_Encoder.vhd */DVI_Constants.vhd
  */rgb2dvi.vhd */dvi2rgb.vhd */ClockGen.vhd */SyncAsync*.vhd */TMDS_*.vhd
}] {
  catch {set_property LIBRARY work $f}
}
foreach r [get_runs -quiet "*rgb2dvi*_synth_1"] {
  puts "Deleting Digilent OOC run: [get_property NAME $r]"
  catch {delete_runs $r}
}
foreach r [get_runs -quiet "*dvi2rgb*_synth_1"] {
  puts "Deleting Digilent OOC run: [get_property NAME $r]"
  catch {delete_runs $r}
}

# If we just rebuilt BD/wrapper, force top-level runs to refresh
if {$bd_rebuilt || $need_gen} {
  puts "BD/wrapper changed — marking synth/impl for refresh"
  foreach r {synth_1 impl_1} {
    if {[llength [get_runs -quiet $r]] > 0} {
      catch {reset_run $r}
    }
  }
}

# -----------------------------------------------------------------------------
# Constraints (add once)
# -----------------------------------------------------------------------------
if {[llength [get_files -quiet $xdc_file]] == 0} {
  puts "Adding constraints: $xdc_file"
  add_files -fileset constrs_1 -norecurse $xdc_file
}
set_property target_constrs_file $xdc_file [current_fileset -constrset]

# -----------------------------------------------------------------------------
# Synthesis — launch only if stale; never touch OOC/IP runs explicitly
# -----------------------------------------------------------------------------
set synth_run [get_runs synth_1]
set synth_needs [get_property NEEDS_REFRESH $synth_run]
set synth_prog  [get_property PROGRESS $synth_run]
set synth_status [get_property STATUS $synth_run]

puts "synth_1: STATUS=$synth_status PROGRESS=$synth_prog NEEDS_REFRESH=$synth_needs"

if {$synth_prog eq "100%" && !$synth_needs} {
  puts "Synthesis up to date — skipping synth_1 (OOC/PS left untouched)"
} else {
  puts "Launching synthesis ($jobs jobs)..."
  # Work from the project directory so OOC child runs resolve the .xpr
  cd [get_property DIRECTORY [current_project]]

  # Parent -nolog/-nojournal leaves OOC rundef.js with empty -log/-source.
  # Repair only those corrupted runs; leave healthy OOC DCPs alone.
  foreach r [get_runs -filter {IS_SYNTHESIS == 1}] {
    set rname [get_property NAME $r]
    if {$rname eq "synth_1"} { continue }
    set rd [file join [get_property DIRECTORY $r] "rundef.js"]
    if {![file exists $rd]} { continue }
    set fh [open $rd r]
    set txt [read $fh]
    close $fh
    if {[string match "*-log  -m64*" $txt] || [string match "*-source \" *" $txt] || [regexp -- {-source\s*"\s*\)} $txt]} {
      puts "Repairing corrupted OOC run scripts: $rname"
      catch {reset_run $r}
    }
  }

  reset_run synth_1

  # launch_runs can recreate Digilent OOC children; disable + delete again first
  foreach xci [get_files -quiet *.xci] {
    set xn [string tolower $xci]
    if {[string match *rgb2dvi* $xn] || [string match *dvi2rgb* $xn]} {
      catch {set_property generate_synth_checkpoint false $xci}
    }
  }
  foreach r [get_runs -quiet "*rgb2dvi*_synth_1"] { catch {delete_runs $r} }
  foreach r [get_runs -quiet "*dvi2rgb*_synth_1"] { catch {delete_runs $r} }

  launch_runs synth_1 -jobs $jobs
  wait_on_run synth_1

  if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: synthesis failed. See run log under $project_dir"
    exit 1
  }
  puts "Synthesis complete."
}

if {$build_stage eq "synth"} {
  puts "stage=synth — stopping after synthesis."
  exit 0
}

# -----------------------------------------------------------------------------
# Implementation — route and/or bitstream
# -----------------------------------------------------------------------------
set impl_run [get_runs impl_1]
set impl_needs [get_property NEEDS_REFRESH $impl_run]
set impl_prog  [get_property PROGRESS $impl_run]
set impl_status [get_property STATUS $impl_run]

puts "impl_1: STATUS=$impl_status PROGRESS=$impl_prog NEEDS_REFRESH=$impl_needs"

if {$build_stage eq "route"} {
  set impl_to_step "route_design"
} else {
  set impl_to_step "write_bitstream"
}

set bit_candidates [glob -nocomplain \
  [file join $project_dir "${project_name}.runs" "impl_1" "*.bit"]]

set impl_up_to_date 0
if {$impl_prog eq "100%" && !$impl_needs} {
  if {$build_stage eq "route"} {
    set impl_up_to_date 1
  } elseif {[llength $bit_candidates] > 0} {
    set impl_up_to_date 1
  }
}

if {$impl_up_to_date} {
  puts "Implementation up to date — skipping impl_1 (target step: $impl_to_step)"
} else {
  puts "Launching implementation to $impl_to_step ($jobs jobs)..."
  reset_run impl_1
  launch_runs impl_1 -to_step $impl_to_step -jobs $jobs
  wait_on_run impl_1

  if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: implementation failed at/before $impl_to_step. See run log under $project_dir"
    exit 1
  }
  set bit_candidates [glob -nocomplain \
    [file join $project_dir "${project_name}.runs" "impl_1" "*.bit"]]
}

if {$build_stage eq "route"} {
  puts "stage=route — stopping after route_design."
  exit 0
}

if {[llength $bit_candidates] == 0} {
  puts "ERROR: bitstream not found after impl_1."
  exit 1
}
set bit_src [lindex $bit_candidates 0]
file copy -force $bit_src $bitstream_out
puts "Bitstream written: $bitstream_out"

if {$build_stage eq "bitstream"} {
  puts "stage=bitstream — skipping XSA export."
  puts "Build finished OK."
  exit 0
}

# -----------------------------------------------------------------------------
# Export fixed hardware platform (.xsa) for Vitis
# -----------------------------------------------------------------------------
puts "Exporting hardware platform: $xsa_out"
open_run impl_1
write_hw_platform -fixed -include_bit -force -file $xsa_out
puts "XSA written: $xsa_out"
puts "Build finished OK."
exit 0
