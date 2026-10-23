# FPGA build (Vivado 2024.2)

Windows only. Script lives in `fpga/syn/build.bat`.

## Prerequisites
- Vivado 2024.2 at `C:\Xilinx\Vivado\2024.2`
- Vitis 2024.2 at `C:\Xilinx\Vitis\2024.2` (needed for a full build with software)
- Python on PATH

* These scripts build the project for the Arty Z720 dev board by Digilent *

## Steps
- Open cmd
- `cd fpga\syn`
- `build.bat`

No args = full build (`all`): bitstream + XSA + Vitis software.

Digilent IP used by the design (`axi_dynclk`, `dvi2rgb`, `rgb2dvi`, and the TMDS interface) is vendored at `fpga\ip\digilent`. The build does not clone it. Upstream base is Digilent `vivado-library` commit `0362ce72` (2026-10-13). `axi_dynclk` is the local version (global pixel clock `PXL_CLK_G_O`, AXI register `0x24`). `rgb2dvi` includes the OOC component-style reset overlay.

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
