`timescale 1ns / 1ps

//   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
//  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
// | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
// | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
// | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
//  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
//                               ______                                                
//                              |______|                                               
// Module Name: debounce_multi by RD Jordan
// Created: 20.05.2022 14:34:42
// Description: create custom width debounce busses, where the debounce time is based on a counter
// Notes: based on code form NandLand
// Dependencies: 
// Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE-



module debounce_multi #(parameter num_bits = 8, DBtime = 8)(
    input [num_bits-1:0] button,
    input clk,
    input reset,
    output [num_bits-1:0] result
    );
    
    
    debounce_n #(.DBtime(DBtime) ) debounce_8[7:0](.button(button),.clk(clk),.reset(reset),.result(result));
    
endmodule
