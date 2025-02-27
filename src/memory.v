`define DATA_WIDTH 8  // Define macro for register width

module memory (
    input wire clk,
    input wire rst_n,

    input wire write_enable,            // Write enable signal
    input wire [1:0] write_line,        // Column for writing
    input wire [1:0] write_elem,        // Row for writing
    input wire [`DATA_WIDTH-1:0] data_in,   // Data input for writing

    input wire [3:0] read_enable,       // Each bit controls whether a column outputs data
    input wire [1:0] read_elem [3:0],         // 4x2-bit, selects which row each column reads from
    output wire [`DATA_WIDTH-1:0] data_out [3:0]  // 4-column output, each with DATA_WIDTH-bit width
);

    // 4x4 memory array, each cell is DATA_WIDTH-bit register
    reg [`DATA_WIDTH-1:0] mem [3:0][3:0];

    integer line, elem;

    // Reset: Initialize all memory cells to 0 when rst_n is LOW
    always @(negedge rst_n) begin
        for (line = 0; line < 4; line = line + 1) begin
            for (elem = 0; elem < 4; elem = elem + 1) begin
                mem[line][elem] <= {`DATA_WIDTH{1'b0}};
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
        for (line = 0; line < 4; line = line + 1) begin
            if (read_enable[line]) begin
                data_out[i] = mem[line][read_elem[line]];  // Select row based on read_elem
            end else begin
                data_out[i] = {`DATA_WIDTH{1'b0}};  // Output 0 if read_enable is 0
            end
        end
    end

endmodule
