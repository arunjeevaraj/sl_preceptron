/*
* Author: Arun Jeevaraj
* Date: Dec 8 2021
* Description: The Top module that stiches the fifo, mac and the sram blocks. The bus access to the Ram is muxed between the external mem interface and the mac.   
*/
`timescale 1ns / 1ps

module sl_preceptron_top 
#(parameter DATA_IN_LANES  = 4,
            DATA_IN_WIDTH  = 8,
            MEM_ADDR_WIDTH = 16,
            WEIGHTS_WIDTH  = 8,
            VECTOR_LENGTH  = 64,
            SUM_WIDTH = DATA_IN_WIDTH + WEIGHTS_WIDTH + $clog2(VECTOR_LENGTH),
            SRAM_BASE_ADDRESS = 'h1000)
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
  output[SUM_WIDTH-1:0] status_ai_sum,
  output status_ai_comparator
);

reg dut_mem_lock; // if asserted, the sram memory bus is locked by the dut, and external interface wont have access.

wire start_vector_processing;
wire done_vector_processing;
wire dut_mem_lock_n;
wire[DATA_IN_WIDTH-1:0] data_out_fifo;
wire data_out_fifo_valid;

//assign status_ai_sum = done_vector_processing ? current_ai_sum;



always @(posedge clk) begin
  if (!rst_n) begin
    dut_mem_lock <= 0;
  end  else begin
    dut_mem_lock <= dut_mem_lock_n;
  end
end

assign dut_mem_lock_n = start_vector_processing || done_vector_processing ? ~dut_mem_lock: dut_mem_lock;


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


wire valid_mem_addr;
assign valid_mem_addr = mem_addr >= SRAM_BASE_ADDRESS ? 1 : 0;


// mux mem interface to internal dut and external dut controls.
assign to_mem_wen = dut_mem_lock ? dut_mem_wen :
                    valid_mem_addr ?  mem_wen :
                    1'b0;
assign to_mem_ren = dut_mem_lock ? dut_mem_ren : mem_ren;
assign to_mem_addr = dut_mem_lock ? dut_mem_addr : 
                     valid_mem_addr ? (mem_addr - SRAM_BASE_ADDRESS) :
                     'h0;

assign to_mem_wdata = dut_mem_lock ? dut_mem_wdata : mem_wdata;
assign dut_mem_rdata = dut_mem_lock ? from_mem_rdata : 0;
assign mem_rdata = !dut_mem_lock ? from_mem_rdata : 0;


sl_preceptron_ram  #(.DATA_WIDTH(WEIGHTS_WIDTH), .ADDR_WIDTH(MEM_ADDR_WIDTH)) 
weight_ram1 ( .clk(clk),
              .rst_n(rst_n),  //not used.
              .mem_wen(to_mem_wen),
              .mem_ren(to_mem_ren),
              .mem_addr(to_mem_addr),
              .mem_wdata(to_mem_wdata),
              .mem_rdata(from_mem_rdata)
            );

sl_preceptron_fifo #(.DATA_WIDTH(DATA_IN_WIDTH), .DATA_LANES(DATA_IN_LANES), .FIFO_SIZE((VECTOR_LENGTH/4+1)*3 + 1 )) 
data_incoming_fifo (.clk(clk),
                    .rst_n(rst_n),
                    .data_in_valid(data_valid),
                    .data_in(data_in),
                    .data_out_valid(data_out_fifo_valid),
                    .data_out(data_out_fifo),
                    .done_vector_processing(done_vector_processing),
                    .start_vector_processing(start_vector_processing)
                    );

sl_preceptron_mac #( .DATA_IN_LANES(DATA_IN_LANES),
                     .DATA_IN_WIDTH(DATA_IN_WIDTH),
                     .MEM_ADDR_WIDTH(MEM_ADDR_WIDTH),
                     .WEIGHTS_WIDTH(WEIGHTS_WIDTH),
                     .VECTOR_LENGTH(VECTOR_LENGTH),
                     .SUM_WIDTH(SUM_WIDTH))
mac_processor (.clk(clk),
               .rst_n(rst_n),
               .data_valid(data_out_fifo_valid),
               .data_in(data_out_fifo),
               .mem_wen(dut_mem_wen),
               .mem_ren(dut_mem_ren),
               .mem_addr(dut_mem_addr),
               .mem_wdata(dut_mem_wdata),
               .mem_rdata(dut_mem_rdata),
               .cfg_ai_threshold(cfg_ai_threshold),
               .status_ai_sum(status_ai_sum),
               .status_ai_comparator(status_ai_comparator),
               .start_vector_processing(start_vector_processing),
               .done_vector_processing(done_vector_processing)
);
endmodule
