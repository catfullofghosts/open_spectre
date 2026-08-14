// Colour encoder designed to replicate the kind of unique video colourspace encoder 
// of the EMS Spectre 
// Based on code contributed by Andrey Demenev 2025 (https://github.com/ademenev) and
// Used with his permission

module color_encoder(
  input clk,
  input [10:0]y,
  input [10:0]c1,
  input [10:0]c2,
  input swap_early, //set to 0 at higher level
  output reg[7:0]red,
  output reg[7:0]green,
  output reg[7:0]blue
);


localparam DELAY = 4;

reg [DELAY-1 : 0]swap = 0;

always@(posedge clk) swap[DELAY-1:0] <= {swap[DELAY-2:0], swap_early};

wire [10:0]swapped_c1 = swap[DELAY - 1] ? c1 : c2;
wire [10:0]swapped_c2 = swap[DELAY - 1] ? c2 : c1;

// give em an extra bit for overflow detection
wire signed [11:0]  c1_ext = {1'b0, swapped_c1[10:0]};
wire signed [11:0]  c2_ext = {1'b0, swapped_c2[10:0]};
wire signed [11:0]  g = 2047 - c1_ext - c2_ext;

wire [18:0]red_scaled;
wire [18:0]blue_scaled ;
wire [18:0]green_scaled;

  color_mult mult1(
      .dout(red_scaled), //output [18:0] dout
      .a(swapped_c1[10:3]), //input [7:0] a
      .b(y[10:3]), //input [10:0] b
      .ce(1'b1), //input ce
      .clk(clk), //input clk
      .reset(1'b0) //input reset
  );
  color_mult mult2(
      .dout(blue_scaled), //output [18:0] dout
      .a(swapped_c2[10:3]), //input [7:0] a
      .b(y[10:3]), //input [10:0] b
      .ce(1'b1), //input ce
      .clk(clk), //input clk
      .reset(1'b0) //input reset
  );
  color_mult mult3(
      .dout(green_scaled), //output [18:0] dout
      .a(g[11] ? 8'b0 : g[10:3]), //input [7:0] a
      .b(y[10:3]), //input [10:0] b
      .ce(1'b1), //input ce
      .clk(clk), //input clk
      .reset(1'b0) //input reset
  );


always@(posedge clk) begin
  red <= red_scaled[18:11];
  blue <= blue_scaled[18:11];
  green <= green_scaled[18:11];
end

endmodule


