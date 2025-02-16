`default_nettype none
`timescale 1ns/1ns

module control_unit (
    input  wire clk,
    input  wire rst_n,
    input  wire start,             // External start signal to begin the operation
    input  wire computation_done,  // Signal from the systolic array indicating computation is complete
    input  wire store_done,        // Signal from the output SRAM that storing is complete
    output reg  load_weight,       // Control signal to load weights into the weight buffer
    output reg  load_activation,   // Control signal to load activations into the activation buffer
    output reg  compute_en,        // Control signal to enable the systolic array for computation
    output reg  store_en,          // Control signal to trigger storing of results to the output SRAM
    output reg  done               // Overall done signal (indicating the complete operation is finished)
);

    // Define FSM state encoding using local parameters.
    localparam IDLE             = 3'b000,
               LOAD_WEIGHT      = 3'b001,
               LOAD_ACTIVATION  = 3'b010,
               COMPUTE          = 3'b011,
               STORE            = 3'b100,
               FINISH           = 3'b101;

    reg [2:0] state, next_state;

    // State transition: Update state at every clock edge.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next state logic and output assignments.
    always @(*) begin
        // Default: deassert all control signals.
        next_state = state;
        load_weight = 1'b0;
        load_activation = 1'b0;
        compute_en = 1'b0;
        store_en = 1'b0;
        done = 1'b0;

        case (state)
            IDLE: begin
                // Wait for the external start signal.
                if (start)
                    next_state = LOAD_WEIGHT;
            end

            LOAD_WEIGHT: begin
                // Assert weight loading.
                load_weight = 1'b1;
                // Transition to loading activations (could be delayed by an external "buffer full" signal).
                next_state = LOAD_ACTIVATION;
            end

            LOAD_ACTIVATION: begin
                // Assert activation loading.
                load_activation = 1'b1;
                // Move to computation phase after activations are loaded.
                next_state = COMPUTE;
            end

            COMPUTE: begin
                // Enable the systolic array for computation.
                compute_en = 1'b1;
                // Wait for computation to complete.
                if (computation_done)
                    next_state = STORE;
            end

            STORE: begin
                // Trigger the storing of results to the output SRAM.
                store_en = 1'b1;
                // Wait until storing is complete.
                if (store_done)
                    next_state = FINISH;
            end

            FINISH: begin
                // Signal that the entire operation is complete.
                done = 1'b1;
                // Return to IDLE (or you might hold in FINISH if continuous operation is desired).
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
