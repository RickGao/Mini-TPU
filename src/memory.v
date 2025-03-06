`define DATA_WIDTH 8  // Define macro for register width

module memory (
    input wire clk,
    input wire rst_n,

    input wire write_enable,            // Write enable signal
    input wire [1:0] write_line,        // Column for writing
    input wire [1:0] write_elem,        // Row for writing
    input wire [`DATA_WIDTH-1:0] data_in,   // Data input for writing

<<<<<<< HEAD
    input wire [3:0] read_enable,           // Each bit controls whether a column outputs data
    input wire [7:0] read_elem,             // 4x2-bit, selects which row each column reads from
    output wire [`DATA_WIDTH*4-1:0] data_out // 4-column output, each with DATA_WIDTH-bit width
=======
    input wire [3:0] read_enable,       // Each bit controls whether a column outputs data
    input wire [7:0] read_elem,         // 4x2-bit, selects which row each column reads from
    output wire [4*`DATA_WIDTH-1:0] data_out  // 4-column output, each with DATA_WIDTH-bit width
>>>>>>> d2448639699c9fc25f230dcc2959e9bbdf5ffc1e
);

    wire [1:0] read_elem0 = read_elem[1:0];
    wire [1:0] read_elem1 = read_elem[3:2];
    wire [1:0] read_elem2 = read_elem[5:4];
    wire [1:0] read_elem3 = read_elem[7:6];
    
    wire [`DATA_WIDTH-1:0] data_out0 = data_out [`DATA_WIDTH-1:0];
    wire [`DATA_WIDTH-1:0] data_out1 = data_out [2*`DATA_WIDTH-1:`DATA_WIDTH];
    wire [`DATA_WIDTH-1:0] data_out2 = data_out [3*`DATA_WIDTH-1:2*`DATA_WIDTH];
    wire [`DATA_WIDTH-1:0] data_out3 = data_out [4*`DATA_WIDTH-1:3*`DATA_WIDTH];

    // 4x4 memory array, each cell is DATA_WIDTH-bit register
    reg [`DATA_WIDTH-1:0] mem [3:0][3:0];

    integer line, elem;
    
    // Extract individual read_elem values
    wire [1:0] read_elem_0 = read_elem[1:0];
    wire [1:0] read_elem_1 = read_elem[3:2];
    wire [1:0] read_elem_2 = read_elem[5:4];
    wire [1:0] read_elem_3 = read_elem[7:6];
    
    // Individual output signals
    wire [`DATA_WIDTH-1:0] data_out_0;
    wire [`DATA_WIDTH-1:0] data_out_1;
    wire [`DATA_WIDTH-1:0] data_out_2;
    wire [`DATA_WIDTH-1:0] data_out_3;
    
    // Combine individual outputs into a single bus
    assign data_out = {data_out_3, data_out_2, data_out_1, data_out_0};

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
    // Assign outputs based on read_enable and read_elem values
<<<<<<< HEAD
    assign data_out_0 = read_enable[0] ? mem[0][read_elem_0] : {`DATA_WIDTH{1'b0}};
    assign data_out_1 = read_enable[1] ? mem[1][read_elem_1] : {`DATA_WIDTH{1'b0}};
    assign data_out_2 = read_enable[2] ? mem[2][read_elem_2] : {`DATA_WIDTH{1'b0}};
    assign data_out_3 = read_enable[3] ? mem[3][read_elem_3] : {`DATA_WIDTH{1'b0}};
=======
    assign data_out0 = read_enable[0] ? mem[0][read_elem0] : {`DATA_WIDTH{1'b0}};
    assign data_out1 = read_enable[1] ? mem[1][read_elem1] : {`DATA_WIDTH{1'b0}};
    assign data_out2 = read_enable[2] ? mem[2][read_elem2] : {`DATA_WIDTH{1'b0}};
    assign data_out3 = read_enable[3] ? mem[3][read_elem3] : {`DATA_WIDTH{1'b0}};
>>>>>>> d2448639699c9fc25f230dcc2959e9bbdf5ffc1e

endmodule
