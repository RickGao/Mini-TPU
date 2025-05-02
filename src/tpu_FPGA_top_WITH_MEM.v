//============================================================================
//  Mini-TPU one-button demo  -- Nexys A7-100T top level  (Data input Method: $readmemh)
//
//  * matrix_A.mem / matrix_B.mem (16 bytes each, row-major) are read into two
//    4×4 × 8-bit ROMs during configuration.
//  * On power-up the FSM automatically:
//      1. LOADs A and B into on-chip memories
//      2. issues RUN for 10 cycles
//      3. STOREs the 16 accumulated PE results into C_buf[0-15]
//  * BTN_R (BTNR) cycles through the 16 results, showing one byte on LEDs 7-0.
//  * BTN_C (BTNC) is a global active-low reset.
//  * Clock directly uses the on-board 100 MHz crystal (safe timing on Artix-7).
//----------------------------------------------------------------------------
//  Date   : 2025-05-01
//============================================================================
`timescale 1ns/1ps

module tpu_fpga_top
(
    input  wire CLK100MHZ,        // E3 : 100 MHz system clock
    input  wire BTNC,             // H17: centre button - active-low reset
    input  wire BTNR,             // M17: right button  - next result
    output reg  [15:0] LED        // LED7-0 show result byte; LED15-8 cleared
);

/* -------------------------------------------------------------------------
 * 1) Clock & synchronous reset
 * ---------------------------------------------------------------------- */
wire clk = CLK100MHZ;             // use raw crystal for simplicity

reg [2:0] rst_pipe;
always @(posedge clk) rst_pipe <= {rst_pipe[1:0], ~BTNC};
wire rst_n = rst_pipe[2];          // de-asserted when button released

/* -------------------------------------------------------------------------
 * 2) TPU instance
 * ---------------------------------------------------------------------- */
reg  [15:0] instr;                // instruction bus
wire [7:0]  result;               // output byte selected by control

tpu u_tpu (
    .clk         (clk),
    .rst_n       (rst_n),
    .instruction (instr),
    .result      (result)
);

/* -------------------------------------------------------------------------
 * 3) Constant matrices read from external files (Method 2)
 * ---------------------------------------------------------------------- */
reg [7:0] A_ROM [0:15];
reg [7:0] B_ROM [0:15];

initial begin
    // Each file must contain 16 bytes in row-major order:
    //      a00 a01 a02 a03 a10 a11 … a33
    // Example (hex): 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 10
    $readmemh("matrix_A.mem", A_ROM);
    $readmemh("matrix_B.mem", B_ROM);
end

/* -------------------------------------------------------------------------
 * 4) Buffer to hold the final 4×4 results (row-major)
 * ---------------------------------------------------------------------- */
reg [7:0] C_buf [0:15];

/* -------------------------------------------------------------------------
 * 5) Simple FSM:  LOAD-A ? LOAD-B ? RUN ? STORE ? DONE
 * ---------------------------------------------------------------------- */
localparam S_LOAD_A = 3'd0,
           S_LOAD_B = 3'd1,
           S_RUN    = 3'd2,
           S_STORE  = 3'd3,
           S_DONE   = 3'd4;

reg [2:0] state;
reg [1:0] row, col;               // address counters
reg [3:0] run_ctr;                // counts 0-10 cycles

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state   <= S_LOAD_A;
        row     <= 2'd0;
        col     <= 2'd0;
        run_ctr <= 4'd0;
    end else begin
        case (state)
        // ---------- LOAD A -------------------------------------------------
        S_LOAD_A: begin
            instr <= {2'b10, 2'b00, row, col, A_ROM[{row,col}]};
            if (col == 2'd3) begin
                col <= 0;
                if (row == 2'd3) begin
                    row   <= 0;
                    state <= S_LOAD_B;
                end else row <= row + 1'b1;
            end else col <= col + 1'b1;
        end
        // ---------- LOAD B -------------------------------------------------
        S_LOAD_B: begin
            instr <= {2'b10, 2'b10, row, col, B_ROM[{row,col}]};
            if (col == 2'd3) begin
                col <= 0;
                if (row == 2'd3) begin
                    row   <= 0;
                    state <= S_RUN;
                end else row <= row + 1'b1;
            end else col <= col + 1'b1;
        end
        // ---------- RUN for 10 cycles -------------------------------------
        S_RUN: begin
            instr   <= {2'b01, 2'b00, 2'b00, 2'b00, 8'h00};
            run_ctr <= run_ctr + 1'b1;
            if (run_ctr == 4'd12) begin
                run_ctr <= 0;
                state   <= S_STORE;
            end
        end
        // ---------- STORE all 16 results ----------------------------------
        S_STORE: begin
            instr <= {2'b11, 2'b00, row, col, 8'h00};
            C_buf[{row,col}] <= result;
            if (col == 2'd3) begin
                col <= 0;
                if (row == 2'd3) begin
                    state <= S_DONE;
                end else row <= row + 1'b1;
            end else col <= col + 1'b1;
        end
        // ---------- DONE ---------------------------------------------------
        default: instr <= 16'h0000; // idle
        endcase
    end
end

/* -------------------------------------------------------------------------
 * 6) Front-panel viewer - BTNR cycles through the 16 bytes
 * ---------------------------------------------------------------------- */
reg btn0, btn1;                  // simple two-FF synchroniser
always @(posedge clk) begin
    btn0 <= BTNR;
    btn1 <= btn0;
end
wire next_byte = btn0 & ~btn1;   // rising edge pulse

reg [3:0] view_idx;              // 0-15 (needs 5 bits)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) view_idx <= 5'd0;
    else if (state == S_DONE && next_byte) view_idx <= view_idx + 1'b1;
end

/* show selected byte on LED7-0; clear upper LEDs */
always @(posedge clk) begin
    LED[7:0]  <= C_buf[view_idx[3:0]];  // lower 8 LEDs
    LED[15:8] <= 8'h00;                 // blank
end

endmodule
