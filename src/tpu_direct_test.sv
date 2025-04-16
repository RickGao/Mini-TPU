//====================================================================
//  ❶  Golden reference: unsigned 8-bit mat-mul with 8-bit accumulator
//====================================================================
function automatic void golden_ref   // pass matrices by ref
   (input  byte A [4][4],
    input  byte B [4][4],
    output byte C [4][4]);
  for (int i=0;i<4;i++)
    for (int j=0;j<4;j++) begin
      int unsigned sum = 0;
      for (int k=0;k<4;k++)
        sum += A[i][k] * B[k][j];
      C[i][j] = sum[7:0];    // truncate to ACC_WIDTH
    end
endfunction

//====================================================================
//  ❷  Compare DUT matrix with reference; return #errors
//====================================================================
function automatic int compare_C
   (input byte C_dut [4][4],
    input byte C_ref [4][4]);
  int err = 0;
  for (int r=0;r<4;r++)
    for (int c=0;c<4;c++)
      if (C_dut[r][c] !== C_ref[r][c]) begin
        $error("Mismatch (%0d,%0d) exp=%0d got=%0d",
               r,c,C_ref[r][c],C_dut[r][c]);
        err++;
      end
  return err;
endfunction

//====================================================================
//  ❸  Core procedure that loads A & B, STARTs, reads C
//====================================================================
task automatic run_once
   (input byte A_in [4][4],
    input byte B_in [4][4],
    output byte C_out[4][4]);
  // ❸-a LOAD
  for (int r=0;r<4;r++)
    for (int c=0;c<4;c++) begin
      load_word(1'b0,r,c,A_in[r][c]);  // memory-A
      load_word(1'b1,r,c,B_in[r][c]);  // memory-B
    end
  // ❸-b START
  send_instr(2'b00,1'b0,2'b00,2'b00,8'h00);
  repeat (12) @(posedge clk);          // wait >10 cycles
  // ❸-c STORE every element
  for (int r=0;r<4;r++)
    for (int c=0;c<4;c++) begin
      store_word(r,c);
      @(posedge clk);
      C_out[r][c] = result;
    end
endtask

//====================================================================
//  ❹  TEST-1  A × I  and  I × B
//====================================================================
task automatic test_id_mul (ref int err_acc);
  byte A[4][4],B[4][4],C_ref[4][4],C_dut[4][4];

  // A = increasing pattern, B = identity
  foreach(A[i,j]) A[i][j]=i*4+j;
  foreach(B[i,j]) B[i][j]=(i==j);
  golden_ref(A,B,C_ref);
  run_once(A,B,C_dut);
  err_acc += compare_C(C_dut,C_ref);

  // Now A = identity, B = previous A
  foreach(A[i,j]) A[i][j]=(i==j);
  foreach(B[i,j]) B[i][j]=i*4+j;
  golden_ref(A,B,C_ref);
  run_once(A,B,C_dut);
  err_acc += compare_C(C_dut,C_ref);
endtask

//====================================================================
//  ❺  TEST-2  20 random matrices
//====================================================================
task automatic test_random (ref int err_acc);
  byte A[4][4],B[4][4],C_ref[4][4],C_dut[4][4];
  for (int t=0;t<20;t++) begin
    foreach(A[i,j]) A[i][j]=$urandom_range(0,255);
    foreach(B[i,j]) B[i][j]=$urandom_range(0,255);
    golden_ref(A,B,C_ref);
    run_once(A,B,C_dut);
    err_acc += compare_C(C_dut,C_ref);
  end
endtask

//====================================================================
//  ❻  TEST-3  Overflow check (0xFF * 0xFF * 4)
//====================================================================
task automatic test_overflow (ref int err_acc);
  byte A[4][4],B[4][4],C_ref[4][4],C_dut[4][4];
  foreach(A[i,j]) A[i][j]=8'hFF;
  foreach(B[i,j]) B[i][j]=8'hFF;
  golden_ref(A,B,C_ref);
  run_once(A,B,C_dut);
  err_acc += compare_C(C_dut,C_ref);
endtask

//====================================================================
//  ❼  TEST-4  Re-start without re-loading memories
//====================================================================
task automatic test_reuse_memory (ref int err_acc);
  byte A[4][4],B[4][4],C_ref[4][4],C_dut[4][4];

  // first load random
  foreach(A[i,j]) A[i][j]=$urandom_range(0,255);
  foreach(B[i,j]) B[i][j]=$urandom_range(0,255);
  golden_ref(A,B,C_ref);
  run_once(A,B,C_dut);
  err_acc += compare_C(C_dut,C_ref);

  // do NOT reload, just issue another START
  send_instr(2'b00,1'b0,2'b00,2'b00,8'h00);
  repeat (12) @(posedge clk);
  for (int r=0;r<4;r++)
    for (int c=0;c<4;c++) begin
      store_word(r,c); @(posedge clk);
      C_dut[r][c]=result;
    end
  err_acc += compare_C(C_dut,C_ref);
endtask

//====================================================================
//  ❽  Kick everything off from your existing main initial block
//====================================================================
initial begin : main
  int errors = 0;

  @(negedge rst_n); @(posedge rst_n);  // wait for reset release

  test_id_mul     (errors);
  test_random     (errors);
  test_overflow   (errors);
  test_reuse_memory(errors);

  if (errors==0) $display("\n*** TPU-TOP TESTS PASSED ***\n");
  else            $display("\n*** TPU-TOP TESTS FAILED : %0d errors ***\n",errors);

  $finish;
end
