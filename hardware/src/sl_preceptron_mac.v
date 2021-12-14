/*
* Author: Arun Jeevaraj
* Date: Dec 8 2021
* Description: Multiply and accumulate, initates when start_processing pulse asserts high, until done vector_processing is set.
*              this modules expects continuous data and weight stream, and supports no back pressure.  
*/
module sl_preceptron_mac 
#(parameter DATA_IN_LANES  = 4,
            DATA_IN_WIDTH  = 8,
            MEM_ADDR_WIDTH = 16,
            WEIGHTS_WIDTH  = 8,
            VECTOR_LENGTH  = 64,
            SUM_WIDTH = 22)
(
  input clk,
  input rst_n,
  input data_valid,
  input [DATA_IN_WIDTH-1:0] data_in,
  output reg mem_wen,
  output reg mem_ren,
  output reg [MEM_ADDR_WIDTH-1:0] mem_addr,
  output reg [WEIGHTS_WIDTH-1:0]  mem_wdata,
  input [WEIGHTS_WIDTH-1:0] mem_rdata,
  input [SUM_WIDTH-1:0] cfg_ai_threshold,
  output reg [SUM_WIDTH-1:0] status_ai_sum,
  output reg status_ai_comparator,
  input start_vector_processing,
  input done_vector_processing
);

localparam ST_IDLE  = 0,
           ST_LOAD_RAM = 1,
           ST_START = 2,
           ST_DONE  = 3;

reg[2:0] c_state, n_state, c_state_del1, c_state_del2;
reg[MEM_ADDR_WIDTH-1:0] read_addr;


//
//reg data_valid_del_1;
//reg [DATA_IN_WIDTH-1:0] data_in_del1;


reg[2*DATA_IN_WIDTH-1:0] mul_result_reg;
wire[2*DATA_IN_WIDTH-1:0] mul_result;
reg[SUM_WIDTH-1:0] accumulated_result_reg;
wire[SUM_WIDTH-1:0] accumulated_result;

reg [SUM_WIDTH-1:0] cfg_ai_threshold_store;
wire [SUM_WIDTH-1:0] cfg_ai_threshold_store_n;


wire [SUM_WIDTH-1:0] current_ai_sum;
wire current_ai_comparator;

assign current_ai_comparator = c_state_del1 == ST_DONE ?  cfg_ai_threshold_store < accumulated_result_reg : status_ai_comparator;
assign current_ai_sum = c_state_del1 == ST_DONE ? accumulated_result_reg : status_ai_sum;

always @(posedge clk) begin
  if (!rst_n) begin
    cfg_ai_threshold_store <= 0;
    c_state <= ST_IDLE;
    c_state_del1 <= ST_IDLE;
    c_state_del2 <= ST_IDLE;
    mem_addr <= 0;
    mul_result_reg <= 0;
    accumulated_result_reg <= 0;
    status_ai_comparator <= 0;
    status_ai_sum <= 0;
  end else begin
    cfg_ai_threshold_store <= cfg_ai_threshold_store_n;
    c_state <= n_state;
    c_state_del1 <= c_state;
    c_state_del2 <= c_state_del1;
    mem_addr <= read_addr;
    mul_result_reg <= mul_result;
    accumulated_result_reg <= accumulated_result;
    status_ai_comparator <= current_ai_comparator;
    status_ai_sum <= current_ai_sum;
  end
end


assign cfg_ai_threshold_store_n = start_vector_processing ? cfg_ai_threshold : cfg_ai_threshold_store; // store the threshold at the start of vector processing.
assign mul_result = c_state == ST_START ? mem_rdata*data_in : mul_result_reg;
assign accumulated_result = c_state_del1 == ST_START ? accumulated_result_reg + mul_result_reg 
                          : c_state_del1 == ST_DONE ? 0
                          : accumulated_result_reg; 


always @(*) begin
  mem_wen = 0; // always zero, mac is always reading weights, no writes are initiated.
  mem_ren = 0;
  read_addr = mem_addr;
  mem_wdata = 0;
  case (c_state)
    ST_IDLE: begin
      if (start_vector_processing) begin
        n_state = ST_LOAD_RAM;
      end else begin
        n_state = ST_IDLE;
        read_addr = 0;
      end
    end
    ST_LOAD_RAM: begin
      n_state = ST_START;
      mem_ren = 1;
      read_addr = mem_addr + 1;
    end
    ST_START: begin
      if (done_vector_processing) begin
        n_state = ST_DONE;
      end else begin
        n_state = ST_START;
        mem_ren = 1;
        read_addr = mem_addr + 1;
      end
    end
    ST_DONE: begin
      n_state = ST_IDLE;
    end 
    default: begin
      n_state = ST_IDLE;
    end 
  endcase
end

endmodule