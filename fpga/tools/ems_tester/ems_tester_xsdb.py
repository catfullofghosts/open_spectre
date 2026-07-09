
# Download this and put this file in the root folder: https://github.com/raczben/pysct
# HOW TO: https://voltagedivide.com/2022/12/13/fpga-xilinx-jtag-to-axi-master-from-xsdb-and-python/

#You need to install "wexpect" for python

# in Your vivado bin folder (windows) open a terminal and run 'xsdb' 
# This starts a XSDB session, Now enter "xsdbserver start -port 3010"

# Then Run this program

# Should just be able to use xsct commands here: https://docs.xilinx.com/r/en-US/ug1400-vitis-embedded/XSCT-Commands

# need to add ability to silently read and wait for changed reg and then print the change when it happens
# x would need some more string parsing, maybe you enter the reg name and it will wait till a change


import json
import subprocess
import re
import argparse
import os
import sys
import logging
import time
from datetime import datetime
from core import * #core file is local


import subprocess

# constants

# number of digital ins/outs
matrix_in = 63
matrix_out = 56

# Matrix IN enumeration mapping
MATRIX_IN_MAP = {}
# xy_inv_out (17 downto 0)
for i in range(18):
    MATRIX_IN_MAP[f"xy_inv_out_{i}"] = i
# Individual signals
MATRIX_IN_MAP["slow_cnt_6"] = 18
MATRIX_IN_MAP["slow_cnt_3"] = 19
MATRIX_IN_MAP["slow_cnt_1_5"] = 20
MATRIX_IN_MAP["slow_cnt_0_6"] = 21
MATRIX_IN_MAP["slow_cnt_0_4"] = 22
MATRIX_IN_MAP["slow_cnt_0_2"] = 23
# overlay_gate_out (27 downto 24)
for i in range(4):
    MATRIX_IN_MAP[f"overlay_gate_out_{i}"] = 24 + i
# inv_out (31 downto 28)
for i in range(4):
    MATRIX_IN_MAP[f"inv_out_{i}"] = 28 + i
# edge_detector_out (35 downto 32)
for i in range(4):
    MATRIX_IN_MAP[f"edge_detector_out_{i}"] = 32 + i
MATRIX_IN_MAP["delay_out"] = 36
MATRIX_IN_MAP["ff_out_a"] = 37
MATRIX_IN_MAP["ff_out_b"] = 38
# shapes1
MATRIX_IN_MAP["shape1_a"] = 39
MATRIX_IN_MAP["shape1_b"] = 40
# shapes2
MATRIX_IN_MAP["shape2_a"] = 41
MATRIX_IN_MAP["shape2_b"] = 42
# comp_output (49 downto 43)
for i in range(7):
    MATRIX_IN_MAP[f"comp_output_{i}"] = 43 + i
MATRIX_IN_MAP["gnd"] = 50
# Analog side inputs
MATRIX_IN_MAP["osc1_sqr"] = 51
MATRIX_IN_MAP["osc2_sqr"] = 52
MATRIX_IN_MAP["random1"] = 53
MATRIX_IN_MAP["random2"] = 54
MATRIX_IN_MAP["audio_T"] = 55
MATRIX_IN_MAP["audio_B"] = 56
MATRIX_IN_MAP["ca_out"] = 57
MATRIX_IN_MAP["vcc"] = 63  # '1' used to set all outputs

def resolve_matrix_in(value):
    """Convert matrix_in name or number to integer value."""
    if isinstance(value, str):
        if value in MATRIX_IN_MAP:
            return MATRIX_IN_MAP[value]
        else:
            raise ValueError(f"Unknown matrix_in name: {value}")
    elif isinstance(value, int):
        return value
    else:
        raise TypeError(f"matrix_in must be int or str, got {type(value)}")

# Matrix OUT enumeration mapping
MATRIX_OUT_MAP = {}
# xy_inv_in (17 downto 0)
for i in range(18):
    MATRIX_OUT_MAP[f"xy_inv_in_{i}"] = i
