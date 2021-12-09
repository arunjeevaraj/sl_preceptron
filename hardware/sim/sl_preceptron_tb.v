/*
* Author: Arun Jeevaraj
* Date: Dec 8 2021
* Description: Test bench, Reads the stimuli file, drives the signals into single layer preceptron dut, 
* and provides a simple scoreboard that reports pass under the condition all expected results match!  
*/

`timescale 1ns/1ps

module sl_preceptron_tb ();

localparam DATA_IN_LANES  = 4;
localparam DATA_IN_WIDTH  = 8;
localparam MEM_ADDR_WIDTH = 16;
localparam WEIGHTS_WIDTH  = 8;
localparam VECTOR_LENGTH  = 64;
localparam CLOCK_PERIOD   = 5;
localparam RESET_DURATION = 12;
localparam TEST_DURAT_CCS = 200;
localparam SUM_WIDTH = 24;
localparam TOTAL_DATA_IN_WIDTH = DATA_IN_LANES*DATA_IN_WIDTH;

reg clk = 1'b0;
reg rst_n = 1'b1;
//data interface
reg data_valid = 1'b0;
reg[TOTAL_DATA_IN_WIDTH-1:0] data_in = 0;
//mem_interface
reg mem_wen;
reg mem_ren;
reg[MEM_ADDR_WIDTH-1:0]   mem_addr = 0;
reg[WEIGHTS_WIDTH-1:0]    mem_wdata = 0;
wire[WEIGHTS_WIDTH-1:0]   mem_rdata;
//configuration and status interface.
reg[SUM_WIDTH-1:0]    cfg_ai_threshold;
wire[SUM_WIDTH-1:0]   status_ai_sum;
wire status_ai_comparator;                     

//testbench variables.
integer hcc_number = 0;
reg loop = 1;
reg reset_done = 0;
integer weight_fid;
integer data_in_fid;

//instantiate DUT
sl_preceptron_top  #( .DATA_IN_LANES(DATA_IN_LANES),
					  .DATA_IN_WIDTH(DATA_IN_WIDTH),
					  .MEM_ADDR_WIDTH(MEM_ADDR_WIDTH),
					  .WEIGHTS_WIDTH(WEIGHTS_WIDTH),
					  .VECTOR_LENGTH(VECTOR_LENGTH),
					  .SUM_WIDTH(SUM_WIDTH))
DUT_TOP ( .clk,
  .rst_n(rst_n),
  .data_valid(data_valid),
  .data_in(data_in),
  .mem_wen(mem_wen),
  .mem_ren(mem_ren),
  .mem_addr(mem_addr),
  .mem_wdata(mem_wdata),
  .mem_rdata(mem_rdata),
  .cfg_ai_threshold(cfg_ai_threshold),
  .status_ai_sum(status_ai_sum),
  .status_ai_comparator(status_ai_comparator)
);

///CLOCK AND RESET
always begin
	clk <= !clk;
    #CLOCK_PERIOD;
	hcc_number = hcc_number + 1;
end

initial begin
	@(negedge clk);
	rst_n = 0;
	#RESET_DURATION;
	rst_n = 1;
	reset_done = 1;
end

// testbench termination
initial begin
	weight_fid = $fopen("../../algorithm/weight_Vect_s64_w8_M5_Weig_w8.dat", "r");
	data_in_fid = $fopen("../../algorithm/data_in_Vect_s64_w8_M5_Weig_w8.dat", "r");
	if (weight_fid == 0 || data_in_fid == 0) begin
		if (!weight_fid)  $display("File: ../../algorithm/weight_Vect_s64_w8_M5_Weig_w8.dat not found !");
		if (!data_in_fid)  $display("File: ../../algorithm/data_in_Vect_s64_w8_M5_Weig_w8.dat not found !");
		$finish;
	end
	while (loop) begin
		if (hcc_number > TEST_DURAT_CCS*2) begin
			$display("At time %0d Test Ended", $time);
			$finish;
  		end
		@(negedge clk);  // yield for other process to continue running.
	end
	$finish;
end

//testbench stimuli drive.
initial begin
	$display("At time %0d Test started !", $time);
  `ifdef IVERILOG
    $dumpfile("sl_preceptron_tb.fst");
    $dumpvars(0, sl_preceptron_tb);
	$dumpvars(0, DUT_TOP);
  `endif
	@(posedge reset_done);
	$display("At time %0d Test writing to weight memory !", $time);
	do_write_weights_to_ram(0);
	do_drive_data(0);

	//do_write_weights_to_ram(1);
end


//vector_i does change the file handler location, and has no functional impact.
// reads from the file and writes to the ram.
task do_write_weights_to_ram (input integer vector_i);               
	integer addr;
	reg[WEIGHTS_WIDTH-1:0] weight_data;
	integer c1;
begin
	$display("## accessing weight vector %d", vector_i);
	addr = 0;
	while (!$feof(weight_fid) && addr < VECTOR_LENGTH) begin
		c1 = $fscanf(weight_fid, "%d\n", weight_data);
		@(negedge clk);
		mem_wen = 1;
		mem_addr = addr;
		$display("At time %0d  writing 0h%h at 0h%h", $time,  weight_data, mem_addr);
		addr = addr + 1;
		mem_wdata = weight_data;
		mem_ren = 0;
	end
	@(negedge clk);
	$display("## writing to ram done");
	mem_wen = 0;
	mem_wdata = 0;
	
end
endtask

// reads from the file and drives the data into design.
task do_drive_data (input integer vector_i);
	integer count;
	reg[DATA_IN_WIDTH-1:0] data_in_read_0, data_in_read_1, data_in_read_2, data_in_read_3;
	integer c1;
	reg[31:0] read_vector_length_check;
begin
	$display("## At time %0d Accessing data vector %d", $time, vector_i);
	data_valid = 0;
	read_vector_length_check = 0;
	while (!$feof(data_in_fid) && read_vector_length_check < VECTOR_LENGTH) begin
		c1 = $fscanf(data_in_fid, "%d\n", data_in_read_0);
		c1 = $fscanf(data_in_fid, "%d\n", data_in_read_1);
		c1 = $fscanf(data_in_fid, "%d\n", data_in_read_2);
		c1 = $fscanf(data_in_fid, "%d\n", data_in_read_3);
		@(negedge clk);
		data_valid = 1;
		data_in = {data_in_read_3, data_in_read_2, data_in_read_1, data_in_read_0};
		$display("At time %0d driving data [0d%d] 0h%h into the design", $time, read_vector_length_check, data_in);
		read_vector_length_check = read_vector_length_check + 4;
	end
	@(negedge clk);
	$display("## driving data vector to DUT done");
	data_valid = 0;
	data_in = 0;
end
endtask

endmodule