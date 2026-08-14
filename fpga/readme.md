# FPGA build (Vivado 2024.2)

Windows only. Script lives in `fpga/syn/build.bat`.

## Prerequisites
- Vivado 2024.2 at `C:\Xilinx\Vivado\2024.2`
- Vitis 2024.2 at `C:\Xilinx\Vitis\2024.2` (needed for a full build with software)
- Python on PATH
- Git on PATH (first run clones Digilent IP)

* These scripts build the project for the Arty Z720 dev board by Digilent *

## Steps
- Open cmd
- `cd fpga\syn`
- `build.bat`

No args = full build (`all`): bitstream + XSA + Vitis software.

First run clones Digilent `vivado-library` into `fpga\deps\vivado-library` if it is missing.

## Commands
- `build.bat synth` — synthesis only
- `build.bat route` — synth + place/route, no bitstream
- `build.bat bitstream` — through write_bitstream
- `build.bat all` — bitstream + XSA + Vitis software
- `build.bat software` — Vitis only (needs existing `build\hdmi_in.xsa`)
- `build.bat clean` — wipe build products, then full build
- `build.bat clean synth` — wipe, then synth only
- `build.bat clean_only` — wipe only, no rebuild

## Outputs
- Vivado project: `fpga\syn\build\open_spec`
- Bitstream: `fpga\syn\build\hdmi_in.bit`
- XSA: `fpga\syn\build\hdmi_in.xsa`
- ELF: `fpga\syn\build\video_demo.elf`

## Notes
- `bitstream` does not export XSA. Use `all` if you need software.
- If Vivado/Vitis is not in the default path, set `XILINX_VIVADO` / `XILINX_VITIS` to the install folder.
- To program the board after a bitstream: `fpga\syn\program.bat`
