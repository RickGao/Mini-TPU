// Processing Element of Systolic Array

`define DATA_WIDTH 8  // Define bit-width for input A and B
`define ACC_WIDTH 16  // Define bit-width for accumulation (C)

module pe (
    input  wire clk,
    input  wire rst_n,
    input  wire we,  // Write enable signal
    input  wire [`DATA_WIDTH-1:0] a_in,     // Input A from the left
    input  wire [`DATA_WIDTH-1:0] b_in,     // Input B from the top
    output wire [`DATA_WIDTH-1:0] a_out,    // Pass A to the right
    output wire [`DATA_WIDTH-1:0] b_out,    // Pass B to the bottom
    output wire [`ACC_WIDTH-1:0]  c_out     // Accumulated result
);

    // Internal registers to store current A and B values
    reg [`DATA_WIDTH-1:0] a_reg, b_reg;
    reg [`ACC_WIDTH-1:0]  c_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin  // Reset
            a_reg <= 0;  // Reset A register
            b_reg <= 0;  // Reset B register
            c_reg <= 0;  // Reset accumulation register
        end else if (we) begin  // Update only when we = 1
            a_reg <= a_in;  // Store the input A value
            b_reg <= b_in;  // Store the input B value
            c_reg <= c_reg + a_reg * b_reg;  // Perform multiply-accumulate operation
        end
    end

    // Pass values
    assign a_out = a_reg;
    assign b_out = b_reg;
    assign c_out = c_reg;

endmodule
