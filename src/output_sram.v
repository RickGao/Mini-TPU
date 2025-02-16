`default_nettype none
`timescale 1ns/1ns

module output_sram #(
    parameter DATA_WIDTH = 16,               // Bit-width for each stored result
    parameter DEPTH      = 16,               // Number of storage locations (e.g., for 16 outputs)
    parameter ADDR_WIDTH = $clog2(DEPTH)       // Address width calculated from DEPTH
)(
    input  wire                    clk,
    input  wire                    rst_n,
    // Write port: writes data from the systolic array
    input  wire                    we,       // Write enable signal
    input  wire [ADDR_WIDTH-1:0]   waddr,    // Write address (provided by control logic)
    input  wire [DATA_WIDTH-1:0]   wdata,    // Data to write (e.g., one PE's c_out)
    // Read port: reads out stored data to the external interface
    input  wire                    re,       // Read enable signal
    input  wire [ADDR_WIDTH-1:0]   raddr,    // Read address (controlled by an output controller)
    output reg  [DATA_WIDTH-1:0]   rdata     // Data read out
);

    // Declare the SRAM memory array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Write operation: synchronous write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ; // Optionally, initialize the memory array here if desired.
        else if (we)
            mem[waddr] <= wdata;
    end

    // Read operation: synchronous read
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rdata <= {DATA_WIDTH{1'b0}};
        else if (re)
            rdata <= mem[raddr];
    end

endmodule
