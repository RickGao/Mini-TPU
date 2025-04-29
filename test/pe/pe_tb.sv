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
        repeat (10000) begin
            trans = new();
            assert(trans.randomize());
            trans.we = 1;
            gen2drv.put(trans);
        end
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
                trans.we = vif.we;
                trans.c_out = vif.c_out;
                mon2sbx.put(trans);
           
            end
         
        end
    endtask
endclass     

//scoreboard class
class scoreboard;
    mailbox mon2sbx;
    bit[`ACC_WIDTH-1:0] next_expected_c;
    bit [`DATA_WIDTH-1:0] queue2[$];  // Declare as a queue for input
    int passed_count;
    int failed_count;


    int transaction_count;
    
    function new(mailbox mon2sbx);
        this.mon2sbx = mon2sbx;
        next_expected_c   = 0;
        queue2 = {0, 0, 0, 0};  // Initialize queue with four zeros in the constructor
        passed_count = 0;
        failed_count = 0;

    endfunction
   
    task run;
        forever begin
            transaction trans;
            
            bit [`DATA_WIDTH-1:0] input_a;
            bit [`DATA_WIDTH-1:0] input_b;

            mon2sbx.get(trans);
            
            queue2.push_back(trans.a_in);
            queue2.push_back(trans.b_in);
            
            input_a = queue2.pop_front();
            input_b = queue2.pop_front();
            
            if (transaction_count > 0) begin
                $display("Delayed Input at time %0t: a_in = %0d, b_in = %0d", $time, input_a, input_b);

                if (trans.c_out !== next_expected_c) begin
                    failed_count++;
    
                    $display("ERROR at time %0t: expected_c=%0d, got c_out=%0d",
                             $time, next_expected_c, trans.c_out);
                end
                else begin
                    passed_count++;
                    $display("MATCH at time %0t: expected_c=%0d, got c_out=%0d",
                             $time, next_expected_c, trans.c_out);
                    /**         
                    $display("\n--- Test Report ---");
                    $display("Passed: %0d", passed_count);
                    $display("Failed: %0d", failed_count);
                    $display("-------------------");
                    **/
                end
                end
            next_expected_c = next_expected_c + trans.a_in * trans.b_in;
            transaction_count++;

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
    test t;
    
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
        t = new(vif);
        #500;
        t.run();
        #500;
        $finish;
    end
endmodule
    
    



