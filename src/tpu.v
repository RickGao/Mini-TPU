`define DATA_WIDTH 8  // Define bit-width for input A and B
`define ACC_WIDTH 8  // Define bit-width for accumulation C


module tpu (
    input wire clk,
    input wire rst_n,

    input wire [15:0] instruction,
    output wire [7:0] result
);

wire [`DATA_WIDTH-1:0] mema_data_in;
wire mema_write_enable;
wire [1:0] mema_write_line;
wire [1:0] mema_write_elem;
wire [3:0] mema_read_enable;
wire [7:0] mema_read_elem;

wire [`DATA_WIDTH-1:0] memb_data_in;
wire memb_write_enable;
wire [1:0] memb_write_line;
wire [1:0] memb_write_elem;
wire [3:0] memb_read_enable;
wire [7:0] memb_read_elem;

wire array_write_enable;
wire [`DATA_WIDTH*4-1:0] array_a_in;
wire [`DATA_WIDTH*4-1:0] array_b_in;
wire [`ACC_WIDTH*16-1:0] array_data_out;
wire [1:0] array_output_row;
wire [1:0] array_output_col;

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
    .data_out(array_a_in)
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
    .data_out(array_b_in)
);


// wire [3:0] result_index = {array_output_row, array_output_col};
// wire [`ACC_WIDTH-1:0] selected_result = array_data_out[`ACC_WIDTH*(result_index+1)-1:`ACC_WIDTH*result_index];
// assign result = selected_result[7:0];

// wire [3:0] result_index = {array_output_row, array_output_col};

// wire [`ACC_WIDTH-1:0] result_0 = array_data_out[8*1-1:8*0];
// wire [`ACC_WIDTH-1:0] result_1 = array_data_out[8*2-1:8*1];
// wire [`ACC_WIDTH-1:0] result_2 = array_data_out[8*3-1:8*2];
// wire [`ACC_WIDTH-1:0] result_3 = array_data_out[8*4-1:8*3];
// wire [`ACC_WIDTH-1:0] result_4 = array_data_out[8*5-1:8*4];
// wire [`ACC_WIDTH-1:0] result_5 = array_data_out[8*6-1:8*5];
// wire [`ACC_WIDTH-1:0] result_6 = array_data_out[8*7-1:8*6];
// wire [`ACC_WIDTH-1:0] result_7 = array_data_out[8*8-1:8*7];
// wire [`ACC_WIDTH-1:0] result_8 = array_data_out[8*9-1:8*8];
// wire [`ACC_WIDTH-1:0] result_9 = array_data_out[8*10-1:8*9];
// wire [`ACC_WIDTH-1:0] result_10 = array_data_out[8*11-1:8*10];
// wire [`ACC_WIDTH-1:0] result_11 = array_data_out[8*12-1:8*11];
// wire [`ACC_WIDTH-1:0] result_12 = array_data_out[8*13-1:8*12];
// wire [`ACC_WIDTH-1:0] result_13 = array_data_out[8*14-1:8*13];
// wire [`ACC_WIDTH-1:0] result_14 = array_data_out[8*15-1:8*14];
// wire [`ACC_WIDTH-1:0] result_15 = array_data_out[8*16-1:8*15];

// assign result = 
//     (result_index == 4'd0) ? result_0 :
//     (result_index == 4'd1) ? result_1 :
//     (result_index == 4'd2) ? result_2 :
//     (result_index == 4'd3) ? result_3 :
//     (result_index == 4'd4) ? result_4 :
//     (result_index == 4'd5) ? result_5 :
//     (result_index == 4'd6) ? result_6 :
//     (result_index == 4'd7) ? result_7 :
//     (result_index == 4'd8) ? result_8 :
//     (result_index == 4'd9) ? result_9 :
//     (result_index == 4'd10) ? result_10 :
//     (result_index == 4'd11) ? result_11 :
//     (result_index == 4'd12) ? result_12 :
//     (result_index == 4'd13) ? result_13 :
//     (result_index == 4'd14) ? result_14 :
//     result_15;

wire [`ACC_WIDTH-1:0] result_array [0:15];
wire [3:0] result_index = {array_output_row, array_output_col};


genvar i;
generate
    for (i = 0; i < 16; i = i + 1) begin : extract_results
        assign result_array[i] = array_data_out[8*(i+1)-1:8*i];
    end
endgenerate

assign result = result_array[result_index][7:0];


endmodule
