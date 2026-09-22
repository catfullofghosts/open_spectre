# pico_midi_uart

Raspberry Pi Pico as a USB-MIDI gadget for the Open Spectre Zynq.

The Pico is a dumb bridge: USB-MIDI on the computer side, raw MIDI bytes at
**31250 baud** on UART0. Channel-1 CC → register mapping is on the Zynq
(`fpga/z7_build/sw/midi_uart`), not here.

The DAW should see a device named **OPEN SPECTRE MIDI**.

## Wiring (3.3 V TTL)

This is a direct UART, not a DIN-MIDI opto / current loop.

| Pico            | Arty Z7-20 JA (PMOD)      |
|-----------------|---------------------------|
| GP0 UART0 TX    | JA1_P **Y18** `UART1_RX`  |
| GP1 UART0 RX    | JA1_N **Y19** `UART1_TX`  |
| GND             | GND                       |

Baud on both ends is `31250` (`MIDI_UART_BAUD` in this CMakeLists and in
`midi_uart.h`). Do not mix 115200 unless you change both.

JA1 is also the I2S MCLK pair in `open_spec.xdc`. If I2S is still mapped to
those pins, move this UART PMOD or drop I2S.

## Build

Needs the [Pico SDK](https://github.com/raspberrypi/pico-sdk) and ARM GCC.
If you have the **Raspberry Pi Pico** VS Code extension, those already live in
`%USERPROFILE%\.pico-sdk` and CMake will pick them up.

PowerShell (`set VAR=` does nothing here — use `$env:`):

```powershell
cd fpga\tools\pico_midi_uart
mkdir build -Force
cd build
cmake -G Ninja ..
cmake --build .
```

Copy `pico_midi_uart.uf2` onto the Pico in BOOTSEL mode.

Without the VS Code Pico install, point CMake at a local SDK:

```powershell
$env:PICO_SDK_PATH = "C:\path\to\pico-sdk"
cmake -G Ninja ..
```

## DAW map (channel 1)

CCs 1–35, contiguous, 14-bit pairs adjacent. YUV 12-bit is `(MSB<<7)|LSB` then
`>> 2` on the Zynq.

| CC | Control |
|----|---------|
| 1 / 2 | Osc 1 freq MSB / LSB |
| 3 | Osc 1 derivative |
| 4 | Osc 1 PWM duty (0–127 → 0–360°) |
| 5 | Osc 1 wave 0–3 |
| 6 | Osc 1 sync 0–3 |
| 7 | Osc 1 speed |
| 8 | Osc 1 alpha |
| 9 / 10 | Osc 2 freq MSB / LSB |
| 11 | Osc 2 derivative |
| 12 | Osc 2 PWM duty |
| 13 | Osc 2 wave |
| 14 | Osc 2 sync |
| 15 | Osc 2 speed |
| 16 | Osc 2 alpha |
| 17 / 18 | Noise freq MSB / LSB |
| 19 | Noise slew |
| 20 | Noise slowdown |
| 21 | Noise recycle (≥64) |
| 22 | Noise alpha |
| 23 | Audio crossover |
| 24 | Audio T thresh |
| 25 | Audio B thresh |
| 26 / 27 | Y MSB / LSB |
| 28 / 29 | Cr MSB / LSB |
| 30 / 31 | Cb MSB / LSB |
| 32 | Digital edge width |
| 33 | Slow-counter frame |
| 34 | Slow-counter /4 |
| 35 | CA rule (0–127) |

Classic-mode bits stay at AXI `0x7C` (not a CC yet).
