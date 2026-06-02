
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

def rst_digital_side_matrix(matrix_out):    
            matrix_in_shifted = 0
            # Read register value using XSCT
            command = f"mwr -force  0x40000004 {hex(matrix_out)}"
            print(command)
            output = xsct.do(command) # needs gracefull fail state
            command = f"mwr -force  0x40000010 {hex(matrix_in_shifted)}"
            print(command)

            output = xsct.do(command) # needs gracefull fail state
            command = f"mwr -force  0x40000008 0x1"
            output = xsct.do(command) # needs gracefull fail state
            command = f"mwr -force  0x40000008 0x0"
            output = xsct.do(command) # needs gracefull fail state


def prog_digital_side_matrix(matrix_out, matrix_in): 
            if matrix_in > 31:
                matrix_in_addr = "0x40000014"
            else:
                 matrix_in_addr = "0x40000010"
            matrix_in_shifted = 1 << (matrix_in % 32)
            # Read register value using XSCT
            command = f"mwr -force  0x40000004 {hex(matrix_out)}"
            print(command)
            output = xsct.do(command) # needs gracefull fail state
            command = f"mwr -force  {matrix_in_addr} {hex(matrix_in_shifted)}"
            print(command)

            output = xsct.do(command) # needs gracefull fail state
            command = f"mwr -force  0x40000008 0x1"
            output = xsct.do(command) # needs gracefull fail state
            command = f"mwr -force  0x40000008 0x0"
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

    for x in range(57):
        print(f"Checking input {x}")
        prog_digital_side_matrix(49, x)
        rst_digital_side_matrix(49)
        


    print("Ending program...")
    xsct.close()


    