# Program the current hw device with the Open Spec bitstream.
# Run (after settings64.bat):
#   vivado -mode batch -source program.tcl
# Optional:
#   vivado -mode batch -source program.tcl -tclargs C:/path/to/custom.bit

set script_dir [file normalize [file dirname [info script]]]
set default_bit [file normalize [file join $script_dir "build" "hdmi_in.bit"]]

if {[llength $argv] > 0} {
  set bitfile [file normalize [lindex $argv 0]]
} else {
  set bitfile $default_bit
}

if {![file exists $bitfile]} {
  puts "ERROR: bitstream not found: $bitfile"
  exit 1
}

puts "Programming: $bitfile"
open_hw_manager
connect_hw_server
current_hw_target
open_hw_target
set_property PROGRAM.FILE $bitfile [current_hw_device]
program_hw_devices [current_hw_device]
puts "Programming complete."
exit 0