# overlay_gate1 and overlay_gate2
MATRIX_OUT_MAP["overlay_gate1_0"] = 18
MATRIX_OUT_MAP["overlay_gate2_0"] = 19
MATRIX_OUT_MAP["overlay_gate1_1"] = 20
MATRIX_OUT_MAP["overlay_gate2_1"] = 21
MATRIX_OUT_MAP["overlay_gate1_2"] = 22
MATRIX_OUT_MAP["overlay_gate2_2"] = 23
MATRIX_OUT_MAP["overlay_gate1_3"] = 24
MATRIX_OUT_MAP["overlay_gate2_3"] = 25
# inv_in (29 downto 26)
for i in range(4):
    MATRIX_OUT_MAP[f"inv_in_{i}"] = 26 + i
MATRIX_OUT_MAP["edge_detector_in"] = 30
MATRIX_OUT_MAP["delay_in"] = 31
MATRIX_OUT_MAP["ff_in_a"] = 32
MATRIX_OUT_MAP["ff_in_b"] = 33
MATRIX_OUT_MAP["acm_out1"] = 34
MATRIX_OUT_MAP["acm_out2"] = 35
# luma_in1 (39 downto 36)
for i in range(4):
    MATRIX_OUT_MAP[f"luma_in1_{i}"] = 36 + i
# chroma_mux_in1 (42 downto 40) and (45 downto 43)
for i in range(3):
    MATRIX_OUT_MAP[f"chroma_mux_in1_{i}"] = 40 + i
for i in range(3):
    MATRIX_OUT_MAP[f"chroma_mux_in1_{i+3}"] = 43 + i
# luma_in2 (49 downto 46)
for i in range(4):
    MATRIX_OUT_MAP[f"luma_in2_{i}"] = 46 + i
# chroma_mux_in2 (52 downto 50) and (55 downto 53)
for i in range(3):
    MATRIX_OUT_MAP[f"chroma_mux_in2_{i}"] = 50 + i
for i in range(3):
    MATRIX_OUT_MAP[f"chroma_mux_in2_{i+3}"] = 53 + i
MATRIX_OUT_MAP["chrom_swap"] = 56

def resolve_matrix_out(value):
    """Convert matrix_out name or number to integer value."""
    if isinstance(value, str):
        if value in MATRIX_OUT_MAP:
            return MATRIX_OUT_MAP[value]
        else:
            raise ValueError(f"Unknown matrix_out name: {value}")
    elif isinstance(value, int):
        return value
    else:
        raise TypeError(f"matrix_out must be int or str, got {type(value)}")

