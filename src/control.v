// Control Unit of Mini TPU
`define DATA_WIDTH 8  // Define macro for register width

module control (
    input wire clk,
    input wire rst_n,
    input wire [15:0] instruction,

    output wire array_write_enable,
    output wire [1:0] array_output_row,
    output wire [1:0] array_output_col,
    
    output wire [`DATA_WIDTH-1:0] mema_data_in,
    output wire mema_write_enable,
    output wire [1:0] mema_write_line,
    output wire [1:0] mema_write_elem,

    output wire [`DATA_WIDTH-1:0] memb_data_in,
    output wire memb_write_enable,
    output wire [1:0] memb_write_line,
    output wire [1:0] memb_write_elem,

    output wire [3:0] mema_read_enable,
    output wire [7:0] mema_read_elem,

    output wire [3:0] memb_read_enable,
    output wire [7:0] memb_read_elem
);

    reg [3:0] counter;
    reg status;
    
    // Instruction decoding
    wire [1:0] opcode = instruction[15:14];
    wire mem_select = instruction[13];      // Memory selection bit for LOAD
    wire [1:0] row = instruction[11:10];    // Row bits
    wire [1:0] col = instruction[9:8];      // Column bits
    wire [7:0] imm = instruction[7:0];      // Immediate data
    
    // Opcode definitions
    localparam LOAD  = 2'b10;
    localparam STORE = 2'b11;
    localparam START = 2'b00;
    localparam STOP  = 2'b01;
    
    // Reset logic
    always @(negedge rst_n) begin
        counter <= 0;
        status <= 0;
    end

    // Counter logic - increments when status is active
    always @(posedge clk) begin
        if (status) begin
            counter <= counter + 1'b1;
        end
        case (opcode)
            START: begin
                status <= 1; // Start the counter
            end
                
            STOP: begin
                status <= 0; // Stop the counter
            end

        endcase
        
    end

    // Generate memory read enable signals
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : read_enable_gen
            // Memory A read enable timing
            assign mema_read_enable[i] = (counter > i && counter < (i+5));
            
            // Memory B read enable (same as Memory A in this design)
            assign memb_read_enable[i] = mema_read_enable[i];
        end
    endgenerate

    // Generate memory read element selectors
    // These are the 2-bit selectors for each memory row/column
    wire [1:0] mem_read_elem_array [3:0];
    
    generate
        for (i = 0; i < 4; i = i + 1) begin : read_elem_gen
            // Memory A read element selection based on counter and row
            assign mem_read_elem_array[i] = 
                (counter == (i+1)) ? 2'b00 :
                (counter == (i+2)) ? 2'b01 :
                (counter == (i+3)) ? 2'b10 :
                (counter == (i+4)) ? 2'b11 : 2'b00;
                
            // Assign to the correct bits in the output bus
            assign mema_read_elem[(i*2)+:2] = mem_read_elem_array[i];
            
            // Memory B uses the same pattern as Memory A
            assign memb_read_elem[(i*2)+:2] = mem_read_elem_array[i];
        end
    endgenerate



    case (opcode)
            LOAD: begin
                if (mem_select == 0) begin
                    // Load to Memory A
                    assign mema_data_in = immediate;
                    assign mema_write_enable = 1'b1;
                    assign mema_write_line = row;
                    assign mema_write_elem = col;
                end else begin
                    // Load to Memory B
                    assign memb_data_in = immediate;
                    assign memb_write_enable = 1;
                    assign memb_write_line = col;
                    assign memb_write_elem = row;
                end
            end
            
            STORE: begin
                // Read from systolic array at row/column
                assign array_output_row = row;    // Row from instruction
                assign array_output_col = col;    // Column from instruction
            end
            
            default: begin
                // No operation
            end
        endcase
endmodule