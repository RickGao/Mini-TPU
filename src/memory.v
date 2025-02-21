`define DATA_WIDTH 8  // Define macro for register width

module memory (
    input wire clk,
    input wire rst_n,

    input wire write_enable,            // Write enable signal
    input wire [1:0] write_line,        // Column for writing
    input wire [1:0] write_elem,        // Row for writing
    input wire [`DATA_WIDTH-1:0] data_in,   // Data input for writing

    input wire [3:0] read_enable,       // Each bit controls whether a column outputs data
    input wire [7:0] read_elem,         // 4x2-bit, selects which row each column reads from
    output wire [`DATA_WIDTH-1:0] data_out [3:0]  // 4-column output, each with DATA_WIDTH-bit width
);

    // 4x4 memory array, each cell is DATA_WIDTH-bit register
    reg [`DATA_WIDTH-1:0] mem [3:0][3:0];

    integer i, j;

    // Reset: Initialize all memory cells to 0 when rst_n is LOW
    always @(negedge rst_n) begin
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                mem[i][j] <= {`DATA_WIDTH{1'b0}};
            end
        end
    end

    // Synchronous write: Data is written on the rising edge of clk
    always @(posedge clk) begin
        if (write_enable) begin
            mem[write_line][write_elem] <= data_in;
        end
    end

    // Asynchronous read
    always @(*) begin
        for (i = 0; i < 4; i = i + 1) begin
            if (read_enable[i]) begin
                data_out[i] = mem[read_elem[2*i +: 2]][i];  // Select row based on read_select
            end else begin
                data_out[i] = {`DATA_WIDTH{1'b0}};  // Output 0 if read_enable is 0
            end
        end
    end

endmodule
