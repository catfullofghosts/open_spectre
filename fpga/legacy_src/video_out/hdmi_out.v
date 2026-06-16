// Adapted from (c) fpga4fun.com & KNJN LLC 2013, and updated to SVGA (800x600) from 640X480 and from sparten 6 to series 7
// this is a test pattern generaotor only (uses Xilinx CLK wiz to generate pixel clk and 10X tmds clk)
////////////////////////////////////////////////////////////////////////
module hdmi_out(
    input pixclk,  
    input clk_5x,  
    input Video_active,
    input hSync,
    input vSync,
    input [7:0] red, green, blue,
    // input [23:0]video_in,
    output [2:0] TMDSp, TMDSn,
    output TMDSp_clock, TMDSn_clock,
    output led0,
    output hSync_out, vSync_out

    ///Simulation outputs
    //	output pixclk_s,hSync_s, vSync_s,
    //	output [7:0] r_s, g_s, b_s

  );

  ////////////////////////////////////////////////////////////////////////
  // reg [10:0] CounterX = 11'b00000000000; //define inital content for simulation to work
  // reg [10:0] CounterY = 11'b00000000000; //define inital content for simulation to work
   reg DrawArea = 1'b0;
//  wire pixclk;
  always @(posedge pixclk) DrawArea <= Video_active;

  // always @(posedge pixclk) CounterX <= (CounterX==1055) ? 0 : CounterX+1;
  // always @(posedge pixclk) if(CounterX==1055) CounterY <= (CounterY==627) ? 0 : CounterY+1;

  // always @(posedge pixclk) hSync <= (CounterX>=840) && (CounterX<968);
  // always @(posedge pixclk) vSync <= (CounterY>=601) && (CounterY<605);

  ////////////////
  // wire [7:0] W = {8{CounterX[7:0]==CounterY[7:0]}};
  // wire [7:0] A = {8{CounterX[7:5]==3'h2 && CounterY[7:5]==3'h2}};
  // reg [7:0] red, green, blue;
  // //always @(posedge pixclk) red <= ({CounterX[5:0] & {6{CounterY[4:3]==~CounterX[4:3]}}, 2'b00} | W) & ~A;
  // //always @(posedge pixclk) green <= (CounterX[7:0] & {8{CounterY[6]}} | W) & ~A;
  // //always @(posedge pixclk) blue <= CounterY[7:0] | W | A;
  // always @(posedge pixclk) red <= video_in[23:16];
  // always @(posedge pixclk) green <= video_in[15:8];
  // always @(posedge pixclk) blue <= video_in[7:0];

  ////////////////////////////////////////////////////////////////////////
  wire [9:0] TMDS_red, TMDS_green, TMDS_blue;
  TMDS_encoder encode_R(.clk(pixclk), .VD(red  ), .CD(2'b00)        , .VDE(DrawArea), .TMDS(TMDS_red));
  TMDS_encoder encode_G(.clk(pixclk), .VD(green), .CD(2'b00)        , .VDE(DrawArea), .TMDS(TMDS_green));
  TMDS_encoder encode_B(.clk(pixclk), .VD(blue ), .CD({vSync,hSync}), .VDE(DrawArea), .TMDS(TMDS_blue));

  //////////////////////////////////////////////////////////////////////// Seris 7 doesnt support DCM_sp, its replaced by clock wiz
//  wire clk_TMDS, DCM_TMDS_CLKFX;  // 25MHz x 10 = 250MHz
  //DCM_SP #(.CLKFX_MULTIPLY(10)) DCM_TMDS_inst(.CLKIN(pixclk), .CLKFX(DCM_TMDS_CLKFX), .RST(1'b0));
  //BUFG BUFG_TMDSp(.I(DCM_TMDS_CLKFX), .O(clk_TMDS));

  ////////////////////////////////////////////////////////////////////////
  reg [3:0] TMDS_mod10=0;  // modulus 10 counter
  reg [9:0] TMDS_shift_red=0, TMDS_shift_green=0, TMDS_shift_blue=0;
  reg TMDS_shift_load=0;
////////////////////////////////////////////////////////////////////////
// TMDS output serializer block (Series-7, using OSERDESE2)
////////////////////////////////////////////////////////////////////////

wire tmds_red_serial, tmds_green_serial, tmds_blue_serial, tmds_clk_serial;

//=========================================================
// Red channel
//=========================================================
OSERDESE2 #(
    .DATA_RATE_OQ("DDR"),
    .DATA_WIDTH(10),
    .TRISTATE_WIDTH(1),
    .SERDES_MODE("MASTER")
) oserdes_red_master (
    .OQ(tmds_red_serial),
    .CLK(clk_5x),           // 5x pixel clock (371.25 MHz for 720p60)
    .CLKDIV(pixclk),        // pixel clock (74.25 MHz)
    .D1(TMDS_red[0]), .D2(TMDS_red[1]),
    .D3(TMDS_red[2]), .D4(TMDS_red[3]),
    .D5(TMDS_red[4]), .D6(TMDS_red[5]),
    .D7(TMDS_red[6]), .D8(TMDS_red[7]),
    .OCE(1'b1),
    .RST(1'b0),
    .SHIFTIN1(), .SHIFTIN2(),
    .SHIFTOUT1(red_shift1), .SHIFTOUT2(red_shift2),
    .TQ()
);

OSERDESE2 #(
    .DATA_RATE_OQ("DDR"),
    .DATA_WIDTH(10),
    .TRISTATE_WIDTH(1),
    .SERDES_MODE("SLAVE")
) oserdes_red_slave (
    .OQ(),
    .CLK(clk_5x),
    .CLKDIV(pixclk),
    .D3(TMDS_red[8]), .D4(TMDS_red[9]),
    .OCE(1'b1),
    .RST(1'b0),
    .SHIFTIN1(red_shift1), .SHIFTIN2(red_shift2),
    .SHIFTOUT1(), .SHIFTOUT2(),
    .TQ()
);

OBUFDS obufds_red (.I(tmds_red_serial), .O(TMDSp[2]), .OB(TMDSn[2]));

//=========================================================
// Green channel
//=========================================================
OSERDESE2 #(
    .DATA_RATE_OQ("DDR"),
    .DATA_WIDTH(10),
    .TRISTATE_WIDTH(1),
    .SERDES_MODE("MASTER")
) oserdes_green_master (
    .OQ(tmds_green_serial),
    .CLK(clk_5x), .CLKDIV(pixclk),
    .D1(TMDS_green[0]), .D2(TMDS_green[1]),
    .D3(TMDS_green[2]), .D4(TMDS_green[3]),
    .D5(TMDS_green[4]), .D6(TMDS_green[5]),
    .D7(TMDS_green[6]), .D8(TMDS_green[7]),
    .OCE(1'b1), .RST(1'b0),
    .SHIFTIN1(), .SHIFTIN2(),
    .SHIFTOUT1(green_shift1), .SHIFTOUT2(green_shift2),
    .TQ()
);

OSERDESE2 #(
    .DATA_RATE_OQ("DDR"),
    .DATA_WIDTH(10),
    .TRISTATE_WIDTH(1),
    .SERDES_MODE("SLAVE")
) oserdes_green_slave (
    .OQ(),
    .CLK(clk_5x), .CLKDIV(pixclk),
    .D3(TMDS_green[8]), .D4(TMDS_green[9]),
    .OCE(1'b1), .RST(1'b0),
    .SHIFTIN1(green_shift1), .SHIFTIN2(green_shift2),
    .SHIFTOUT1(), .SHIFTOUT2(),
    .TQ()
);

OBUFDS obufds_green (.I(tmds_green_serial), .O(TMDSp[1]), .OB(TMDSn[1]));

//=========================================================
// Blue channel
//=========================================================
OSERDESE2 #(
    .DATA_RATE_OQ("DDR"),
    .DATA_WIDTH(10),
    .TRISTATE_WIDTH(1),
    .SERDES_MODE("MASTER")
) oserdes_blue_master (
    .OQ(tmds_blue_serial),
    .CLK(clk_5x), .CLKDIV(pixclk),
    .D1(TMDS_blue[0]), .D2(TMDS_blue[1]),
    .D3(TMDS_blue[2]), .D4(TMDS_blue[3]),
    .D5(TMDS_blue[4]), .D6(TMDS_blue[5]),
    .D7(TMDS_blue[6]), .D8(TMDS_blue[7]),
    .OCE(1'b1), .RST(1'b0),
    .SHIFTIN1(), .SHIFTIN2(),
    .SHIFTOUT1(blue_shift1), .SHIFTOUT2(blue_shift2),
    .TQ()
);

OSERDESE2 #(
    .DATA_RATE_OQ("DDR"),
    .DATA_WIDTH(10),
    .TRISTATE_WIDTH(1),
    .SERDES_MODE("SLAVE")
) oserdes_blue_slave (
    .OQ(),
    .CLK(clk_5x), .CLKDIV(pixclk),
    .D3(TMDS_blue[8]), .D4(TMDS_blue[9]),
    .OCE(1'b1), .RST(1'b0),
    .SHIFTIN1(blue_shift1), .SHIFTIN2(blue_shift2),
    .SHIFTOUT1(), .SHIFTOUT2(),
    .TQ()
);

OBUFDS obufds_blue (.I(tmds_blue_serial), .O(TMDSp[0]), .OB(TMDSn[0]));

//=========================================================
// TMDS Clock channel
//=========================================================
// For clock channel, TMDS spec wants "1010101010" pattern
// Which is just a DDR toggle (same as forwarding pixclk)
OSERDESE2 #(
    .DATA_RATE_OQ("DDR"),
    .DATA_WIDTH(10),
    .TRISTATE_WIDTH(1),
    .SERDES_MODE("MASTER")
) oserdes_clk (
    .OQ(tmds_clk_serial),
    .CLK(clk_5x), .CLKDIV(pixclk),
    .D1(1'b1), .D2(1'b0), .D3(1'b1), .D4(1'b0),
    .D5(1'b1), .D6(1'b0), .D7(1'b1), .D8(1'b0),
    .OCE(1'b1), .RST(1'b0),
    .SHIFTIN1(), .SHIFTIN2(), .SHIFTOUT1(), .SHIFTOUT2(),
    .TQ()
);

OBUFDS obufds_clk (.I(tmds_clk_serial), .O(TMDSp_clock), .OB(TMDSn_clock));

////////////////////////////////////////////////////////////////////////



endmodule


////////////////////////////////////////////////////////////////////////
module TMDS_encoder(
    input clk,
    input [7:0] VD,  // video data (red, green or blue)
    input [1:0] CD,  // control data
    input VDE,  // video data enable, to choose between CD (when VDE=0) and VD (when VDE=1)
    output reg [9:0] TMDS = 0
  );

  wire [3:0] Nb1s = VD[0] + VD[1] + VD[2] + VD[3] + VD[4] + VD[5] + VD[6] + VD[7];
  wire XNOR = (Nb1s>4'd4) || (Nb1s==4'd4 && VD[0]==1'b0);
  wire [8:0] q_m = {~XNOR, q_m[6:0] ^ VD[7:1] ^ {7{XNOR}}, VD[0]};

  reg [3:0] balance_acc = 0;
  wire [3:0] balance = q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7] - 4'd4;
  wire balance_sign_eq = (balance[3] == balance_acc[3]);
  wire invert_q_m = (balance==0 || balance_acc==0) ? ~q_m[8] : balance_sign_eq;
  wire [3:0] balance_acc_inc = balance - ({q_m[8] ^ ~balance_sign_eq} & ~(balance==0 || balance_acc==0));
  wire [3:0] balance_acc_new = invert_q_m ? balance_acc-balance_acc_inc : balance_acc+balance_acc_inc;
  wire [9:0] TMDS_data = {invert_q_m, q_m[8], q_m[7:0] ^ {8{invert_q_m}}};
  wire [9:0] TMDS_code = CD[1] ? (CD[0] ? 10'b1010101011 : 10'b0101010100) : (CD[0] ? 10'b0010101011 : 10'b1101010100);

  always @(posedge clk) TMDS <= VDE ? TMDS_data : TMDS_code;
  always @(posedge clk) balance_acc <= VDE ? balance_acc_new : 4'h0;
endmodule


////////////////////////////////////////////////////////////////////////




