`default_nettype none
`timescale 1ns/1ns

module tpu_top (
    input  wire         clk,
    input  wire         rst_n,
    // Control interface
    input  wire         start,          // Begin the operation
    output wire         done,           // Signals full completion
    // Streaming data input
    input  wire [7:0]   data_in,        // Used for both weights & activations
    input  wire         data_in_valid,  // Asserted when data_in is valid
    // Debug or optional read-back from SRAM (not strictly required)
    input  wire         sram_read_en,
    input  wire  [3:0]  sram_read_addr, // Enough bits for DEPTH=16
    output wire [15:0]  sram_read_data  // 16-bit data read from SRAM
);

    //------------------------------------------------------
    // 1) Control Unit
    //------------------------------------------------------
    wire load_weight, load_activation, compute_en, store_en;
    reg  computation_done, store_done;

    control_unit u_ctrl (
        .clk               (clk),
        .rst_n             (rst_n),
        .start             (start),
        .computation_done  (computation_done),
        .store_done        (store_done),
        .load_weight       (load_weight),
        .load_activation   (load_activation),
        .compute_en        (compute_en),
        .store_en          (store_en),
        .done              (done)
    );

    //------------------------------------------------------
    // 2) Weight & Activation Buffers
    //------------------------------------------------------
    // a) Weight Buffer
    //    - When load_weight=1, we enable writing from data_in
    //    - When compute_en=1, we enable reading to feed the systolic array
    reg weight_swap;  // Used to "flip" read/write roles internally
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            weight_swap <= 1'b0;
        else if (load_weight == 1'b0 && compute_en == 1'b1)
            // As soon as we leave LOAD_WEIGHT and enter COMPUTE, flip
            weight_swap <= 1'b1;
        else if (!compute_en)
            weight_swap <= 1'b0; // reset swap after compute is done, or keep logic as needed
    end

    wire [7:0] weight_data_out;
    wire       weight_empty;
    
    weight_buffer u_weight_buffer (
        .clk         (clk),
        .rst_n       (rst_n),
        .data_in     (data_in),
        .in_valid    (load_weight && data_in_valid),
        .in_ready    (/* not used here */),
        .swap        (weight_swap),
        .read_en     (compute_en), // read when computing
        .data_out    (weight_data_out),
        .buffer_empty(weight_empty)
    );

    // b) Activation Buffer
    reg activation_swap;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            activation_swap <= 1'b0;
        else if (load_activation == 1'b0 && compute_en == 1'b1)
            activation_swap <= 1'b1;
        else if (!compute_en)
            activation_swap <= 1'b0;
    end

    wire [7:0] activation_data_out;
    wire       activation_empty;

    activation_buffer u_activation_buffer (
        .clk           (clk),
        .rst_n         (rst_n),
        .data_in       (data_in),
        .in_valid      (load_activation && data_in_valid),
        .in_ready      (/* not used here */),
        .swap          (activation_swap),
        .read_en       (compute_en),
        .data_out      (activation_data_out),
        .buffer_empty  (activation_empty)
    );

    //------------------------------------------------------
    // 3) Systolic Array (4x4)
    //------------------------------------------------------
    // NOTE: For a real design, you typically want 4 different activations
    // and 4 different weights. This example simply replicates the single
    // FIFO outputs across all rows and columns for demonstration.
    //------------------------------------------------------
    localparam DATA_WIDTH = 8;
    localparam ACC_WIDTH  = 16;

    wire [ACC_WIDTH-1:0] c00, c01, c02, c03,
                          c10, c11, c12, c13,
                          c20, c21, c22, c23,
                          c30, c31, c32, c33;

    systolic_array_4x4 u_systolic (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (compute_en),  // Perform MACs when compute_en=1
        // Activation inputs (all the same for demonstration)
        .a_in0  (activation_data_out),
        .a_in1  (activation_data_out),
        .a_in2  (activation_data_out),
        .a_in3  (activation_data_out),
        // Weight inputs (all the same for demonstration)
        .b_in0  (weight_data_out),
        .b_in1  (weight_data_out),
        .b_in2  (weight_data_out),
        .b_in3  (weight_data_out),
        // Outputs
        .c00 (c00), .c01 (c01), .c02 (c02), .c03 (c03),
        .c10 (c10), .c11 (c11), .c12 (c12), .c13 (c13),
        .c20 (c20), .c21 (c21), .c22 (c22), .c23 (c23),
        .c30 (c30), .c31 (c31), .c32 (c32), .c33 (c33)
    );

    //------------------------------------------------------
    // 3a) Generate "computation_done"
    //------------------------------------------------------
    // Example: after 16 cycles in COMPUTE state, declare done.
    reg [4:0] compute_cycle;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            compute_cycle <= 5'd0;
            computation_done <= 1'b0;
        end
        else if (!compute_en) begin
            // Reset whenever we leave compute state
            compute_cycle <= 5'd0;
            computation_done <= 1'b0;
        end
        else begin
            // Counting while compute_en=1
            compute_cycle <= compute_cycle + 1'b1;
            if (compute_cycle == 5'd15)
                computation_done <= 1'b1;
        end
    end

    //------------------------------------------------------
    // 4) Output SRAM
    //    We'll store 16 partial sums: c00..c03, c10..c13, c20..c23, c30..c33
    //------------------------------------------------------
    wire [15:0] sram_rdata;
    reg  [15:0] sram_wdata;
    reg  [3:0]  sram_waddr;  // 16 deep
    reg         sram_we;

    output_sram #(
        .DATA_WIDTH(16),
        .DEPTH     (16)
    ) u_output_sram (
        .clk   (clk),
        .rst_n (rst_n),
        // Write port
        .we    (sram_we),
        .waddr (sram_waddr),
        .wdata (sram_wdata),
        // Read port (for external debug)
        .re    (sram_read_en),
        .raddr (sram_read_addr),
        .rdata (sram_rdata)
    );

    assign sram_read_data = sram_rdata; // Expose read data externally

    //------------------------------------------------------
    // 4a) Storing Results in SRAM + "store_done"
    //------------------------------------------------------
    reg [3:0] store_count; // 16 results total
    always @(*) begin
        // By default, pick c00
        sram_wdata = c00;
        case (store_count)
            4'd0 : sram_wdata = c00;
            4'd1 : sram_wdata = c01;
            4'd2 : sram_wdata = c02;
            4'd3 : sram_wdata = c03;
            4'd4 : sram_wdata = c10;
            4'd5 : sram_wdata = c11;
            4'd6 : sram_wdata = c12;
            4'd7 : sram_wdata = c13;
            4'd8 : sram_wdata = c20;
            4'd9 : sram_wdata = c21;
            4'd10: sram_wdata = c22;
            4'd11: sram_wdata = c23;
            4'd12: sram_wdata = c30;
            4'd13: sram_wdata = c31;
            4'd14: sram_wdata = c32;
            4'd15: sram_wdata = c33;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sram_we    <= 1'b0;
            sram_waddr <= 4'd0;
            store_done <= 1'b0;
            store_count <= 4'd0;
        end
        else if (!store_en) begin
            // Idle when not in STORE
            sram_we     <= 1'b0;
            sram_waddr  <= 4'd0;
            store_done  <= 1'b0;
            store_count <= 4'd0;
        end
        else begin
            // STORE state: each cycle we write one result
            sram_we           <= 1'b1;
            sram_waddr        <= store_count;
            store_count       <= store_count + 1'b1;
            if (store_count == 4'd15)
                store_done <= 1'b1; // done after writing the last element
        end
    end

endmodule
