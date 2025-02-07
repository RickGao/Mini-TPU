`define DATA_WIDTH 8  // Define bit-width for input A and B
`define ACC_WIDTH 16


module pe (
    input  wire clk,
    input  wire rst_n,
    input  wire [`DATA_WIDTH-1:0] a_in,   // from the left
    input  wire [`DATA_WIDTH-1:0] b_in,   // from the top
    input  wire [`ACC_WIDTH-1:0]  c_in,   // partial sum from above
    output wire [`DATA_WIDTH-1:0] a_out,  // to the right
    output wire [`DATA_WIDTH-1:0] b_out,  // to the bottom
    output wire [`ACC_WIDTH-1:0]  c_out   // updated partial sum
);

    reg [`DATA_WIDTH-1:0] a_reg, b_reg;
    reg [`ACC_WIDTH-1:0] c_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg <= 0;
            b_reg <= 0;
            c_reg <= 0;
        end 
        else begin
            // Pipeline the A and B values each cycle
            a_reg <= a_in;
            b_reg <= b_in;

            // Multiply-Accumulate using old latched A/B or direct inputs,
            // depending on your pipeline design:
            c_reg <= c_in + (a_in * b_in);  
            // or c_reg <= c_in + (a_reg * b_reg);
        end
    end

    assign a_out = a_reg;  
    assign b_out = b_reg;  
    assign c_out = c_reg;

endmodule
