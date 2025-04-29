// =============================================================
//  control_tb.sv   -   directed testbench for Mini-TPU control
// =============================================================
`timescale 1ns/1ps
`ifndef DATA_WIDTH
  `define DATA_WIDTH 8
`endif

module control_tb;

  // -----------------------------------------------------------
  // ❶ DUT connections
  // -----------------------------------------------------------
  logic        clk;
  logic        rst_n;
  logic [15:0] instruction;

  wire        array_write_enable;
  wire [1:0]  array_output_row;
  wire [1:0]  array_output_col;
  wire [`DATA_WIDTH-1:0] mema_data_in,  memb_data_in;
  wire                 mema_write_enable,  memb_write_enable;
  wire [1:0]           mema_write_line,    mema_write_elem;
  wire [1:0]           memb_write_line,    memb_write_elem;
  wire [3:0]           mema_read_enable,   memb_read_enable;
  wire [7:0]           mema_read_elem,     memb_read_elem;

  control dut (.*);

  // -----------------------------------------------------------
  // ❷ clock / reset
  // -----------------------------------------------------------
  initial clk = 0;
  always  #5 clk = ~clk;                 // 100 MHz

  initial begin
    rst_n = 0;
    instruction = 16'hC000;              // idle STORE opcode (11) so counter can run
    repeat (3) @(posedge clk);
    rst_n = 1;
  end

  // -----------------------------------------------------------
  // ❸ helper tasks
  // -----------------------------------------------------------
  localparam OPC_START = 2'b00,
             OPC_STOP  = 2'b01,
             OPC_LOAD  = 2'b10,
             OPC_STORE = 2'b11;

  // one-cycle instruction pulse, then back to idle (11xxxxxxxxxxxxxxxx)
  task automatic pulse_instr (input [15:0] inst);
    @(negedge clk);
       instruction = inst;
    @(posedge clk);
       instruction = 16'hC000;           // idle STORE (opcode 11, row/col 0)
  endtask

  task automatic send_load
     (input bit mem_sel, input [1:0] row, col, input byte data);
    pulse_instr({OPC_LOAD,mem_sel,row,col,data});
  endtask

  task automatic send_store (input [1:0] row,col);
    pulse_instr({OPC_STORE,1'b0,row,col,8'h00});
  endtask

  task automatic send_start ();
    pulse_instr({OPC_START,13'd0});
  endtask

  // -----------------------------------------------------------
  // ❹ scoreboard helpers
  // -----------------------------------------------------------
  function automatic [3:0] exp_read_enable (input int cnt);
    // bit-i = (cnt > i) && (cnt < i+5)
    exp_read_enable = {
       (cnt>3) && (cnt<8),
       (cnt>2) && (cnt<7),
       (cnt>1) && (cnt<6),
       (cnt>0) && (cnt<5)
    };
  endfunction

  function automatic [7:0] exp_read_elem (input int cnt);
    // packs the four 2-bit selectors for columns 3→0
    byte elems;
    for (int i=0;i<4;i++) begin
      case (cnt)
        i+1 : elems[i*2 +: 2] = 2'b00;
        i+2 : elems[i*2 +: 2] = 2'b01;
        i+3 : elems[i*2 +: 2] = 2'b10;
        i+4 : elems[i*2 +: 2] = 2'b11;
        default: elems[i*2 +: 2] = 2'b00;
      endcase
    end
    return elems;
  endfunction

  // -----------------------------------------------------------
  // ❺ directed test sequence
  // -----------------------------------------------------------
  initial begin : main
    int errors = 0;
    int local_cnt = 0;

    //----------------------------------------------------------
    // RESET - everything must be 0
    //----------------------------------------------------------
    @(negedge rst_n); @(posedge rst_n);   // wait for release
    assert(array_write_enable==0 && mema_write_enable==0 &&
           memb_write_enable==0 && mema_read_enable==0 &&
           memb_read_enable==0) else $fatal("RESET failed");

    //----------------------------------------------------------
    // LOAD to mem-A  (row=2,col=1,data=0xAB)
    //----------------------------------------------------------
    send_load(1'b0,2,1,8'hAB);
    #1;
    assert(mema_write_enable==1  && mema_data_in==8'hAB &&
           mema_write_line==2    && mema_write_elem==1 &&
           memb_write_enable==0)
        else $fatal("LOAD-A signal mismatch");

    //----------------------------------------------------------
    // LOAD to mem-B  (row=1,col=3,data=0xCD)
    //----------------------------------------------------------
    send_load(1'b1,1,3,8'hCD);
    #1;
    assert(memb_write_enable==1  && memb_data_in==8'hCD &&
           memb_write_line==1    && memb_write_elem==3 &&
           mema_write_enable==0)
        else $fatal("LOAD-B signal mismatch");

    //----------------------------------------------------------
    // START  ➜ 10-cycle read pattern + auto-stop
    //----------------------------------------------------------
    send_start();                // semicolon, not colon
    
      fork
        forever begin
          @(negedge clk);
          if (array_write_enable) begin
            // checker body
            assert(mema_read_enable === exp_read_enable(local_cnt))
              else $fatal("read_enable mismatch at cnt=%0d",local_cnt);
            assert(mema_read_elem   === exp_read_elem(local_cnt))
              else $fatal("read_elem   mismatch at cnt=%0d",local_cnt);
            local_cnt++;
          end
        end
      join_none
    
      wait (!array_write_enable);
      assert(local_cnt==10)
        else $fatal("counter ran %0d cycles, expected 10", local_cnt);
    
      // STORE test …
      $display("\n*** CONTROL-UNIT TESTS PASSED ***\n");
      $finish;
    end

endmodule
