`default_nettype none
`timescale 1ns/1ps

// Define bit-widths according to your system requirements
`define DATA_WIDTH 8
`define ACC_WIDTH 16

module pe_improved (
    input  wire                   clk,
    input  wire                   reset,        // Synchronous active-high reset
    input  wire                   load_weight,  // Load a new weight when asserted
    input  wire                   valid,        // Indicates valid input data for calculation
    input  wire [`DATA_WIDTH-1:0] a_in,         // Input data from the left
    input  wire [`DATA_WIDTH-1:0] weight,       // External weight input to be stored
    input  wire [`ACC_WIDTH-1:0]  acc_in,       // Accumulated sum input from above

    output reg  [`DATA_WIDTH-1:0] a_out,        // Output data to the right
    output reg  [`ACC_WIDTH-1:0]  acc_out       // Accumulated sum output to the next stage below
);

    // Register to hold the stationary weight inside the PE
    reg [`DATA_WIDTH-1:0] weight_reg;

    // Synchronous block with synchronous active-high reset
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all internal registers to 0
            a_out      <= {`DATA_WIDTH{1'b0}};
            acc_out    <= {`ACC_WIDTH{1'b0}};
            weight_reg <= {`DATA_WIDTH{1'b0}};
        end 
        else begin
            // Load new weight when load_weight is asserted
            if (load_weight) begin
                weight_reg <= weight;
            end

            // Perform MAC operation only when valid is high
            if (valid) begin
                // Multiply a_in with the stored weight and add to acc_in
                // Note: a_in * weight_reg may require 16 bits to avoid overflow if DATA_WIDTH=8
                acc_out <= acc_in + (a_in * weight_reg);

                // Pass a_in through to a_out so the data can propagate to the next PE horizontally
                a_out <= a_in;
            end
            // If valid is low, a_out and acc_out remain unchanged in this design.
            // Adjust if your system requires different behavior when valid is 0.
        end
    end

endmodule
