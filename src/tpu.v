`default_nettype none
`timescale 1ns/1ns


module tpu (
    input wire clk,
    input wire rst_n,

    input wire [15:0] instruction,
    output wire [7:0] result
);

wire array_write_enable;
wire [`DATA_WIDTH*4-1:0] array_a_in;
wire [`DATA_WIDTH*4-1:0] array_b_in;
wire [`ACC_WIDTH*16-1:0] array_data_out;

array array_inst (
    .clk(clk),
    .rst_n(rst_n),
    .we(array_write_enable),
    .a_in(array_a_in),
    .b_in(array_b_in),
    .data_out(array_data_out)
);

// Control unit
control control_unit (
    .clk(clk),
    .rst_n(rst_n),
    .instruction(instruction),
    
    .array_write_enable(array_write_enable),
    .array_output_row(array_output_row),
    .array_output_col(array_output_col),
    
    .mema_data_in(mema_data_in),
    .mema_write_enable(mema_write_enable),
    .mema_write_line(mema_write_line),
    .mema_write_elem(mema_write_elem),
    
    .memb_data_in(memb_data_in),
    .memb_write_enable(memb_write_enable),
    .memb_write_line(memb_write_line),
    .memb_write_elem(memb_write_elem),
    
    .mema_read_enable(mema_read_enable),
    .mema_read_elem(mema_read_elem),
    
    .memb_read_enable(memb_read_enable),
    .memb_read_elem(memb_read_elem)
);

// Memory A
memory memory_a (
    .clk(clk),
    .rst_n(rst_n),
    .write_enable(mema_write_enable),
    .write_line(mema_write_line),
    .write_elem(mema_write_elem),
    .data_in(mema_data_in),
    .read_enable(mema_read_enable),
    .read_elem(mema_read_elem),
    .data_out(mema_data_out)
);

// Memory B
memory memory_b (
    .clk(clk),
    .rst_n(rst_n),
    .write_enable(memb_write_enable),
    .write_line(memb_write_line),
    .write_elem(memb_write_elem),
    .data_in(memb_data_in),
    .read_enable(memb_read_enable),
    .read_elem(memb_read_elem),
    .data_out(memb_data_out)
);


endmodule
