# tools

Helper scripts used during development. Not part of the Vivado build.

## Folders
- `ems_tester` — Python XSDB tools to poke EMS registers on the board
- `ems_tester/gui` — GUI front end for that tester
- `legacy` — older tester scripts, unused
- `shape_sim` — Python sim of the shape generator
- `sim_images` — PNGs dumped from Vivado sim traces

## Loose files
- `vga_sim.py` — turns sim CSV dumps into images
- `write_file_ex.vhd` — VHDL helper to write video frames out of sim
