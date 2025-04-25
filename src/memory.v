`define DATA_WIDTH 8 // Define macro for register width
module memory (
    input wire clk,
    input wire rst_n,
    input wire write_enable, // Write enable signal
    input wire [1:0] write_line, // Column for writing
    input wire [1:0] write_elem, // Row for writing
    input wire [`DATA_WIDTH-1:0] data_in, // Data input for writing
    input wire [3:0] read_enable, // Each bit controls whether a column outputs data
    input wire [7:0] read_elem, // 4x2-bit, selects which row each column reads from
    output wire [`DATA_WIDTH*4-1:0] data_out // 4-column output, each with DATA_WIDTH-bit width
);
    // 4x4 memory array, each cell is DATA_WIDTH-bit register
    reg [`DATA_WIDTH-1:0] mem [0:15];
    // Define internal arrays to better organize the data flow
    wire [1:0] read_elem_array [3:0]; // Internal array for read element selectors
    wire [`DATA_WIDTH-1:0] data_out_array [3:0]; // Internal array for data outputs
    
    // Map packed read_elem input to unpacked read_elem_array
    genvar read_line;
    generate
        for (read_line = 0; read_line < 4; read_line = read_line + 1) begin : map_read_elem
            assign read_elem_array[read_line] = read_elem[read_line*2+1:read_line*2];
        end
    endgenerate
    
    // Map internal data_out_array to packed data_out output
    genvar out_line;
    generate
        for (out_line = 0; out_line < 4; out_line = out_line + 1) begin : map_data_out
            assign data_out[`DATA_WIDTH*(out_line+1)-1:`DATA_WIDTH*out_line] = data_out_array[out_line];
        end
    endgenerate
    
    integer i;
    // Reset: Initialize all memory cells to 0 when rst_n is LOW
    always @(negedge rst_n) begin
    for (i = 0; i < 16; i = i + 1)
        mem[i] <= {`DATA_WIDTH{1'b0}};
    end
    
    // Synchronous write: Data is written on the rising edge of clk
    wire [3:0] index_write = write_line * 4 + write_elem;
    always @(posedge clk) begin
        if (write_enable)
            mem[index_write] <= data_in;
    end
    
    // Asynchronous read using generate loop with internal arrays
    // Assign outputs based on read_enable and read_elem values
    genvar line;
    generate
        for (line = 0; line < 4; line = line + 1) begin : read_output_gen
            wire [3:0] index_read = line * 4 + read_elem_array[line];
            assign data_out_array[line] = read_enable[line] ? mem[index_read] : {`DATA_WIDTH{1'b0}};
        end
    endgenerate

endmodule