# OPEN_SPECTRE
## An open-source FPGA-based EMS SPECTRE video synth.
*A project aimed at recreating the EMS SPECTRE VIDEO SYNTHESIZER in HDL*

Sorry about the repo disappearing for a while. Had some issues, it's back now. and better than EVER!

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/donate/?hosted_button_id=LSMYWSM7M7EEA)
Open to donations and contributors with FPGA experience. 😀 

###  ✨The EMS SPECTRE Colour Video ✨
> Synthesiser is a unique and revolutionary new product: an instrument capable of producing exciting graphic images on an ordinary television screen. The complete SPECTRE package consists of the synthesiser itself, plus a Sony Trinitron colour monitor and a Sony black-and-white TV camera. The synthesiser was compact (38"x23.5"x7"), portable (about 35 pounds/15.9KG), and unequalled in its simplicity and versatility.

![EMS SPECTRE](/Spectron%20Resources/Product%20Photos/spectre1.jpg)

### Design Info
#### 🎉Aim 🎉
The aim of this project is to preserve this rare and unique video synth by recreating it in an FPGA, but also to use it as a building block to make a Spectre that is both true to the original and also a modern tool for creativity.
For more info on this process, take a look at: 
[Cloning Hardware Ethos](documentation/Cloning%20a%20process%20not%20a%20device.md)

### 🍣Want to Contribute?🍣
Amazing! If you have FPGA and or Verilog/VHDL skills, we would love to have you involved. But first, there are a few things you should know. 
#### What to do first
- Look through the resources folder to get an idea of what the EMS SPECTRE is and how it works
- Look at the top-level diagram and the list of modules
#### Project Details For Contributors
- RTL in VHDL or Verilog (VHDL preferred, no SystemVerilog 😎 sorry) 
- One module per file with a separate testbench (Verilog or VHDL test benches only, *not everything has one yet, but it should)
- Test benches should print out a message at the end confirming if they are successful or not
- No HSL or auto-generated code, no busses or interfaces for now (will be busses later)
- Use any software you like, but a Vivado project will be supplied
- Follow the template for file headers and comments 📑
- Follow the folder structure for the project 📂
- All code must be open source or MIT license 👍

#### If, after all that, you still want to be involved,d you can do one of three things:
- Email us at *OPEN.SPECTRE.PROJECT@gmail.com* and see what modules we need to make at the moment
- Branch the repo, make a module, and submit a pull request 
- If you are not good at git/GitHub, if you write any module,s you can email it to us, and we will integrate it into the project

### 🐙License🐙
Creative Commons CC BY-NC

### Contributors
-Remi Freer
-Jacob Stoker
-Robert D Jordan
-Andrey Demenev

### Donations
We are very thankful to have received donations from the following people:
Chris Korvin,
Jay Hotchin,
Milton Grimshaw, and more amazing anonymous people. 
