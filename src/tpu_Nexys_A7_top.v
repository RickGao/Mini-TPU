//==============================================================
//  Mini-TPU  - Top for Nexys-A7-100T
//  SW[15:0] -> instruction,  BTNR get one input
//  LED[7:0] <- result
//==============================================================
`timescale 1ns/1ps
module tpu_top_sw
(
    input  wire CLK100MHZ,     // E3 : 100 MHz
    input  wire BTNC,
    input  wire BTNR,   
    input  wire [15:0] SW, 
    output wire [15:0] LED    
);

// 100mhz clk
wire clk = CLK100MHZ;

//low -> high reset
reg [2:0] rst_sr;
always @(posedge clk) rst_sr <= {rst_sr[1:0], BTNC};
wire rst_n = rst_sr[2];


reg bt_r0, bt_r1;
always @(posedge clk) begin
    bt_r0 <= BTNR;
    bt_r1 <= bt_r0;
end
wire wr_pulse =  bt_r0 & ~bt_r1;

// wr pulse
reg [15:0] instr_reg;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)  instr_reg <= 16'h0000;
    else if (wr_pulse) instr_reg <= SW;
    else instr_reg <= 16'h0000;
end

// connect to tpu top
wire [7:0] result;

tpu u_tpu (
    .clk         (clk),
    .rst_n       (rst_n),
    .instruction (instr_reg),
    .result      (result)
);

//led
assign LED[7:0]  = result;
assign LED[15:8] = 8'h00;

endmodule
