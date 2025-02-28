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
    

    always @(negedge rst_n) begin
        counter <= 0
        status <= 0
    end

    always @(posedge clk) begin
        if (status) begin
            counter <= counter + 1b'1;
        end
    end

    

endmodule
