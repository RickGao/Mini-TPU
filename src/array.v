// 4x4 array with processing elements of Systolic Array

`define DATA_WIDTH 8  // Define bit-width for input A and B
`define ACC_WIDTH  8  // Define bit-width for accumulation C


module array (
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       we,

    input  wire [`DATA_WIDTH*4-1:0]   a_in,   // 4 rows of activations
    input  wire [`DATA_WIDTH*4-1:0]   b_in,   // 4 columns of weights
    output wire [`ACC_WIDTH*16-1:0]   data_out
);

    /*=============================================
     * 1) 2‑D interconnect buses
     *===========================================*/
    // a_pipe[row][col] : activation flowing to the right
    wire [`DATA_WIDTH-1:0] a_pipe [0:3][0:4]; // 4 rows × 5 cols (last col is rightmost a_out)
    // b_pipe[row][col] : weight flowing down
    wire [`DATA_WIDTH-1:0] b_pipe [0:4][0:3]; // 5 rows × 4 cols (last row is bottom b_out)

    // c_bus[row][col] : accumulation outputs
    wire [`ACC_WIDTH-1:0]  c_bus  [0:3][0:3];

    /*=============================================
     * 2) Map external inputs to the bus
     *===========================================*/
    generate
        for (genvar row = 0; row < 4; row++) begin
            assign a_pipe[row][0] = a_in[`DATA_WIDTH*(row+1)-1:`DATA_WIDTH*row];
        end
        for (genvar col = 0; col < 4; col++) begin
            assign b_pipe[0][col] = b_in[`DATA_WIDTH*(col+1)-1:`DATA_WIDTH*col];
        end
    endgenerate

    /*=============================================
     * 3) Instantiate the 4×4 processing element grid
     *===========================================*/
    generate
        for (genvar row = 0; row < 4; row++) begin : ROWS
            for (genvar col = 0; col < 4; col++) begin : COLS
                pe pe_inst (
                    .clk   (clk),
                    .rst_n (rst_n),
                    .we    (we),

                    .a_in  (a_pipe[row][col]),
                    .b_in  (b_pipe[row][col]),
                    .a_out (a_pipe[row][col+1]),   // to the right neighbour
                    .b_out (b_pipe[row+1][col]),   // to the neighbour below
                    .c_out (c_bus [row][col])
                );
            end
        end
    endgenerate

    /*=============================================
     * 4) Flatten c_bus into data_out (row‑major order)
     *===========================================*/
    generate
        for (genvar row = 0; row < 4; row++) begin
            for (genvar col = 0; col < 4; col++) begin
                localparam int flat_idx = row*4 + col; // row‑major
                assign data_out[`ACC_WIDTH*(flat_idx+1)-1:`ACC_WIDTH*flat_idx]
                       = c_bus[row][col];
            end
        end
    endgenerate

endmodule
