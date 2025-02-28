// Control Unit of Mini TPU
`define DATA_WIDTH 8  // Define macro for register width


module control (
    input wire clk,
    input wire rst_n,
    input wire [15:0] instruction,

    output wire array_write_enable,
    output wire [1:0] array_output_row,
    output wire [1:0] array_output_column,
    
    output wire [`DATA_WIDTH-1:0] mema_data_in,
    output wire mema_write_enable,
    output wire [1:0] mema_write_line,
    output wire [1:0] mema_write_elem,

    output wire [`DATA_WIDTH-1:0] memb_data_in,
    output wire memb_write_enable,
    output wire [1:0] memb_write_line,
    output wire [1:0] memb_write_elem,

    output wire [3:0] mema_read_enable,
    output wire [1:0] mema_read_elem [3:0],

    output wire [3:0] memb_read_enable,
    output wire [1:0] memb_read_elem [3:0]
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
    
    // Memory selection and addressing are now handled directly in the instruction decoding section
    
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
    end

    // // Instruction execution
    // always @(posedge clk) begin
        
    // end

    // Memory A 读取使能信号
    assign mema_read_enable[0] = (counter >= 4'd1 && counter <= 4'd4);
    assign mema_read_enable[1] = (counter >= 4'd2 && counter <= 4'd6);
    assign mema_read_enable[2] = (counter >= 4'd3 && counter <= 4'd6);
    assign mema_read_enable[3] = (counter >= 4'd4 && counter <= 4'd7);

    // Memory B 读取使能信号（假设与Memory A相同的访问模式）
    assign memb_read_enable[0] = mema_read_enable[0];
    assign memb_read_enable[1] = mema_read_enable[1];
    assign memb_read_enable[2] = mema_read_enable[2];
    assign memb_read_enable[3] = mema_read_enable[3];

    // Memory A 元素索引控制
    // 第一行元素索引
    assign mema_read_elem[0][1:0] = (counter == 4'd1) ? 2'b00 :
                                (counter == 4'd2) ? 2'b01 :
                                (counter == 4'd3) ? 2'b10 :
                                (counter == 4'd4) ? 2'b11 : 2'b00;

    // 第二行元素索引
    assign mema_read_elem[1][1:0] = (counter == 4'd2) ? 2'b00 :
                                (counter == 4'd3) ? 2'b01 :
                                (counter == 4'd4) ? 2'b10 :
                                (counter == 4'd5) ? 2'b11 : 2'b00;

    // 第三行元素索引
    assign mema_read_elem[2][1:0] = (counter == 4'd3) ? 2'b00 :
                                (counter == 4'd4) ? 2'b01 :
                                (counter == 4'd5) ? 2'b10 :
                                (counter == 4'd6) ? 2'b11 : 2'b00;

    // 第四行元素索引
    assign mema_read_elem[3][1:0] = (counter == 4'd4) ? 2'b00 :
                                (counter == 4'd5) ? 2'b01 :
                                (counter == 4'd6) ? 2'b10 :
                                (counter == 4'd7) ? 2'b11 : 2'b00;

    // Memory B 元素索引控制（假设与Memory A相同的访问模式）
    assign memb_read_elem[0][1:0] = mema_read_elem[0][1:0];
    assign memb_read_elem[1][1:0] = mema_read_elem[1][1:0];
    assign memb_read_elem[2][1:0] = mema_read_elem[2][1:0];
    assign memb_read_elem[3][1:0] = mema_read_elem[3][1:0];

    case (opcode)
            LOAD: begin
                if (mem_select == 0) begin
                    // Load to Memory A
                    assign mema_data_in = immediate;
                    assign mema_write_enable = 1;
                    assign mema_write_line = row;
                    assign mema_write_elem = col;
                end else begin
                    // Load to Memory B
                    assign memb_data_in = immediate;
                    assign memb_write_enable = 1;
                    assign memb_write_line = row;
                    assign memb_write_elem = col;
                end
            end
            
            STORE: begin
                // Read from systolic array at row/column
                array_write_enable <= 0; // Not writing to array
                array_output_row <= row;    // Row from instruction
                array_output_column <= col;    // Column from instruction
            end
            
            START: begin
                status <= 1; // Start the counter
                
                // Initialize memory read enables for matrix multiplication
                mema_read_enable <= 4'b1111; // Enable all rows
                memb_read_enable <= 4'b1111; // Enable all columns
                
                // Configure which elements to read from memories
                // For matrix multiplication, each processing element needs
                // an element from its corresponding row/column
                for (integer i = 0; i < 4; i = i + 1) begin
                    mema_read_elem[i] <= i[1:0]; // Row element index
                    memb_read_elem[i] <= i[1:0]; // Column element index
                end
            end
            
            STOP: begin
                status <= 0; // Stop the counter
                
                // Disable memory reads when stopped
                mema_read_enable <= 4'b0000;
                memb_read_enable <= 4'b0000;
            end
            
            default: begin
                // No operation
            end
        endcase
endmodule