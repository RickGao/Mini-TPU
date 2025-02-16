`default_nettype none
`timescale 1ns/1ns

module activation_buffer (
    input  wire        clk,
    input  wire        rst_n,       // Active-low reset
    // Data input interface
    input  wire [7:0]  data_in,
    input  wire        in_valid,    // Indicates that data_in is valid
    output wire        in_ready,    // Asserted when the active write FIFO is not full
    // Swap signal: toggles which FIFO is for write vs. read
    input  wire        swap,
    // Data output interface
    input  wire        read_en,     // Read enable
    output wire [7:0]  data_out,
    output wire        buffer_empty // Indicates the read FIFO is empty
);

  //------------------------------------------------
  // active flag: 0 => FIFO0 is write, FIFO1 is read
  //              1 => FIFO1 is write, FIFO0 is read
  //------------------------------------------------
  reg active;
  always @(posedge clk or negedge rst_n) begin
      if (!rst_n)
         active <= 1'b0;
      else if (swap)
         active <= ~active;
  end

  //------------------------------------------------
  // FIFO0 and FIFO1
  //------------------------------------------------
  wire fifo0_empty, fifo0_full;
  wire [7:0] fifo0_data_out;

  simple_fifo #(.DATA_WIDTH(8), .DEPTH(16)) fifo0 (
      .clk    (clk),
      .rst_n  (rst_n),
      // Write side
      .wr_en  (in_valid && (active == 1'b0)),
      .data_in(data_in),
      // Read side
      .rd_en  (read_en && (active == 1'b1)),
      .data_out(fifo0_data_out),
      .empty  (fifo0_empty),
      .full   (fifo0_full)
  );

  wire fifo1_empty, fifo1_full;
  wire [7:0] fifo1_data_out;

  simple_fifo #(.DATA_WIDTH(8), .DEPTH(16)) fifo1 (
      .clk    (clk),
      .rst_n  (rst_n),
      // Write side
      .wr_en  (in_valid && (active == 1'b1)),
      .data_in(data_in),
      // Read side
      .rd_en  (read_en && (active == 1'b0)),
      .data_out(fifo1_data_out),
      .empty  (fifo1_empty),
      .full   (fifo1_full)
  );

  //------------------------------------------------
  // Output logic
  //------------------------------------------------
  assign in_ready = (active == 1'b0) ? ~fifo0_full : ~fifo1_full;
  assign data_out = (active == 1'b0) ? fifo1_data_out : fifo0_data_out;
  assign buffer_empty = (active == 1'b0) ? fifo1_empty : fifo0_empty;

endmodule
