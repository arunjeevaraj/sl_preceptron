`timescale 1ns / 1ps

module sl_preceptron_top 
#(parameter DATA_IN_LANES  = 4,
            DATA_IN_WIDTH  = 8,
            MEM_ADDR_WIDTH = 16,
            WEIGHTS_WIDTH  = 8,
            VECTOR_LENGTH  = 64,
            SUM_WIDTH = 24)
(
  input clk,
  input rst_n,
  input data_valid,
  input [DATA_IN_WIDTH*DATA_IN_LANES-1:0] data_in,
  input mem_wen,
  input mem_ren,
  input [MEM_ADDR_WIDTH-1:0] mem_addr,
  input [WEIGHTS_WIDTH-1:0]  mem_wdata,
  output [WEIGHTS_WIDTH-1:0] mem_rdata,
  input [SUM_WIDTH-1:0] cfg_ai_threshold,
  output reg [SUM_WIDTH-1:0] status_ai_sum,
  output reg status_ai_comparator
);

reg dut_mem_lock; // if asserted, the sram memory bus is locked by the dut, and external interface wont have access.
reg[10:0]  vector_data_rcv;  // max packets
reg start_vector_processing;
reg done_vector_processing;
wire[10:0] vector_data_rcv_n;
reg dut_mem_lock_n;
reg current_ai_comparator;
wire[DATA_IN_WIDTH-1:0] data_out_fifo;
wire data_out_fifo_valid;

//assign status_ai_sum = done_vector_processing ? current_ai_sum;
// data packet counter
assign vector_data_rcv_n = data_valid ? (done_vector_processing ? 0 : (vector_data_rcv + 4)) 
                          : vector_data_rcv;

always @(posedge clk) begin
  if (!rst_n) begin
    vector_data_rcv <= 0;
    dut_mem_lock <= 0;
  end  else begin
    vector_data_rcv <= vector_data_rcv_n;
    dut_mem_lock <= dut_mem_lock_n;
  end
end

// start and done vector status.
always @(*) begin
  start_vector_processing = 0;
  done_vector_processing = 0;
  dut_mem_lock_n = dut_mem_lock;
  if (vector_data_rcv == 0 && data_valid) begin
    start_vector_processing = 1;
  end
  if (vector_data_rcv == (VECTOR_LENGTH - DATA_IN_LANES) && data_valid) begin
    done_vector_processing = 1;
  end
  if(start_vector_processing || done_vector_processing) begin
    dut_mem_lock_n = ~dut_mem_lock;
  end
end

// sram drive from dut
wire dut_mem_wen;
wire dut_mem_ren;
wire[MEM_ADDR_WIDTH-1:0] dut_mem_addr;
wire[WEIGHTS_WIDTH-1:0] dut_mem_wdata;
wire[WEIGHTS_WIDTH-1:0] dut_mem_rdata;

// signals to sram memory
wire to_mem_wen;
wire to_mem_ren;
wire[MEM_ADDR_WIDTH-1:0] to_mem_addr;
wire[WEIGHTS_WIDTH-1:0] to_mem_wdata;
wire[WEIGHTS_WIDTH-1:0] from_mem_rdata;

assign to_mem_wen = dut_mem_lock ? dut_mem_wen : mem_wen;
assign to_mem_ren = dut_mem_lock ? dut_mem_ren : mem_ren;
assign to_mem_addr = dut_mem_lock ? dut_mem_addr : mem_addr;
assign to_mem_wdata = dut_mem_lock ? dut_mem_wdata : mem_wdata;
assign dut_mem_rdata = dut_mem_lock ? from_mem_rdata : 0;
assign mem_rdata = dut_mem_lock ? from_mem_rdata : 0;


sl_preceptron_ram  #(.DATA_WIDTH(WEIGHTS_WIDTH), .ADDR_WIDTH(MEM_ADDR_WIDTH)) 
weight_ram1 ( .clk(clk),
              .rst_n(rst_n),  //not used.
              .mem_wen(to_mem_wen),
              .mem_ren(to_mem_ren),
              .mem_addr(to_mem_addr),
              .mem_wdata(to_mem_wdata),
              .mem_rdata(from_mem_rdata)
            );

sl_preceptron_fifo #(.DATA_WIDTH(DATA_IN_WIDTH), .DATA_LANES(DATA_IN_LANES), .FIFO_SIZE(VECTOR_LENGTH/4*3)) 
data_incoming_fifo (.clk(clk),
                    .rst_n(rst_n),
                    .data_in_valid(data_valid),
                    .data_in(data_in),
                    .data_out_valid(data_out_fifo_valid),
                    .data_out(data_out_fifo)
                    );
endmodule
