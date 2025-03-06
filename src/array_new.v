`define DATA_WIDTH 8  // Define bit-width for input A and B
`define ACC_WIDTH 16  // Define bit-width for accumulation C


module array (
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       we,       // Write enable (when high, each PE performs its MAC)
    // External activation inputs (one per row)
    input  wire [`DATA_WIDTH*4-1:0]   a_in,    // Combined a_in inputs (a_in3, a_in2, a_in1, a_in0)
    // External weight inputs (one per column, for the top row)
    input  wire [`DATA_WIDTH*4-1:0]   b_in,    // Combined b_in inputs (b_in3, b_in2, b_in1, b_in0)
    // Outputs: accumulated results from each PE
    output wire [`ACC_WIDTH*16-1:0]   c_out    // Combined c_out outputs (c33...c00)
);

    // Wires for activation signals between PEs
    wire [`DATA_WIDTH-1:0] a_wire[3:0][3:0];
    
    // Wires for weight signals between PEs
    wire [`DATA_WIDTH-1:0] b_wire[3:0][3:0];
    
    // Break out individual c_out values for readability
    wire [`ACC_WIDTH-1:0] c[3:0][3:0];
    
    // Map individual c outputs to the combined c_out bus
    genvar x, y;
    generate
        for (y = 0; y < 4; y = y + 1) begin : map_c_rows
            for (x = 0; x < 4; x = x + 1) begin : map_c_cols
                assign c_out[`ACC_WIDTH*(y*4+x+1)-1:`ACC_WIDTH*(y*4+x)] = c[y][x];
            end
        end
    endgenerate
    
    // Instantiate processing elements using generate
    generate
        for (y = 0; y < 4; y = y + 1) begin : pe_rows
            for (x = 0; x < 4; x = x + 1) begin : pe_cols
                // Determine a_in source for this PE
                wire [`DATA_WIDTH-1:0] a_src;
                if (x == 0) begin
                    // First column gets external input
                    assign a_src = a_in[`DATA_WIDTH*(y+1)-1:`DATA_WIDTH*y];
                end else begin
                    // Other columns get input from left neighbor
                    assign a_src = a_wire[y][x-1];
                end
                
                // Determine b_in source for this PE
                wire [`DATA_WIDTH-1:0] b_src;
                if (y == 0) begin
                    // First row gets external input
                    assign b_src = b_in[`DATA_WIDTH*(x+1)-1:`DATA_WIDTH*x];
                end else begin
                    // Other rows get input from above neighbor
                    assign b_src = b_wire[y-1][x];
                end
                
                // Instantiate the PE
                pe pe_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .we(we),
                    .a_in(a_src),
                    .b_in(b_src),
                    .a_out(a_wire[y][x]),
                    .b_out(b_wire[y][x]),
                    .c_out(c[y][x])
                );
            end
        end
    endgenerate

endmodule