module sl_preceptron_fifo 
#(parameter DATA_WIDTH = 8, DATA_LANES = 4, FIFO_SIZE = 48)
(
    input clk,
    input rst_n,
    input data_in_valid,
    input [DATA_WIDTH*DATA_LANES-1:0] data_in,
    output reg data_out_valid,
    output reg [DATA_WIDTH-1:0] data_out,
    output done_vector_processing
);

reg [DATA_WIDTH-1:0] fifo_mem [FIFO_SIZE:0];
reg [9:0] write_addr, write_addr_n;
reg [9:0] read_addr, read_addr_n;
reg [10:0] rcv_pkt_cnt;
reg [10:0] send_pkt_cnt;
wire [10:0] rcv_pkt_cnt_n;
wire [10:0] send_pkt_cnt_n;
reg no_pkt_rcv;
wire no_pkt_rcv_n;

wire[DATA_WIDTH:0] data_val3,
                   data_val2,
                   data_val1,
                   data_val0;


// assign
assign data_val0 = data_in_valid ? data_in[DATA_WIDTH-1:0] : fifo_mem[write_addr];
assign data_val1 = data_in_valid ? data_in[DATA_WIDTH*2-1:DATA_WIDTH] : fifo_mem[write_addr+1];
assign data_val2 = data_in_valid ? data_in[DATA_WIDTH*3-1:2*DATA_WIDTH] : fifo_mem[write_addr+2];
assign data_val3 = data_in_valid ? data_in[DATA_WIDTH*4-1:3*DATA_WIDTH] : fifo_mem[write_addr+3];
assign rcv_pkt_cnt_n = data_in_valid ? rcv_pkt_cnt + 4 :
                       done_vector_processing ? 0 :
                       rcv_pkt_cnt;
assign send_pkt_cnt_n = data_out_valid ? send_pkt_cnt + 1:
                       done_vector_processing ? 0 :
                       send_pkt_cnt;

assign done_vector_processing = !no_pkt_rcv ? send_pkt_cnt == rcv_pkt_cnt : 0;
assign no_pkt_rcv_n = data_in_valid ? 0 : no_pkt_rcv;

always @(posedge clk) begin
    if (!rst_n) begin
        write_addr <= 0;
        read_addr <= 0;
        rcv_pkt_cnt <= 0;
        send_pkt_cnt <= 0;
        no_pkt_rcv <= 1;              // set to zero once any packet is received.
        data_out <= 0;
    end else begin
        read_addr <= read_addr_n;
        write_addr <= write_addr_n;
        fifo_mem[write_addr] <= data_val0;
        fifo_mem[write_addr+1] <= data_val1;
        fifo_mem[write_addr+2] <= data_val2;
        fifo_mem[write_addr+3] <= data_val3;
        rcv_pkt_cnt <= rcv_pkt_cnt_n;
        send_pkt_cnt <= send_pkt_cnt_n;
        no_pkt_rcv <= no_pkt_rcv_n;
    end   
end



always @(*) begin
    data_out_valid = 0;
    write_addr_n = write_addr;
    read_addr_n = read_addr;
    if (data_in_valid) begin
        write_addr_n = write_addr >= (FIFO_SIZE-DATA_LANES-1) ? 0 : write_addr_n + 4;
    end
    if (data_in_valid || send_pkt_cnt < rcv_pkt_cnt) begin
        read_addr_n = read_addr >= (FIFO_SIZE-1) ? 0: read_addr_n + 1;
        data_out_valid = 1;
    end
end


endmodule