`timescale 1ns / 1ps
class systolic_trans;
  // Randomized fields
  rand bit [7:0] a_in0, a_in1, a_in2, a_in3;
  rand bit [7:0] b_in0, b_in1, b_in2, b_in3;
  rand bit       we;  // whether to enable MAC for that cycle

  // Keep inputs small to avoid very large prosducts
  constraint small_inputs {
    a_in0 < 16; a_in1 < 16;
    a_in2 < 16; a_in3 < 16;
    b_in0 < 16; b_in1 < 16;
    b_in2 < 16; b_in3 < 16;
  }
  
  bit [`ACC_WIDTH-1:0] c00, c01, c02, c03;
  bit [`ACC_WIDTH-1:0] c10, c11, c12, c13;
  bit [`ACC_WIDTH-1:0] c20, c21, c22, c23;
  bit [`ACC_WIDTH-1:0] c30, c31, c32, c33;

endclass



class systolic_generator;
  mailbox #(systolic_trans) gen2drv_mb; // from generator to driver
  systolic_trans tr;
  int num_transactions;                 // random transactions to generate counter

  // Event synchronization with scoreboard
  event done_gen;

  function new(mailbox #(systolic_trans) mb);
    this.gen2drv_mb      = mb;
  endfunction

  task run();
    for(int i=0; i<num_transactions; i++) begin
      tr = new();
      if (!tr.randomize()) begin
        $error("Randomization failed for systolic_trans!");
      end
      // Print for debug
      $display("[GEN] Cycle %0d: a_in0=%0d a_in1=%0d a_in2=%0d a_in3=%0d | b_in0=%0d b_in1=%0d b_in2=%0d b_in3=%0d | we=%b",
               i, tr.a_in0, tr.a_in1, tr.a_in2, tr.a_in3, tr.b_in0, tr.b_in1, tr.b_in2, tr.b_in3, tr.we);
      gen2drv_mb.put(tr);
    end
    -> done_gen;
  endtask
endclass

class systolic_driver;
  virtual systolic_if vif;

  mailbox #(systolic_trans) drv_mb;
  systolic_trans tr;

  function new(virtual systolic_if vif, mailbox #(systolic_trans) mb);
    this.vif    = vif;
    this.drv_mb = mb;
  endfunction

  task reset_dut();
    vif.rst_n <= 0;
    vif.we    <= 0;
    vif.a_in0 <= 0; vif.a_in1 <= 0; vif.a_in2 <= 0; vif.a_in3 <= 0;
    vif.b_in0 <= 0; vif.b_in1 <= 0; vif.b_in2 <= 0; vif.b_in3 <= 0;
    repeat(5) @(posedge vif.clk);
    vif.rst_n <= 1;
  endtask

  task run();
    forever begin
      drv_mb.get(tr);   // Block until a transaction is available
      @(posedge vif.clk);
      if (!vif.rst_n) @(posedge vif.clk); // Wait if still in reset

      // Drive signals
      vif.we    <= tr.we;
      vif.a_in0 <= tr.a_in0;
      vif.a_in1 <= tr.a_in1;
      vif.a_in2 <= tr.a_in2;
      vif.a_in3 <= tr.a_in3;
      vif.b_in0 <= tr.b_in0;
      vif.b_in1 <= tr.b_in1;
      vif.b_in2 <= tr.b_in2;
      vif.b_in3 <= tr.b_in3;
    end
  endtask
endclass

class systolic_monitor;
  virtual systolic_if vif;

  mailbox #(systolic_trans) mon2sco_mb; // mailbox to scoreboard

  function new(virtual systolic_if vif, mailbox #(systolic_trans) mb);
    this.vif       = vif;
    this.mon2sco_mb = mb;
  endfunction

  task run();
    systolic_trans t;
    forever begin
      @(posedge vif.clk);
      if (vif.rst_n) begin
        t = new();
        // Capture the current inputs
        t.a_in0 = vif.a_in0;
        t.a_in1 = vif.a_in1;
        t.a_in2 = vif.a_in2;
        t.a_in3 = vif.a_in3;
        t.b_in0 = vif.b_in0;
        t.b_in1 = vif.b_in1;
        t.b_in2 = vif.b_in2;
        t.b_in3 = vif.b_in3;
        t.we    = vif.we;

        // We'll store the current outputs in "extra fields"
        // You can add them to systolic_trans or create a separate struct.
        // For brevity, let's just embed them here:
        t.c00 = vif.c00;
        t.c01 = vif.c01;
        t.c02 = vif.c02;
        t.c03 = vif.c03;
        t.c10 = vif.c10;
        t.c11 = vif.c11;
        t.c12 = vif.c12;
        t.c13 = vif.c13;
        t.c20 = vif.c20;
        t.c21 = vif.c21;
        t.c22 = vif.c22;
        t.c23 = vif.c23;
        t.c30 = vif.c30;
        t.c31 = vif.c31;
        t.c32 = vif.c32;
        t.c33 = vif.c33;

        mon2sco_mb.put(t);
      end
    end
  endtask
endclass

class systolic_scoreboard;
  mailbox #(systolic_trans) mon2sco_mb;

  // Reference partial sums
  int ref_c[4][4];

  function new(mailbox #(systolic_trans) mb);
    mon2sco_mb = mb;
  endfunction

  task run();
    systolic_trans t;
    // Initialize reference array
    foreach (ref_c[i,j]) ref_c[i][j] = 0;

    forever begin
      mon2sco_mb.get(t); // Wait for next monitor sample

      // If we == 1, update the reference partial sums with (a_in[row]*b_in[col]).
      // row is 0..3, col is 0..3.
      if (t.we) begin
        ref_c[0][0] += t.a_in0 * t.b_in0;
        ref_c[0][1] += t.a_in0 * t.b_in1;
        ref_c[0][2] += t.a_in0 * t.b_in2;
        ref_c[0][3] += t.a_in0 * t.b_in3;
        
        ref_c[1][0] += t.a_in1 * t.b_in0;
        ref_c[1][1] += t.a_in1 * t.b_in1;
        ref_c[1][2] += t.a_in1 * t.b_in2;
        ref_c[1][3] += t.a_in1 * t.b_in3;

        ref_c[2][0] += t.a_in2 * t.b_in0;
        ref_c[2][1] += t.a_in2 * t.b_in1;
        ref_c[2][2] += t.a_in2 * t.b_in2;
        ref_c[2][3] += t.a_in2 * t.b_in3;

        ref_c[3][0] += t.a_in3 * t.b_in0;
        ref_c[3][1] += t.a_in3 * t.b_in1;
        ref_c[3][2] += t.a_in3 * t.b_in2;
        ref_c[3][3] += t.a_in3 * t.b_in3;
      end

      // Compare scoreboard vs. DUT
      if ((t.c00 != ref_c[0][0]) || (t.c01 != ref_c[0][1]) ||
           (t.c02 != ref_c[0][2]) || (t.c03 != ref_c[0][3]) ||
           (t.c10 != ref_c[1][0]) || (t.c11 != ref_c[1][1]) ||
           (t.c12 != ref_c[1][2]) || (t.c13 != ref_c[1][3]) ||
           (t.c20 != ref_c[2][0]) || (t.c21 != ref_c[2][1]) ||
           (t.c22 != ref_c[2][2]) || (t.c23 != ref_c[2][3]) ||
           (t.c30 != ref_c[3][0]) || (t.c31 != ref_c[3][1]) ||
           (t.c32 != ref_c[3][2]) || (t.c33 != ref_c[3][3])) 
           begin
        $error("[SCOREBOARD] Mismatch: DUT outputs do not match the reference model!");
        $display("Expected: row0=%0d,%0d,%0d,%0d row1=%0d,%0d,%0d,%0d row2=%0d,%0d,%0d,%0d row3=%0d,%0d,%0d,%0d",
                 ref_c[0][0], ref_c[0][1], ref_c[0][2], ref_c[0][3],
                 ref_c[1][0], ref_c[1][1], ref_c[1][2], ref_c[1][3],
                 ref_c[2][0], ref_c[2][1], ref_c[2][2], ref_c[2][3],
                 ref_c[3][0], ref_c[3][1], ref_c[3][2], ref_c[3][3]);
        $display("Got:      row0=%0d,%0d,%0d,%0d row1=%0d,%0d,%0d,%0d row2=%0d,%0d,%0d,%0d row3=%0d,%0d,%0d,%0d",
                 c00, c01, c02, c03,
                 c10, c11, c12, c13,
                 c20, c21, c22, c23,
                 c30, c31, c32, c33);
      end
      else begin
        $display("[SCOREBOARD] PASS for current cycle: All outputs match reference.");
      end
    end
  endtask
endclass




module tb;
  // Interface instantiation
  systolic_if sif();

  // DUT instantiation
  systolic_array_4x4 dut (
    .clk    (sif.clk),
    .rst_n  (sif.rst_n),
    .we     (sif.we),
    .a_in0  (sif.a_in0), .a_in1  (sif.a_in1), .a_in2  (sif.a_in2), .a_in3  (sif.a_in3),
    .b_in0  (sif.b_in0), .b_in1  (sif.b_in1), .b_in2  (sif.b_in2), .b_in3  (sif.b_in3),
    .c00    (sif.c00),   .c01    (sif.c01),   .c02    (sif.c02),   .c03    (sif.c03),
    .c10    (sif.c10),   .c11    (sif.c11),   .c12    (sif.c12),   .c13    (sif.c13),
    .c20    (sif.c20),   .c21    (sif.c21),   .c22    (sif.c22),   .c23    (sif.c23),
    .c30    (sif.c30),   .c31    (sif.c31),   .c32    (sif.c32),   .c33    (sif.c33)
  );

  // Clock generation
  initial sif.clk = 0;
  always #5 sif.clk = ~sif.clk;

  // Instantiate mailboxes
  mailbox #(systolic_trans) gen2drv_mb   = new();
  mailbox #(systolic_trans) mon2sco_mb  = new();

  // Instantiate classes
  systolic_generator   gen;
  systolic_driver      drv;
  systolic_monitor     mon;
  systolic_scoreboard  sco;

  initial begin
    // Optionally dump waves
    // $dumpfile("waves.vcd");
    // $dumpvars(0, tb);

    // Create generator (generate 20 transactions)
    gen = new(gen2drv_mb);

    // Create driver
    drv = new(sif, gen2drv_mb);

    // Create monitor
    mon = new(sif, mon2sco_mb);

    // Create scoreboard
    sco = new(mon2sco_mb);

    // Reset sequence
    drv.reset_dut();

    // Fork off processes
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any

    // Wait for generator to finish
    wait(gen.done_gen.triggered);
    // Let some cycles pass to check final results
    repeat(10) @(posedge sif.clk);
    $finish;
  end
endmodule
