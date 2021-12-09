`timescale 1ns / 1ps
module sl_preceptron_ram 
#(parameter DATA_WIDTH = 8, ADDR_WIDTH = 6)
(input clk,
  input rst_n,  //not used.
  input mem_wen,
  input mem_ren,
  input [ADDR_WIDTH-1:0] mem_addr,
  input [DATA_WIDTH-1:0] mem_wdata,
  output reg [DATA_WIDTH-1:0] mem_rdata
);

reg[DATA_WIDTH-1:0] memory_sram[0:2**ADDR_WIDTH-1];

wire[DATA_WIDTH-1:0] data_write, data_read;

assign data_write = mem_wen ? mem_wdata : memory_sram[mem_addr];
assign data_read = mem_ren ? memory_sram[mem_addr] : 'b0;

always @(posedge clk) begin
    memory_sram[mem_addr] <= data_write;
    mem_rdata <= data_read;
end

endmodule