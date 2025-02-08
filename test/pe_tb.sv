//TB for PE
`timescale 1ns/1ps

`define DATA_WIDTH 8  // Define bit-width for input A and B
`define ACC_WIDTH 16  // Define bit-width for accumulation (C)

// Interface
interface pe_if(input bit clk);
    logic [`DATA_WIDTH-1:0] a_in;
    logic [`DATA_WIDTH-1:0] b_in;
    logic we;
    logic [`DATA_WIDTH-1:0] a_out;
    logic [`DATA_WIDTH-1:0] b_out;
    logic [`ACC_WIDTH-1:0] c_out;
endinterface

// Transaction Class
class transaction;
    rand bit [`DATA_WIDTH-1:0] a_in;
    rand bit [`DATA_WIDTH-1:0] b_in;
    bit we;
    
    bit [`ACC_WIDTH-1:0] c_out;

    constraint c_a_in { a_in inside {[0:255]}; }
    constraint c_b_in { b_in inside {[0:255]}; }

    function void display(input string prefix);
        $display("%s: a_in=%0d, b_in=%0d, we=%0b", prefix, a_in, b_in, we);
    endfunction
endclass


//Generator Class

class generator;
    transaction trans;
    mailbox gen2drv;
    virtual pe_if vif;
    
    function new(mailbox gen2drv);
        this.gen2drv = gen2drv;
    endfunction
    
    task run;
        repeat (100) begin
            trans = new();
            assert(trans.randomize());
            trans.we = 1;
            gen2drv.put(trans);
        end
    endtask
    
    
    task corner_case_test;
        // Corner case 1: Minimum values
        trans = new();
        trans.a_in = 0;
        trans.b_in = 0;
        trans.we = 1;
        gen2drv.put(trans);
        @(posedge vif.clk); // Wait for one clock cycle
        
        // Corner case 2: Maximum values
        trans = new();
        trans.a_in = 255;
        trans.b_in = 255;
        trans.we = 1;
        gen2drv.put(trans);
        @(posedge vif.clk); // Wait for one clock cycle
        
        // Corner case 3: Mixed values (a_in = 0, b_in = 255)
        trans = new();
        trans.a_in = 0;
        trans.b_in = 255;
        trans.we = 1;
        gen2drv.put(trans);
        @(posedge vif.clk); // Wait for one clock cycle
        
        // Corner case 4: Mixed values (a_in = 255, b_in = 0)
        trans = new();
        trans.a_in = 255;
        trans.b_in = 0;
        trans.we = 1;
        gen2drv.put(trans);
        @(posedge vif.clk); // Wait for one clock cycle
    endtask
    
endclass


//Driver Class
class driver;
    virtual pe_if vif;
    mailbox gen2drv;
    
    function new(virtual pe_if vif, mailbox gen2drv);
        this.vif = vif;
        this.gen2drv = gen2drv;
    endfunction
    
    task run;
        forever begin
            transaction trans;
            gen2drv.get(trans);
            vif.a_in <= trans.a_in;
            vif.b_in <= trans.b_in;
            vif.we <= trans.we;
            @(posedge vif.clk);
        end
     endtask
endclass



//Monitor Class
class monitor;
    virtual pe_if vif;
    mailbox mon2sbx;
    
    function new(virtual pe_if vif, mailbox mon2sbx);
        this.vif = vif;
        this.mon2sbx = mon2sbx;
    endfunction
    
    task run;
        forever begin
            @(posedge vif.clk);
            if(vif.we) begin
                transaction trans = new();
                trans.a_in = vif.a_in;
                trans.b_in = vif.b_in;
                trans.c_out = vif.c_out;
                trans.we = vif.we;
                
                mon2sbx.put(trans);
           
            end
         
        end
    endtask
endclass     


class scoreboard;
    mailbox mon2sbx;
    bit[`ACC_WIDTH-1:0] expected_c;
    integer counter = 0;
    
    function new(mailbox mon2sbx);
        this.mon2sbx = mon2sbx;
        expected_c   = 0;
   endfunction
   
    task run;
        forever begin
        transaction trans;
        mon2sbx.get(trans);
        expected_c = expected_c + trans.a_in * trans.b_in;
        $display("input: a_in: %0d, b_in: %0d", trans.a_in, trans.b_in);
        if (trans.c_out !== expected_c) begin
            $display("Error: Expected c_out = %0d, Actual c_out = %0d", expected_c, trans.c_out);
            counter ++;
        end else begin
            $display("Output Match: Expected c_out = %0d, Actual c_out = %0d", expected_c, trans.c_out);
        end
    end
    endtask
endclass

//Enviroment
class enviroment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sbx;
    mailbox gen2drv, mon2sbx;
    virtual pe_if vif;
    
    function new(virtual pe_if vif);
        this.vif = vif;
        gen2drv = new();
        mon2sbx = new();
        gen = new(gen2drv);
        drv = new(this.vif, gen2drv);
        mon = new(this.vif, mon2sbx);
        sbx = new(mon2sbx);
    endfunction
    
    task run;
        fork
            gen.run();
            drv.run();
            mon.run();
            sbx.run();
        join
    
   endtask
endclass



class test;
    enviroment env;
    virtual pe_if vif;
    
    function new(virtual pe_if vif);
        this.vif = vif;
        env = new(this.vif);
    endfunction
    
    task run;
        env.run();
    endtask
endclass

module tb_top;
    bit clk;
    bit rst_n;
    
    pe_if vif(clk);
    
    pe dut(
        .clk(clk),
        .rst_n(rst_n),
        .we(vif.we),
        .a_in(vif.a_in),
        .b_in(vif.b_in),
        .a_out(vif.a_out),
        .b_out(vif.b_out),
        .c_out(vif.c_out)
        );
       
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        rst_n = 0;
        repeat(10) begin
            #10 rst_n = 0;
            #10 rst_n = 1;
        end
        #10;
        rst_n = 1;
    end
    
    initial begin
        test t = new(vif);
        #500;
        t.run();
        #500;
        $finish;
    end
endmodule
    
    



