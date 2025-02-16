`default_nettype none
`timescale 1ns/1ns

module simple_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,       // Active-low reset
    input  wire                   wr_en,       // Write enable
    input  wire [DATA_WIDTH-1:0]  data_in,
    input  wire                   rd_en,       // Read enable
    output reg  [DATA_WIDTH-1:0]  data_out,
    output reg                    empty,
    output reg                    full
);

    // Calculate address width based on DEPTH
    localparam ADDR_WIDTH = $clog2(DEPTH);

    // Memory storage
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0]   count;  // One extra bit to count up to DEPTH

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            wr_ptr <= {ADDR_WIDTH{1'b0}};
            rd_ptr <= {ADDR_WIDTH{1'b0}};
            count  <= {ADDR_WIDTH+1{1'b0}};
            empty  <= 1'b1;
            full   <= 1'b0;
            data_out <= {DATA_WIDTH{1'b0}};
        end else begin
            // WRITE operation
            if (wr_en && !full) begin
                mem[wr_ptr] <= data_in;
                wr_ptr <= wr_ptr + 1;
                count  <= count + 1;
            end

            // READ operation
            if (rd_en && !empty) begin
                data_out <= mem[rd_ptr];
                rd_ptr <= rd_ptr + 1;
                count  <= count - 1;
            end

            // Update flags
            empty <= (count == 0);
            full  <= (count == DEPTH);
        end
    end

endmodule
