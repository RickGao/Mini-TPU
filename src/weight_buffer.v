`default_nettype none
`timescale 1ns/1ns

module weight_buffer (
    input  wire        clk,
    input  wire        rst_n,
    // Data input interface from external system
    input  wire [7:0]  data_in,
    input  wire        in_valid,    // Indicates that data_in is valid for writing
    output wire        in_ready,    // Indicates that the active write FIFO is not full
    // Swap signal: when asserted, the roles of the two FIFOs are swapped.
    // This should be controlled by your external controller after a complete weight block is loaded.
    input  wire        swap,
    // Data output interface to feed the systolic array's weight inputs
    input  wire        read_en,     // Read enable signal from downstream logic
    output wire [7:0]  data_out,
    output wire        buffer_empty // Indicates the read FIFO is empty
);

  // "active" flag selects which FIFO is currently used for writing:
  // When active == 0, FIFO0 is used for writing and FIFO1 for reading.
  // When active == 1, FIFO1 is used for writing and FIFO0 for reading.
  reg active;
  always @(posedge clk or negedge rst_n) begin
      if (!rst_n)
         active <= 1'b0;
      else if (swap)
         active <= ~active;
  end
  
  // Instantiate two FIFO modules (adjust DEPTH as needed)
  
  // FIFO0 instance
  wire fifo0_empty, fifo0_full;
  wire [7:0] fifo0_data_out;
  
  simple_fifo #(.DATA_WIDTH(8), .DEPTH(16)) fifo0 (
      .clk(clk),
      .reset(rst_n),
      // Write when FIFO0 is active for writing (active == 0)
      .wr_en(in_valid && (active == 1'b0)),
      .data_in(data_in),
      // Read when FIFO0 is active for reading (active == 1)
      .rd_en(read_en && (active == 1'b1)),
      .data_out(fifo0_data_out),
      .empty(fifo0_empty),
      .full(fifo0_full)
  );
  
  // FIFO1 instance
  wire fifo1_empty, fifo1_full;
  wire [7:0] fifo1_data_out;
  
  simple_fifo #(.DATA_WIDTH(8), .DEPTH(16)) fifo1 (
      .clk(clk),
      .reset(rst_n),
      // Write when FIFO1 is active for writing (active == 1)
      .wr_en(in_valid && (active == 1'b1)),
      .data_in(data_in),
      // Read when FIFO1 is active for reading (active == 0)
      .rd_en(read_en && (active == 1'b0)),
      .data_out(fifo1_data_out),
      .empty(fifo1_empty),
      .full(fifo1_full)
  );
  
  // The in_ready signal is asserted when the FIFO currently used for writing is not full.
  assign in_ready = (active == 1'b0) ? ~fifo0_full : ~fifo1_full;
  
  // The data_out is taken from the FIFO currently designated for reading.
  assign data_out = (active == 1'b0) ? fifo1_data_out : fifo0_data_out;
  
  // The buffer_empty signal reflects whether the read FIFO is empty.
  assign buffer_empty = (active == 1'b0) ? fifo1_empty : fifo0_empty;
  
endmodule
