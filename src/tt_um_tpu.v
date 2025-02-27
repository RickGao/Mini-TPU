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

    //-----------------------------------------------------
    // 1) Instantiate your TPU top-level (to be written)
    //-----------------------------------------------------
    wire [7:0] tpu_data_out;
    wire [7:0] tpu_uio_out;
    wire [7:0] tpu_uio_oe;

    tpu tpu_inst (
        // Example connections – you will refine these 
        // based on your actual tpu_top interface
        .clk        (clk),
        .rst_n      (rst_n),
        .inp_ui     (ui_in),
        .inp_uio    (uio_in),

        .out_ui     (tpu_data_out),
        .out_uio    (tpu_uio_out),
        .oe_uio     (tpu_uio_oe)
    );

    //-----------------------------------------------------
    // 2) Tie outputs from TPU to the TT pads
    //-----------------------------------------------------
    assign uo_out  = tpu_data_out;  // Goes to dedicated output pins
    assign uio_out = tpu_uio_out;   // Goes to the in/out pins
    assign uio_oe  = tpu_uio_oe;    // Enable signal for in/out pins

    //-----------------------------------------------------
    // 3) Tie off any unused signals to avoid warnings
    //-----------------------------------------------------
    wire _unused = &{ena, 1'b0};

endmodule
