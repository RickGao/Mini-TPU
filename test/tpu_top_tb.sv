`timescale 1ns / 1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

// TPU Interface

interface tpu_if (input bit clk, input bit rst_n);
  logic [15:0] instruction;
  logic [7:0]  result;
  
  // Optional clocking blocks if needed
  clocking drv_cb @(posedge clk);
    output instruction;
  endclocking

  clocking mon_cb @(posedge clk);
    input result;
  endclocking

endinterface : tpu_if

//Transaction
class tpu_transaction extends uvm_sequence_item;

  // The key fields needed for the DUT
  rand logic [15:0] instruction;
  // For scoreboard checking if we want to validate output
  logic [7:0]  expected_result;
  // We can store an indicator if we expect a result on this instruction
  logic        check_result;

  // Constructor
  function new(string name="tpu_transaction");
    super.new(name);
  endfunction


endclass : tpu_transaction



//============================================================
// 3) Example Sequence
//============================================================
class tpu_sequence extends uvm_sequence #(tpu_transaction);

  `uvm_object_utils(tpu_sequence)

  function new(string name="tpu_sequence");
    super.new(name);
  endfunction

  // We'll generate a small set of instructions to demonstrate usage:
  //   1) LOAD instructions to fill memory A or B
  //   2) START instruction
  //   3) Wait a bit, then STORE instruction to read result
  task body();
    tpu_transaction tr;

    // Example: LOAD imm=8'h12 into memory A at row=01 col=02
    tr = tpu_transaction::type_id::create("load_A");
    tr.instruction = {2'b10, 1'b0, 2'b01, 2'b10, 8'h12}; 
      // opcode=2'b10 => LOAD
      // mem_select=0 => mem A
      // row=01 col=10 => row=1 col=2
      // imm=8'h12
    tr.check_result   = 0;
    start_item(tr);
    finish_item(tr);
    #(10);

    // Example: LOAD imm=8'h34 into memory B at row=1 col=3
    tr = tpu_transaction::type_id::create("load_B");
    tr.instruction = {2'b10, 1'b1, 2'b01, 2'b11, 8'h34}; 
      // opcode=2'b10 => LOAD
      // mem_select=1 => mem B
    tr.check_result   = 0;
    start_item(tr);
    finish_item(tr);
    #(10);

    // START instruction (opcode=00)
    tr = tpu_transaction::type_id::create("start");
    tr.instruction = {2'b00, 13'h0};  
    tr.check_result = 0;
    start_item(tr);
    finish_item(tr);
    #(10);

    // Wait enough cycles for the array to do some accumulations
    // The control logic auto-stops after ~10 cycles.
    repeat (15) @(posedge p_sequencer.get_sequencer().m_parent_driver.vif.clk);

    // STORE instruction (opcode=11), row=1, col=2 => read result from (1,2)
    tr = tpu_transaction::type_id::create("store");
    tr.instruction      = {2'b11, 1'b0, 2'b01, 2'b10, 8'h00}; 
      // opcode=2'b11 => STORE
      // row=1 col=2
    tr.expected_result  = 8'h??; // Put your predicted result here
    tr.check_result     = 1;
    start_item(tr);
    finish_item(tr);
    #(10);
  endtask

endclass : tpu_sequence

//============================================================
// 4) TPU Driver
//============================================================
class tpu_driver extends uvm_driver #(tpu_transaction);

  `uvm_component_utils(tpu_driver)

  // Virtual interface
  virtual tpu_if vif;

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // build_phase: fetch interface
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual tpu_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRIVER", "Failed to get tpu_if from config DB");
  endfunction

  // run_phase: drive instructions to DUT
  task run_phase(uvm_phase phase);
    tpu_transaction tr;
    forever begin
      seq_item_port.get_next_item(tr);
      // Drive instruction on next posedge
      @(posedge vif.clk);
      vif.drv_cb.instruction <= tr.instruction;

      seq_item_port.item_done(); 
    end
  endtask

endclass : tpu_driver


//============================================================
// 5) TPU Monitor
//============================================================
class tpu_monitor extends uvm_monitor;

  `uvm_component_utils(tpu_monitor)

  // Analysis port to broadcast observed "results" 
  uvm_analysis_port #(tpu_transaction) ap;

  // Virtual interface
  virtual tpu_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  // build_phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual tpu_if)::get(this, "", "vif", vif))
      `uvm_fatal("MONITOR", "Failed to get tpu_if from config DB");
  endfunction

  tpu_transaction t;


  // We'll monitor the output `result`. In a simple design, there's no handshake,
  // so we might sample `result` every cycle. We'll create a transaction if needed.
  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk);
  
      // Declare a local variable named 't'
  
      t.expected_result = 0;       
      t.instruction     = {8'h00, vif.mon_cb.result};
      t.check_result    = 0;       
  
      // Publish the observed transaction
      ap.write(t);
    end
  endtask


endclass : tpu_monitor

//============================================================
// 6) TPU Scoreboard
//============================================================
class tpu_scoreboard extends uvm_component;

  `uvm_component_utils(tpu_scoreboard)

  // Analysis imp
  uvm_analysis_imp #(tpu_transaction, tpu_scoreboard) analysis_export;
  // We'll store the last observed result in a local variable
  logic [7:0] last_observed_result;

  // For referencing instructions that requested a STORE
  // We'll keep a small queue of transactions that want to check the result
  tpu_transaction store_txn;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  // Called whenever the monitor writes a transaction
  function void write(tpu_transaction t);
    // In this example, the monitor sets t.instruction[7:0] = observed result
    last_observed_result = t.instruction[7:0];
    // If we have a pending store transaction, we can compare now
    if (store_txn != null) begin
      compare_result(store_txn, last_observed_result);
      store_txn = null;
    end
  endfunction

  // We'll create a small method to compare scoreboard results
  function void compare_result(tpu_transaction store_item, logic [7:0] actual);
    if (actual !== store_item.expected_result) begin
      `uvm_error("SCOREBOARD", $sformatf("STORE mismatch. Got 0x%0h, expected 0x%0h",
                                         actual, store_item.expected_result))
    end else begin
      `uvm_info("SCOREBOARD", $sformatf("STORE match: 0x%0h", actual), UVM_LOW)
    end
  endfunction

  // We'll create a task to let the scoreboard know when a STORE instruction was driven
  // so it can store the transaction for later comparison.
  task store_instruction(tpu_transaction tr);
    store_txn = tr;
  endtask

endclass : tpu_scoreboard

//============================================================
// 7) TPU Agent
//============================================================
class tpu_agent extends uvm_agent;

  `uvm_component_utils(tpu_agent)

  tpu_driver                  m_driver;
  tpu_monitor                 m_monitor;
  uvm_sequencer #(tpu_transaction) m_sequencer;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // build_phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create driver, monitor, sequencer
    m_driver    = tpu_driver   ::type_id::create("m_driver",    this);
    m_monitor   = tpu_monitor  ::type_id::create("m_monitor",   this);
    m_sequencer = uvm_sequencer#(tpu_transaction)::type_id::create("m_sequencer", this);
  endfunction

  // connect_phase
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
  endfunction

endclass : tpu_agent

//============================================================
// 8) TPU Environment
//============================================================
class tpu_env extends uvm_env;

  `uvm_component_utils(tpu_env)

  tpu_agent       m_agent;
  tpu_scoreboard  m_scoreboard;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    m_agent       = tpu_agent      ::type_id::create("m_agent",       this);
    m_scoreboard  = tpu_scoreboard ::type_id::create("m_scoreboard",  this);
  endfunction

  // We'll connect the monitor's analysis port to the scoreboard
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    m_agent.m_monitor.ap.connect(m_scoreboard.analysis_export);
  endfunction

endclass : tpu_env

//============================================================
// 9) TPU Test
//============================================================
class tpu_test extends uvm_test;

  `uvm_component_utils(tpu_test)

  tpu_env m_env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_env = tpu_env::type_id::create("m_env", this);
  endfunction
    tpu_sequence seq;
task run_phase(uvm_phase phase);
    phase.raise_objection(this);
  
    // Corrected sequencer parent reference
    
    seq.start(m_env.m_agent.m_sequencer);
  
    phase.drop_objection(this);
  endtask

endclass : tpu_test

//============================================================
// 10) Top-level Testbench Module
//============================================================
module top_tb;

  bit clk = 0;
  bit rst_n = 0;

  // Generate clock
  always #5 clk = ~clk;

  // Reset
  initial begin
    rst_n = 0;
    #20 rst_n = 1;
  end

  // Instantiate interface
  tpu_if tpu_if_inst(.clk(clk), .rst_n(rst_n));

  //============================================================
  // DUT Instantiation (your Mini TPU)
  //============================================================
  tpu dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .instruction(tpu_if_inst.instruction),
    .result     (tpu_if_inst.result)
  );

  //============================================================
  // UVM Run
  //============================================================
  initial begin
    // Provide virtual interface via config DB
    uvm_config_db#(virtual tpu_if)::set(null, "*", "vif", tpu_if_inst);

    // Run the test
    run_test("tpu_test");
  end

endmodule : top_tb

