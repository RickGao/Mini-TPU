`define DATA_WIDTH 8  // Define bit-width for input A and B
`define ACC_WIDTH 16  // Define bit-width for accumulation C

module array (
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          we,       // Write enable (when high, each PE performs its MAC)
    // Unified input/output buses
    input  wire [`DATA_WIDTH*4-1:0]      a_in,     // Packed activation inputs for all rows
    input  wire [`DATA_WIDTH*4-1:0]      b_in,     // Packed weight inputs for all columns (top row)
    output wire [`ACC_WIDTH*16-1:0]      array_data_out // Packed outputs for all PEs (16 elements total)
);

    // Arrays to hold unpacked signals
    wire [`DATA_WIDTH-1:0] a_in_array [0:3];     // Unpacked row activation inputs
    wire [`DATA_WIDTH-1:0] b_in_array [0:3];     // Unpacked column weight inputs
    wire [`ACC_WIDTH-1:0]  c_out_array [0:15];   // Unpacked PE outputs (flattened)

    // Internal connection arrays for PE-to-PE data flow
    wire [`DATA_WIDTH-1:0] a_wire [0:15];  // 4x4 PE activation flow (flattened)
    wire [`DATA_WIDTH-1:0] b_wire [0:15];  // 4x4 PE weight flow (flattened)

    // Unpack input buses to arrays
    genvar input_idx;
    generate
        for (input_idx = 0; input_idx < 4; input_idx = input_idx + 1) begin : unpack_inputs
            assign a_in_array[input_idx] = a_in[`DATA_WIDTH*(input_idx+1)-1:`DATA_WIDTH*input_idx];
            assign b_in_array[input_idx] = b_in[`DATA_WIDTH*(input_idx+1)-1:`DATA_WIDTH*input_idx];
        end
    endgenerate

    // Pack outputs to the output bus
    genvar pe_idx;
    generate
        for (pe_idx = 0; pe_idx < 16; pe_idx = pe_idx + 1) begin : pack_outputs
            assign array_data_out[`ACC_WIDTH*(pe_idx+1)-1:`ACC_WIDTH*pe_idx] = c_out_array[pe_idx];
        end
    endgenerate

    // Instantiate the PE array using generate
    genvar row_idx, col_idx;
    generate
        for (row_idx = 0; row_idx < 4; row_idx = row_idx + 1) begin : pe_row_gen
            for (col_idx = 0; col_idx < 4; col_idx = col_idx + 1) begin : pe_col_gen
                wire [`DATA_WIDTH-1:0] a_input, b_input;
                localparam linear_idx = row_idx * 4 + col_idx;
                
                // Handle boundary conditions safely
                // For a_input: use external input at column 0, otherwise use output from the left PE
                if (col_idx == 0) begin
                    assign a_input = a_in_array[row_idx];
                end else begin
                    assign a_input = a_wire[linear_idx - 1];
                end
                
                // For b_input: use external input at row 0, otherwise use output from the above PE
                if (row_idx == 0) begin
                    assign b_input = b_in_array[col_idx];
                end else begin
                    assign b_input = b_wire[linear_idx - 4];
                end
                
                // Instantiate each PE
                pe pe_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .we(we),
                    .a_in(a_input),
                    .b_in(b_input),
                    .a_out(a_wire[linear_idx]),  // Output to the right
                    .b_out(b_wire[linear_idx]),  // Output downward
                    .c_out(c_out_array[linear_idx])
                );
            end
        end
    endgenerate

endmodule