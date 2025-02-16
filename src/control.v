`default_nettype none
`timescale 1ns/1ns

module control_unit (
    input  wire clk,
    input  wire rst_n,
    input  wire start,             // External start signal to begin the operation
    input  wire computation_done,  // From the systolic array or a counter
    input  wire store_done,        // From output SRAM storing logic
    output reg  load_weight,       // Load weights into the weight buffer
    output reg  load_activation,   // Load activations into the activation buffer
    output reg  compute_en,        // Enable the systolic array
    output reg  store_en,          // Trigger storing results to output SRAM
    output reg  done               // Entire operation is finished
);

    // Define FSM state encoding
    localparam IDLE             = 3'b000,
               LOAD_WEIGHT      = 3'b001,
               LOAD_ACTIVATION  = 3'b010,
               COMPUTE          = 3'b011,
               STORE            = 3'b100,
               FINISH           = 3'b101;

    reg [2:0] state, next_state;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next-state logic & control outputs
    always @(*) begin
        // Default: deassert all
        next_state       = state;
        load_weight      = 1'b0;
        load_activation  = 1'b0;
        compute_en       = 1'b0;
        store_en         = 1'b0;
        done             = 1'b0;

        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD_WEIGHT;
            end

            LOAD_WEIGHT: begin
                load_weight = 1'b1;
                // Immediately proceed (or wait for some “done loading weights” if desired)
                next_state = LOAD_ACTIVATION;
            end

            LOAD_ACTIVATION: begin
                load_activation = 1'b1;
                // Immediately proceed (or wait for “done loading activations”)
                next_state = COMPUTE;
            end

            COMPUTE: begin
                compute_en = 1'b1;
                if (computation_done)
                    next_state = STORE;
            end

            STORE: begin
                store_en = 1'b1;
                if (store_done)
                    next_state = FINISH;
            end

            FINISH: begin
                done       = 1'b1;
                // After finishing, go back to IDLE (or stay in FINISH)
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
