`default_nettype none
`timescale 1ns/1ns

module output_sram #(
    parameter DATA_WIDTH = 16,                // Bit-width per stored result
    parameter DEPTH      = 16,                // # of storage locations
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  wire                    clk,
    input  wire                    rst_n,     // Active-low reset
    // Write port (from systolic array or aggregator)
    input  wire                    we,        // Write enable
    input  wire [ADDR_WIDTH-1:0]   waddr,     // Write address
    input  wire [DATA_WIDTH-1:0]   wdata,     // Data to write
    // Read port (to external interface)
    input  wire                    re,        // Read enable
    input  wire [ADDR_WIDTH-1:0]   raddr,     // Read address
    output reg  [DATA_WIDTH-1:0]   rdata      // Data out
);

    // Declare SRAM
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Optionally, clear memory or do nothing
            // For gate-level or real ASIC, typically memory is not forced to zero.
        end else if (we) begin
            mem[waddr] <= wdata;
        end
    end

    // Read
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata <= {DATA_WIDTH{1'b0}};
        end else if (re) begin
            rdata <= mem[raddr];
        end
    end

endmodule
