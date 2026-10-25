# src

HDL for the project. This is what `build.bat` compiles.

- Top level: `spector_wrapper_zynq_B.vhd`
- One module per file, testbenches sit next to the module they test

## Folders
- `analoge_side` — analog matrix, oscillators, mixers, noise
- `digital_side` — digital matrix, counters, comparators, CA
- `shape_gen` — shape generator
- `video_output` — colour encode
- `audio` — audio input
- `registers` — CPU register map
- `expander` — frame stats
- `common` — shared helpers
- `cpu` — leftover BD tcl, not the live top
