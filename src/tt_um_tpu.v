/*
 * Copyright (c) 2025 Dennis Du and Rick Gao
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_tpu (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Bidirectional Pins All Input
    assign uio_oe  = 8'b00000000;

    // Assigned All Pins
    assign uio_out = 0;
    wire _unused = &{ena, 1'b0};
   
    // Input and Output of TPU
    wire [15:0] instruction;
    wire [7:0] result;

    // Connect pin to instruction
    assign instruction [7:0]  = ui_in [7:0];    // Lower 8 bits are Input pins
    assign instruction [15:8] = uio_in [7:0];   // Upper 8 bits are IO pins


    tpu tpu_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .instruction(instruction),
        .result        (result)
    );

    assign uo_out  = result;


endmodule
