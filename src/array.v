`define DATA_WIDTH 8  // Define bit-width for input A and B
`define ACC_WIDTH 16  // Define bit-width for accumulation C


module systolic_array_4x4 (
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       we,       // Write enable (when high, each PE performs its MAC)
    // External activation inputs (one per row)
    input  wire [`DATA_WIDTH-1:0]     a_in0,
    input  wire [`DATA_WIDTH-1:0]     a_in1,
    input  wire [`DATA_WIDTH-1:0]     a_in2,
    input  wire [`DATA_WIDTH-1:0]     a_in3,
    // External weight inputs (one per column, for the top row)
    input  wire [`DATA_WIDTH-1:0]     b_in0,
    input  wire [`DATA_WIDTH-1:0]     b_in1,
    input  wire [`DATA_WIDTH-1:0]     b_in2,
    input  wire [`DATA_WIDTH-1:0]     b_in3,
    // Outputs: accumulated results from each PE (each 4�4 element)
    output wire [`ACC_WIDTH-1:0]      c00, c01, c02, c03,
    output wire [`ACC_WIDTH-1:0]      c10, c11, c12, c13,
    output wire [`ACC_WIDTH-1:0]      c20, c21, c22, c23,
    output wire [`ACC_WIDTH-1:0]      c30, c31, c32, c33
);

    // Wires for activation signals between PEs (each is DATA_WIDTH wide)
    // Row 0
    wire [`DATA_WIDTH-1:0] a00, a01, a02, a03;
    // Row 1
    wire [`DATA_WIDTH-1:0] a10, a11, a12, a13;
    // Row 2
    wire [`DATA_WIDTH-1:0] a20, a21, a22, a23;
    // Row 3
    wire [`DATA_WIDTH-1:0] a30, a31, a32, a33;

    // Wires for weight signals between PEs (each is DATA_WIDTH wide)
    // Row 0 (outputs from row 0 PEs, which feed row 1)
    wire [`DATA_WIDTH-1:0] b00, b01, b02, b03;
    // Row 1
    wire [`DATA_WIDTH-1:0] b10, b11, b12, b13;
    // Row 2
    wire [`DATA_WIDTH-1:0] b20, b21, b22, b23;
    // Row 3
    wire [`DATA_WIDTH-1:0] b30, b31, b32, b33;

    // -----------------------------------------
    // Row 0 (Top row): use external activation and weight inputs
    // -----------------------------------------
    // Column 0, row 0
    pe pe00 (
        .clk(clk), .rst_n(rst_n), .we(we),
        .a_in(a_in0),         // external activation for row 0
        .b_in(b_in0),         // external weight for col 0
        .a_out(a00),          // pass activation to the right
        .b_out(b00),          // pass weight downward
        .c_out(c00)           // partial (final) output for position (0,0)
    );

    // Column 1, row 0
    pe pe01 (
        .clk(clk), .rst_n(rst_n), .we(we),
        .a_in(a00),           // from left neighbor
        .b_in(b_in1),         // external weight for col 1
        .a_out(a01),
        .b_out(b01),
        .c_out(c01)
    );

    // Column 2, row 0
    pe pe02 (
        .clk(clk), .rst_n(rst_n), .we(we),
        .a_in(a01),           // from left neighbor
        .b_in(b_in2),         // external weight for col 2
        .a_out(a02),
        .b_out(b02),
        .c_out(c02)
    );

    // Column 3, row 0
    pe pe03 (
        .clk(clk), .rst_n(rst_n), .we(we),
        .a_in(a02),           // from left neighbor
        .b_in(b_in3),         // external weight for col 3
        .a_out(a03),
        .b_out(b03),
        .c_out(c03)
    );

    // -----------------------------------------
    // Row 1
    // -----------------------------------------
    // Column 0, row 1: activation comes from external input; weight comes from the PE above (row 0, col 0)
    pe pe10 (
        .clk(clk), .rst_n(rst_n), .we(we),
        .a_in(a_in1),         // external activation for row 1
        .b_in(b00),           // from row 0, col 0
        .a_out(a10),
        .b_out(b10),
        .c_out(c10)
    );

    // Column 1, row 1
    pe pe11 (
        .clk(clk), .rst_n(rst_n), .we(we),
        .a_in(a10),           // from left neighbor (row 1, col 0)
        .b_in(b01),           // from above (row 0, col 1)
        .a_out(a11),
        .b_out(b11),
        .c_out(c11)
    );

    // Column 2, row 1
    pe pe12 (
        .clk(clk), .rst_n(rst_n), .we(we),
        .a_in(a11),           // from left neighbor
        .b_in(b02),           // from above (row 0, col 2)
        .a_out(a12),
        .b_out(b12),
        .c_out(c12)
    );

    // Column 3, row 1
    pe pe13 (
        .clk(clk), .rst_n(rst_n), .we(we),
        .a_in(a12),           // from left neighbor
        .b_in(b03),           // from above (row 0, col 3)
        .a_out(a13),
        .b_out(b13),
        .c_out(c13)
    );

    // -----------------------------------------
    // Row 2
    // -----------------------------------------
    // Column 0, row 2
    pe pe20 (
        .clk(clk), .rst_n(rst_n), .we(we),
        .a_in(a_in2),         // external activation for row 2
        .b_in(b10),           // from above (row 1, col 0)
        .a_out(a20),
        .b_out(b20),
        .c_out(c20)
    );

    // Column 1, row 2
    pe pe21 (
        .clk(clk), .rst_n(rst_n), .we(we),
        .a_in(a20),           // from left neighbor
        .b_in(b11),           // from above (row 1, col 1)
        .a_out(a21),
        .b_out(b21),
        .c_out(c21)
    );

    // Column 2, row 2
    pe pe22 (
        .clk(clk), .rst_n(rst_n), .we(we),
        .a_in(a21),           // from left neighbor
        .b_in(b12),           // from above (row 1, col 2)
        .a_out(a22),
        .b_out(b22),
        .c_out(c22)
    );

    // Column 3, row 2
    pe pe23 (
        .clk(clk), .rst_n(rst_n), .we(we),
        .a_in(a22),           // from left neighbor
        .b_in(b13),           // from above (row 1, col 3)
        .a_out(a23),
        .b_out(b23),
        .c_out(c23)
    );

    // -----------------------------------------
    // Row 3
    // -----------------------------------------
    // Column 0, row 3
    pe pe30 (
        .clk(clk), .rst_n(rst_n), .we(we),
        .a_in(a_in3),         // external activation for row 3
        .b_in(b20),           // from above (row 2, col 0)
        .a_out(a30),
        .b_out(b30),
        .c_out(c30)
    );

    // Column 1, row 3
    pe pe31 (
        .clk(clk), .rst_n(rst_n), .we(we),
        .a_in(a30),           // from left neighbor
        .b_in(b21),           // from above (row 2, col 1)
        .a_out(a31),
        .b_out(b31),
        .c_out(c31)
    );

    // Column 2, row 3
    pe pe32 (
        .clk(clk), .rst_n(rst_n), .we(we),
        .a_in(a31),           // from left neighbor
        .b_in(b22),           // from above (row 2, col 2)
        .a_out(a32),
        .b_out(b32),
        .c_out(c32)
    );

    // Column 3, row 3
    pe pe33 (
        .clk(clk), .rst_n(rst_n), .we(we),
        .a_in(a32),           // from left neighbor
        .b_in(b23),           // from above (row 2, col 3)
        .a_out(a33),
        .b_out(b33),
        .c_out(c33)
    );

endmodule