# TO DO:
# add ability to set radex for reg dump, 
# add colour coding for better eadability
class color:
    PURPLE = "\033[95m"
    CYAN = "\033[96m"
    DARKCYAN = "\033[97m"
    BLUE = "\033[94m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = '\033[41m'# "\033[91m" # red inverted
    BOLD = "\033[1m"
    UNDERLINE = "\033[4m"
    END = "\033[0m"
# add ability to check single reg from search term in reg/reg name

def _pulse_digital_matrix_load():
            command = f"mwr -force  0x40000008 0x1"
            xsct.do(command) # needs gracefull fail state
            command = f"mwr -force  0x40000008 0x0"
            xsct.do(command) # needs gracefull fail state


def _commit_digital_matrix_mask(matrix_out, mask_lower, mask_upper):
            """Write a complete 64-bit mask (both halves) and pulse load once."""
            resolved_matrix_out = resolve_matrix_out(matrix_out)

            command = f"mwr -force  0x40000004 {hex(resolved_matrix_out)}"
            print(command)
            xsct.do(command) # needs gracefull fail state

            command = f"mwr -force  0x40000010 {hex(mask_lower)}"
            print(command)
            xsct.do(command) # needs gracefull fail state

            command = f"mwr -force  0x40000014 {hex(mask_upper)}"
            print(command)
            xsct.do(command) # needs gracefull fail state

            _pulse_digital_matrix_load()


def _digital_matrix_mask_from_inputs(matrix_in):
            """Build lower/upper mask halves from one or more matrix inputs."""
            pins = matrix_in if isinstance(matrix_in, list) else [matrix_in]
            mask_lower = 0
            mask_upper = 0
            for pin in [resolve_matrix_in(p) for p in pins]:
                if pin <= 31:
                    mask_lower |= 1 << pin
                else:
                    mask_upper |= 1 << (pin % 32)
            return mask_lower, mask_upper


def rst_digital_side_matrix(matrix_out=None, pullup = False):    
            # If no argument passed, step through all matrix_out values 0-56
            if matrix_out is None:
                for out_val in range(57):  # 0 to 56 inclusive backwards to avoid the apperence of pin removal causing the viodeo the freakout
                    rst_digital_side_matrix(56-out_val)
                return

            if pullup:
                mask_lower = 0x32
                mask_upper = 0x32
            else:
                mask_lower = 0
                mask_upper = 0

            _commit_digital_matrix_mask(matrix_out, mask_lower, mask_upper)


def prog_digital_side_matrix(matrix_out, matrix_in): 
            # Handle matrix_out as a list - iterate over each value
            if isinstance(matrix_out, list):
                for out_val in matrix_out:
                    prog_digital_side_matrix(out_val, matrix_in)
                return

            mask_lower, mask_upper = _digital_matrix_mask_from_inputs(matrix_in)
            if not isinstance(matrix_in, list):
                print(f"resolved matrix in = {resolve_matrix_in(matrix_in)}")

            _commit_digital_matrix_mask(matrix_out, mask_lower, mask_upper)


def prog_annaloge_side_matrix(matrix_out, matrix_in): 
            
            matrix_in_addr = "0x40000030"

            resolved_matrix_out = matrix_out
            matrix_in_shifted = (1 << matrix_in)  # am i worng about this? is the value inverted somewhere in the fpga
            # matrix_in_shifted = ~(1 << matrix_in) & 0xFFFFFFFF # remember all fs = muted
            # Read register value using XSCT
            command = f"mwr -force  0x40000028 {hex(resolved_matrix_out)}"
            print(command)
            output = xsct.do(command) # needs gracefull fail state
            command = f"mwr -force  {matrix_in_addr} {hex(matrix_in_shifted)}"
            print(command)

            output = xsct.do(command) # needs gracefull fail state
            command = f"mwr -force  0x40000034 0x1"
            print(command)
            output = xsct.do(command) # needs gracefull fail state
            command = f"mwr -force  0x40000034 0x0"
            output = xsct.do(command) # needs gracefull fail state
            print(command)

def rst_annaloge_side_matrix(matrix_out): 
            
            matrix_in_addr = "0x40000030"

            # Resolve matrix_out name to number if needed
            resolved_matrix_out = matrix_out
            
            matrix_in_shifted = 0
            # Read register value using XSCT
            command = f"mwr -force  0x40000028 {hex(resolved_matrix_out)}"
            print(command)
            output = xsct.do(command) # needs gracefull fail state
            command = f"mwr -force  {matrix_in_addr} {hex(matrix_in_shifted)}"
            print(command)

            output = xsct.do(command) # needs gracefull fail state
            command = f"mwr -force  0x40000034 0x1"
            print(command)
            output = xsct.do(command) # needs gracefull fail state
            command = f"mwr -force  0x40000034 0x0"
            output = xsct.do(command) # needs gracefull fail state
            print(command)

def wr_reg(addr, val_in): 
            
            matrix_in_addr = "0x40000030"

            matrix_in_shifted = 1 << (matrix_in)
            # Read register value using XSCT
            command = f"mwr -force  0x400000{addr} {hex(val_in)}"
            print(command)
            output = xsct.do(command) # needs gracefull fail state



if __name__ == "__main__":
   

    print("*************************************")
    print("*    EMS TESTER   *")
    print("*************************************")
    print("")
    print("")


    print("attempting to connect to XSCT running on: 'localhost' port 3010")
    try:
        xsct = Xsct('localhost', 3010)
    except:
        print("ERROR Connecting to XSCT!")
        sys.exit(1)
    print("xsct's pid: {}".format(xsct.do('pid')))

    xsct.do("connect")
    print("Targets:")
    targets_found = xsct.do("targets")
    targets_found = targets_found.split("\\n")
    for target_found in targets_found:
        print(target_found)

    print("Select the target to dump regs from by number/or hit enter if target already selected:")
    target_con = input()
    if len(target_con) == 0:
        print("target not changed...\n")
    else: 
        xsct.do(f"target {target_con}")
        print(xsct.do(f"target -index {target_con}"))

    ###############
    # TESTS
    # ** chroma on the analoge side doesnt work because the digital side is giveing 100% for chroma, and so the analoge side needs to have sigend values 
    # that way the nexitive part of the wave can still effect the digital signal

    # digital and analoge seem to work together

    # work out how to reset the analoge matrix per output
    # is u and v on analog not working because the digital side for those channels is maxed?
    ###############
    # wr_reg('68',4)


    rst_digital_side_matrix() 
    # wr_reg('78',int("2", 16)) #bypass colour encoder
    # wr_reg('78',int("6", 16)) #bypass colour encoder and div pix clk en
    wr_reg('78',int("2", 16)) #bypass colour encoder , dotn devide pix clk
# 0x40000078 = 0x2 bypasses color

    rst_digital_side_matrix(pullup = True) 
   
    rst_annaloge_side_matrix(16)
    rst_annaloge_side_matrix(17)

    prog_digital_side_matrix(53, 1)
    prog_digital_side_matrix(52, 1)
    prog_digital_side_matrix(51, 1)

    # # # chroma 2
    prog_digital_side_matrix(56, 1)
    prog_digital_side_matrix(55, 1)
    prog_digital_side_matrix(54, 1)


    ################################################################
    ############ Analoge side TESTS
    ################################################################
    
    ############ OSC

    # test osc 1 
    # with vertical sync enabled only freqs of 1 or 0 work, may need to adjust the counter range for this sync
    
    # Horixontal test
    wr_reg('68',int("40f000f0", 16)) #-- look at adding a way to de sync the second oscilaor
    prog_annaloge_side_matrix(16,1) # routes osc1 sin to luma out
    
    # # vertical test
    wr_reg('68',int("80000000", 16)) #-- look at adding a way to de sync the second oscilaor
    prog_annaloge_side_matrix(16,1) # routes osc1 sin to luma out

    # unsynced test  running slow
    wr_reg('68',int("100fffff", 16)) #-- look at adding a way to de sync the second oscilaor
    prog_annaloge_side_matrix(16,1) # routes osc1 sin to luma out

    # #test osc changing freq slowly 
    # freq = "40400040"
    # wr_reg('68',int(freq, 16)) #-- look at adding a way to de sync the second oscilaor
    # prog_annaloge_side_matrix(16,1) # routes osc1 sin to luma out
    # prog_annaloge_side_matrix(17,0) # routes osc1 sin to luma out

    # while(1):
    #     for x in range(9):
    #         freq = f"4040003{x}"
    #         wr_reg('68',int(freq, 16)) #-- look at adding a way to de sync the second oscilaor
    #         time.sleep(1)

    #test osc changing freq fast
    # freq = "40400040"
    # wr_reg('68',int(freq, 16)) #-- look at adding a way to de sync the second oscilaor
    # prog_annaloge_side_matrix(16,1) # routes osc1 sin to luma out
    # prog_annaloge_side_matrix(17,0) # routes osc1 sin to luma out

    # while(1):
    #     for x in range(9):
    #         freq = f"4040003{x}"
    #         wr_reg('68',int(freq, 16)) #-- look at adding a way to de sync the second oscilaor
         
    ############ NOISE
    # test noise 1 max freq min slew
    # wr_reg('64',2)
    # wr_reg('60',int("000001", 16))
    # # # prog_annaloge_side_matrix(16,4) # noise works
    # prog_annaloge_side_matrix(16,5) # noise works
    # wr_reg('64',0)
    # wr_reg('64',1) # recycle seems to work

    # # # test noise 2 mid-ish freq 
    # wr_reg('64',2)
    # wr_reg('60',int("3003afff", 16))
    # # # prog_annaloge_side_matrix(16,4) # noise works
    # prog_annaloge_side_matrix(16,5) # noise works
    # wr_reg('64',0)
    # wr_reg('64',0) # recycle needs to be off for very slow frequencyes
    # wr_reg('64',0)

    # test noise 3 slew
    # wr_reg('64',2)
    # wr_reg('60',int("70000", 16))
    # # # prog_annaloge_side_matrix(16,4) # noise works
    # prog_annaloge_side_matrix(16,5) # noise works
    # wr_reg('64',0)
    # wr_reg('64',0) # recycle needs to be off for very slow frequencyes

    # test noise 4 freq change
    # wr_reg('64',2)
    # wr_reg('60',int("0000", 16))
    # # # prog_annaloge_side_matrix(16,4) # noise works
    # prog_annaloge_side_matrix(16,5) # noise works
    # wr_reg('64',0)
    # wr_reg('64',1) # recycle 


    # while(1):
    #     for x in range(30):
    #         freq = f"{x}"
    #         wr_reg('60',int(freq, 16)) #-- look at adding a way to de sync the second oscilaor
    #         time.sleep(1)

    
    # input 6-8 are audio and not hooked up yet!!
    
    # inputs 9 and 10 are dsm form the digital matrix side
    # prog_digital_side_matrix(49, ?) # hange this to dsm 1
    # prog_annaloge_side_matrix(16,9)


    ############### Shape gen -- not working
    # wr_reg('38',100)
    # wr_reg('3C',100)
    # wr_reg('40',100)
    # wr_reg('44',100)
    # wr_reg('48',100)
    # wr_reg('4c',100)
    # wr_reg('50',100)
    # wr_reg('54',100)
    # # # rst_annaloge_side_matrix(16)
    # prog_digital_side_matrix(49, 41)
    # prog_digital_side_matrix(48, 42)
    # prog_digital_side_matrix(47, 40)


    ############################
    #### EXTERNAL INPUT TESTS
    ############################

    ####### test 1: video in 
    # dont reset the matrix just before this!? it can cause distortian??? 
    # wr_reg('24',254)
    # prog_digital_side_matrix(49, 49)
    # prog_digital_side_matrix(48, 48)
    # prog_digital_side_matrix(47, 47)
    # prog_digital_side_matrix(46, 46)

    # prog_digital_side_matrix(45, 47)
    # prog_digital_side_matrix(44, 46)
    # prog_digital_side_matrix(43, 45)

    # prog_digital_side_matrix(42, 45)
    # prog_digital_side_matrix(41, 44)
    # prog_digital_side_matrix(40, 43)

    ####### test 2: video in range changing slowly
    # wr_reg('24',254)
    # prog_digital_side_matrix(49, 49)
    # prog_digital_side_matrix(48, 48)
    # prog_digital_side_matrix(47, 47)
    # prog_digital_side_matrix(46, 46)

    # prog_digital_side_matrix(45, 47)
    # prog_digital_side_matrix(44, 46)
    # prog_digital_side_matrix(43, 45)

    # prog_digital_side_matrix(42, 45)
    # prog_digital_side_matrix(41, 44)
    # prog_digital_side_matrix(40, 43)

    # while(1): # sweep input range -- loks good range works well
    #     for x in range(254):
    #         wr_reg('24',x)
    #         time.sleep(.2)

    ####### test 2: video in range changing fast
    # wr_reg('24',254)
    # prog_digital_side_matrix(49, 49)
    # prog_digital_side_matrix(48, 48)
    # prog_digital_side_matrix(47, 47)
    # prog_digital_side_matrix(46, 46)

    # prog_digital_side_matrix(45, 47)
    # prog_digital_side_matrix(44, 46)
    # prog_digital_side_matrix(43, 45)

    # prog_digital_side_matrix(42, 45)
    # prog_digital_side_matrix(41, 44)
    # prog_digital_side_matrix(40, 43)

    # while(1): # sweep input range -- loks good range works well
    #     for x in range(254):
    #         wr_reg('24',x)

    ### THIS STUFF DOESNT WORK
    # for i in range(matrix_out): # set all digital matrix outputs to 63 which is '1', to mimic the pull up nature of the original matrix
    #     prog_digital_side_matrix(i, 63)
    # # for i in range(16): # set all digital matrix video outs to something, but not chroma mux
    # #     prog_digital_side_matrix(i+36, 0)
    

    #########################
    ########### Detailed matrix test
    #########################

    ## Test inverters
    # prog_digital_side_matrix('inv_in_0','xy_inv_out_0')
    # prog_digital_side_matrix('inv_in_0','inv_out_0')


    ############################
    #### OTHER TESTS
    ############################

    # Test 1 counters pattern
    # luma - lower
    # prog_digital_side_matrix(39, 0)
    # prog_digital_side_matrix(38, 9)
    # prog_digital_side_matrix(37, 2)
    # prog_digital_side_matrix(36, 3)

    # # # # # chroma 1 - lower
    # prog_digital_side_matrix(56, 10) # colour swap

    # prog_digital_side_matrix(42, 6)
    # prog_digital_side_matrix(41, 11)
    # prog_digital_side_matrix(40, 13)

    # # # # # # chroma 2 -lower
    # prog_digital_side_matrix(45, 4)
    # prog_digital_side_matrix(44, 5)
    # prog_digital_side_matrix(43, 17)


    # test 2 random fun stuff
    # prog_digital_side_matrix( "edge_detector_in",'xy_inv_out_2')
    # prog_digital_side_matrix('xy_inv_in_6', "edge_detector_out_1")
    # # prog_digital_side_matrix(39, "xy_inv_out_6")
    # prog_digital_side_matrix('xy_inv_in_0', "edge_detector_out_3")
    # prog_digital_side_matrix(46, "xy_inv_out_2")
    # prog_digital_side_matrix(37, "xy_inv_out_0")
    # # prog_digital_side_matrix(36, "xy_inv_out_12")

  
    # prog_digital_side_matrix('xy_inv_in_9', "edge_detector_out_3")
    # prog_digital_side_matrix(42, "xy_inv_out_9")
    # prog_digital_side_matrix(45, "xy_inv_out_15")
    # prog_digital_side_matrix(47, "xy_inv_out_10")

    

    # Digital SIDE
    # step through all matrix inputs routed to luma lsb output --- yeah something is woerng here
    # for x in range(57):
    #     print(f"Checking input {x}")
    #     prog_digital_side_matrix(49, x)
    #     prog_digital_side_matrix(50, x)
    #     prog_digital_side_matrix(51, x)
    #     rst_digital_side_matrix(49)
    #     rst_digital_side_matrix(50)
    #     rst_digital_side_matrix(51)


    # Feedback test 1: counters
    # routing x and y counter into its own inverter and then to the luma out
    # looks to be working, feedback is stable on the x xounter direction 
    # prog_digital_side_matrix("xy_inv_in_8", "xy_inv_out_8") # horizontal feed balck
    # prog_digital_side_matrix("xy_inv_in_12", "xy_inv_out_12") # berticxal feedbackl
    # prog_digital_side_matrix(49, "xy_inv_out_8")
    # prog_digital_side_matrix(48, "xy_inv_out_8")
    # prog_digital_side_matrix(47, "xy_inv_out_12")
    # prog_digital_side_matrix(53, "xy_inv_out_8")
    # prog_digital_side_matrix(52, "xy_inv_out_8")
    # prog_digital_side_matrix(51, "xy_inv_out_8")
    # prog_digital_side_matrix(56, "xy_inv_out_12")
    # prog_digital_side_matrix(55, "xy_inv_out_12")
    # prog_digital_side_matrix(54, "xy_inv_out_12")



    print("Ending program...")
    xsct.close()


    