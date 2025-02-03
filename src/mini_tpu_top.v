// Basic Systolic Array Structure for Tiny Tapeout

// Top-level module
module systolic_array #(parameter N = 4, DATA_WIDTH = 8) (
    input wire clk,
    input wire rst,
    input wire [N*DATA_WIDTH-1:0] a,
    input wire [N*DATA_WIDTH-1:0] b,
    output wire [N*DATA_WIDTH-1:0] result
);

    // Internal registers and wires
    reg [DATA_WIDTH-1:0] P[N-1:0][N-1:0];
    reg [DATA_WIDTH-1:0] A[N-1:0];
    reg [DATA_WIDTH-1:0] B[N-1:0];
    
    integer i, j;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    P[i][j] <= 0;
                end
                A[i] <= 0;
                B[i] <= 0;
            end
        end else begin
            for (i = 0; i < N; i = i + 1) begin
                A[i] <= a[i*DATA_WIDTH +: DATA_WIDTH];
                B[i] <= b[i*DATA_WIDTH +: DATA_WIDTH];
            end
            
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    P[i][j] <= A[i] * B[j];
                end
            end
        end
    end
    
    // Flatten the result output
    generate
        genvar x, y;
        for (x = 0; x < N; x = x + 1) begin
            for (y = 0; y < N; y = y + 1) begin
                assign result[(x*N + y)*DATA_WIDTH +: DATA_WIDTH] = P[x][y];
            end
        end
    endgenerate

endmodule
