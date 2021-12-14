/*
* Author: Arun Jeevaraj
* Date: Dec 8 2021
* Description: 4:1 gear fifo, which consumes 4 inputs and produces 1 output per cc. The module also generates the start processing and done processing signals,
*               Has no overflow protection!, and supports no back pressure.   
*/
module sl_preceptron_fifo 
#(parameter DATA_WIDTH = 8, DATA_LANES = 4, FIFO_SIZE = 52)
(
    input clk,
    input rst_n,
    input data_in_valid,
    input [DATA_WIDTH*DATA_LANES-1:0] data_in,
    output reg data_out_valid,
    output reg [DATA_WIDTH-1:0] data_out,
    output done_vector_processing,
    output start_vector_processing
);


reg[2:0] c_state, n_state, p_state;
localparam ST_IDLE = 0,
           ST_START = 1,
           ST_DONE = 2;

reg [DATA_WIDTH-1:0] fifo_mem [FIFO_SIZE:0];
reg [9:0] write_addr, write_addr_n;
reg [9:0] read_addr, read_addr_n;
reg [10:0] rcv_pkt_cnt;
reg [10:0] send_pkt_cnt;
wire [10:0] rcv_pkt_cnt_n;
wire [10:0] send_pkt_cnt_n;

reg data_in_valid_reg;
reg[DATA_WIDTH-1:0] data_out_n;
reg data_out_valid_n;
wire[DATA_WIDTH-1:0] data_val3,
                     data_val2,
                     data_val1,
                     data_val0;


// assign
assign data_val0 = data_in_valid ? data_in[DATA_WIDTH-1:0] : fifo_mem[write_addr];
assign data_val1 = data_in_valid ? data_in[DATA_WIDTH*2-1:DATA_WIDTH] : fifo_mem[write_addr+1];
assign data_val2 = data_in_valid ? data_in[DATA_WIDTH*3-1:2*DATA_WIDTH] : fifo_mem[write_addr+2];
assign data_val3 = data_in_valid ? data_in[DATA_WIDTH*4-1:3*DATA_WIDTH] : fifo_mem[write_addr+3];
assign rcv_pkt_cnt_n = data_in_valid ? rcv_pkt_cnt + 4 :
                       c_state == ST_IDLE ? 0 :
                       rcv_pkt_cnt;
assign send_pkt_cnt_n = data_out_valid ? send_pkt_cnt + 1:
                       c_state == ST_IDLE ? 0 :
                       send_pkt_cnt;


assign start_vector_processing = data_in_valid == 1 && data_in_valid_reg == 0;
assign done_vector_processing = c_state == ST_DONE;

always @(posedge clk) begin
    if (!rst_n) begin
        write_addr <= 0;
        read_addr <= 0;
        rcv_pkt_cnt <= 0;
        send_pkt_cnt <= 0;
        data_out <= 0;
        data_out_valid <= 0;
        data_in_valid_reg <= 0;
        c_state <= ST_IDLE;
    end else begin
        read_addr <= read_addr_n;
        write_addr <= write_addr_n;
        fifo_mem[write_addr] <= data_val0;
        fifo_mem[write_addr+1] <= data_val1;
        fifo_mem[write_addr+2] <= data_val2;
        fifo_mem[write_addr+3] <= data_val3;
        rcv_pkt_cnt <= rcv_pkt_cnt_n;
        send_pkt_cnt <= send_pkt_cnt_n;
        data_out <= data_out_n;
        data_out_valid <= data_out_valid_n;
        data_in_valid_reg <= data_in_valid;
        c_state <= n_state;
    end   
end
//state machine

always @(*) begin
    n_state = c_state;
    case(c_state) 
        ST_IDLE: begin
            if (start_vector_processing) begin
                n_state = ST_START;
            end
        end
        ST_START: begin
            if (send_pkt_cnt == rcv_pkt_cnt-2) begin
                n_state = ST_DONE;
            end else
                n_state = ST_START;
        end       
        default : begin
            n_state = ST_IDLE;
        end
    endcase
end

always @(*) begin
    data_out_n = 0;
    write_addr_n = write_addr;
    data_out_valid_n = 0;
    read_addr_n = read_addr;
    if (data_in_valid) begin
        write_addr_n = write_addr >= (FIFO_SIZE-DATA_LANES-1) ? 0 : write_addr_n + 4;
    end
    if (c_state == ST_START && rcv_pkt_cnt != send_pkt_cnt) begin
        read_addr_n = read_addr >= (FIFO_SIZE-1) ? 0: read_addr_n + 1;
        data_out_valid_n = 1;
        data_out_n = fifo_mem[read_addr];
    end
end


endmodule