# OPEN_SPECTRE ✨
FPGA recreation of the EMS SPECTRE video synth.

Sorry about the repo disappearing for a while. Had some issues, it's back now.

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/donate/?hosted_button_id=LSMYWSM7M7EEA)
Open to donations and contributors with FPGA experience.

> Synthesiser is a unique and revolutionary new product: an instrument capable of producing exciting graphic images on an ordinary television screen. The complete SPECTRE package consists of the synthesiser itself, plus a Sony Trinitron colour monitor and a Sony black-and-white TV camera. The synthesiser was compact (38"x23.5"x7"), portable (about 35 pounds/15.9KG), and unequalled in its simplicity and versatility.

![EMS SPECTRE](/Spectron%20Resources/Product%20Photos/spectre1.jpg)

## Status (Arty Z7-20)

`overall progress  ████████░░  it runs, still lots of little things to do`

| block | state | notes |
| --- | --- | --- |
| HDMI in / out | done* | Digilent Arty Z7-20, In has a bug |
| digital matrix | done |  |
| analog matrix | done | signed mix still to do, is unsigned atm |
| oscillators | done | vert sync still a bit blocky |
| shape gen | wip | needs compare with original|
| colour encode | done | |
| audio in | wip | working, but needs propper testing|
| Vitis test software | done | used to test frambuffer, video in, ect |
| hardware interface | not started | still software controlled |

```
digital       [██████████]
analog        [████████░░]
shapes        [██████░░░░]
audio         [███████░░░]
HW interface  [░░░░░░░░░░]
```

## Aim

Recreate the SPECTRE in HDL so it can still make the pictures it was meant to make. Then keep going in the same spirit, not as a museum copy.

More on that: [Cloning Hardware Ethos](documentation/Cloning%20a%20process%20not%20a%20device.md)

## FPGA build
- [How to build with Vivado 2024.2 / `build.bat`](fpga/readme.md)

## Want to contribute?

If you have FPGA and/or Verilog/VHDL skills, we would love to have you involved. A few things first.

### What to do first
- Look through [Spectron Resources](Spectron%20Resources/readme.md) to get an idea of what the EMS SPECTRE is and how it works
- Look at the [top-level diagram](documentation/ems_diagram.drawio) and the [list of modules](documentation/readme.md)
- HDL lives in [`fpga/src`](fpga/src/readme.md) — top is `spector_wrapper_zynq_B.vhd`

### Project details
- RTL in VHDL or Verilog (VHDL preferred, no SystemVerilog sorry)
- One module per file with a separate testbench (Verilog or VHDL testbenches only — not everything has one yet, but it should)
- Testbenches should print a message at the end confirming pass or fail
- No HLS or auto-generated code, no busses or interfaces for now (will be busses later)
- Use any software you like, but a Vivado project is supplied
- Follow the template for file headers and comments
- Follow the folder structure for the project
- Contributions need to be something we can release under CC BY-NC

### How to get involved
- Email *OPEN.SPECTRE.PROJECT@gmail.com* and see what modules we need at the moment
- Branch the repo, make a module, and submit a pull request
- If you are not good at git/GitHub, write the module and email it to us. We will integrate it.

## License
Creative Commons CC BY-NC

## Contributors
- Remi Freer
- Jacob Stoker
- Robert D Jordan
- Andrey Demenev

## Donations
We are very thankful to have received donations from the following people:
Chris Korvin,
Jay Hotchin,
Milton Grimshaw, and more amazing anonymous people.

## Thank yous
- Violet Shylet
- MESS Melbourne
- Flo Kaufmann
