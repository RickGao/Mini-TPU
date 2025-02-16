`default_nettype none
`timescale 1ns/1ns

module simple_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16
)(
    input  wire                   clk,
    input  wire                   reset,
    input  wire                   wr_en,
    input  wire [DATA_WIDTH-1:0]  data_in,
    input  wire                   rd_en,
    output reg  [DATA_WIDTH-1:0]  data_out,
    output reg                    empty,
    output reg                    full
);
    // Calculate address width based on DEPTH
    localparam ADDR_WIDTH = $clog2(DEPTH);
    
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0]   count; // One extra bit to count up to DEPTH
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
            empty  <= 1'b1;
            full   <= 1'b0;
        end else begin
            // Write operation
            if (wr_en && !full) begin
                mem[wr_ptr] <= data_in;
                wr_ptr <= wr_ptr + 1;
                count <= count + 1;
            end
            // Read operation
            if (rd_en && !empty) begin
                data_out <= mem[rd_ptr];
                rd_ptr <= rd_ptr + 1;
                count <= count - 1;
            end
            empty <= (count == 0);
            full  <= (count == DEPTH);
        end
    end
endmodule
