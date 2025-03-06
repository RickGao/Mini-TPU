`define DATA_WIDTH 8  // Define macro for register width

module memory (
    input wire clk,
    input wire rst_n,

    input wire write_enable,                // Write enable signal
    input wire [1:0] write_line,            // Column for writing
    input wire [1:0] write_elem,            // Row for writing
    input wire [`DATA_WIDTH-1:0] data_in,   // Data input for writing

    input wire [3:0] read_enable,           // Each bit controls whether a column outputs data
    input wire [7:0] read_elem,             // 4x2-bit, selects which row each column reads from
    output wire [`DATA_WIDTH*4-1:0] data_out // 4-column output, each with DATA_WIDTH-bit width
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

    // Asynchronous read using generate loop
    // Assign outputs based on read_enable and read_elem values
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : read_output_gen
            assign data_out[`DATA_WIDTH*(i+1)-1:`DATA_WIDTH*i] = 
                read_enable[i] ? mem[i][read_elem[i*2+1:i*2]] : {`DATA_WIDTH{1'b0}};
        end
    endgenerate

endmodule