/*
* Author: Arun Jeevaraj
* Date: Dec 7 2021
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
localparam TEST_DURAT_CCS = 2500;
localparam SUM_WIDTH = DATA_IN_WIDTH + WEIGHTS_WIDTH + $clog2(VECTOR_LENGTH); //weight_width+data_in_width+log(64)/log2
localparam TOTAL_DATA_IN_WIDTH = DATA_IN_LANES*DATA_IN_WIDTH;
localparam N_VECTORS_IN_FILE = 5;
localparam SRAM_BASE_ADDRESS = 'h1000;


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
integer result_fid;
integer count = 0;
integer  match_count = 0;
reg wait_unti_cfg_ai_threshold_is_set = 0;

//instantiate DUT
sl_preceptron_top  #( .DATA_IN_LANES(DATA_IN_LANES),
					  .DATA_IN_WIDTH(DATA_IN_WIDTH),
					  .MEM_ADDR_WIDTH(MEM_ADDR_WIDTH),
					  .WEIGHTS_WIDTH(WEIGHTS_WIDTH),
					  .VECTOR_LENGTH(VECTOR_LENGTH),
					  .SUM_WIDTH(SUM_WIDTH),
					  .SRAM_BASE_ADDRESS(SRAM_BASE_ADDRESS))
DUT_TOP ( .clk(clk),
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
	// for 64 long vectors 8 bit wide data and weight data.
	if (VECTOR_LENGTH == 64) begin
		weight_fid = $fopen("../../algorithm/weight_Vect_s64_w8_M5_Weig_w8.dat", "r");
		data_in_fid = $fopen("../../algorithm/data_in_Vect_s64_w8_M5_Weig_w8.dat", "r");
		result_fid = $fopen("../../algorithm/thre_sum_comp_s64_w8_M5_Weig_w8.dat", "r");
	end else if (VECTOR_LENGTH == 128) begin
		weight_fid = $fopen("../../algorithm/weight_Vect_s128_w8_M5_Weig_w8.dat", "r");
		data_in_fid = $fopen("../../algorithm/data_in_Vect_s128_w8_M5_Weig_w8.dat", "r");
		result_fid = $fopen("../../algorithm/thre_sum_comp_s128_w8_M5_Weig_w8.dat", "r");
	end
	if (weight_fid == 0 || data_in_fid == 0) begin
		if (!weight_fid)  $display("File: ../../algorithm/weight_Vect_s64_w8_M5_Weig_w8.dat not found !");
		if (!data_in_fid)  $display("File: ../../algorithm/data_in_Vect_s64_w8_M5_Weig_w8.dat not found !");
		if (!result_fid)  $display("File: ../../algorithm/thre_sum_comp_s64_w8_M5_Weig_w8.dat not found !");
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
	repeat(N_VECTORS_IN_FILE) begin
		do_write_weights_to_ram(count);
		//do_read_weights_from_ram(count);
		wait_unti_cfg_ai_threshold_is_set = 0; // is set inside do_check_Expected result.  do_drive data will wait until the cfg threshold ai is set.
		fork  
			
			do_drive_data(count);
			do_check_expected_result(count);
			
		join
		count = count + 1;
	end
	if (match_count == N_VECTORS_IN_FILE) begin
		$display("The test passed with all matches !");
	end
	$finish;
end


//vector_i does change the file handler location, and has no functional impact.
// reads from the file and writes to the ram.
task do_write_weights_to_ram (input integer vector_i);               
	integer addr;
	reg[WEIGHTS_WIDTH-1:0] weight_data;
	integer c1;
begin
	$display("## accessing weight from RAM, vector %d", vector_i);
	addr = SRAM_BASE_ADDRESS;
	while (!$feof(weight_fid) && addr < SRAM_BASE_ADDRESS + VECTOR_LENGTH) begin
		c1 = $fscanf(weight_fid, "%d\n", weight_data);
		@(negedge clk);
		mem_wen = 1;
		mem_addr = addr;
		//$display("At time %0d  writing 0h%h at 0h%h", $time,  weight_data, mem_addr);
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

//vector_i does change the file handler location, and has no functional impact.
// reads from the ram to the read_weigth_data.
task do_read_weights_from_ram (input integer vector_i);               
	integer addr;
	reg[WEIGHTS_WIDTH-1:0] read_weight_data;
	integer c1;
begin

	$display("## accessing weight vector %d", vector_i);
	addr = SRAM_BASE_ADDRESS;
	while (addr < SRAM_BASE_ADDRESS + VECTOR_LENGTH) begin
		//c1 = $fscanf(weight_fid, "%d\n", weight_data);
		@(negedge clk);
		mem_wen = 0;
		mem_ren = 1;
		mem_addr = addr;
		@(posedge clk);
		@(posedge clk);
		//$display("At time %0d  read data 0h%h at 0h%h", $time,  mem_rdata, mem_addr);
		addr = addr + 1;
	end
	@(negedge clk);
	$display("## reading from ram done");
	mem_wen = 0;
	mem_wdata = 0;
	mem_ren = 0;
end
endtask


// reads from the file and drives the data into design.
task do_drive_data (input integer vector_i);
	integer count;
	reg[DATA_IN_WIDTH-1:0] data_in_read_0, data_in_read_1, data_in_read_2, data_in_read_3;
	integer c1;
	reg[31:0] read_vector_length_check;
begin
	wait(wait_unti_cfg_ai_threshold_is_set == 1);
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
		//$display("At time %0d driving data [0d%d] 0h%h into the design", $time, read_vector_length_check, data_in);
		read_vector_length_check = read_vector_length_check + 4;
	end
	@(negedge clk);
	$display("## driving data vector to DUT done");
	data_valid = 0;
	data_in = 0;
end
endtask

task do_check_expected_result (input integer vector_i);
	integer c1;
	reg[SUM_WIDTH-1:0] expected_ai_status_sum;
	reg[SUM_WIDTH-1:0] threshold_to_be_set;
	reg expected_ai_status_comparator;
begin
	$display("## At time %0d Accessing result file and fectching configuration for vector %d", $time, vector_i);
	if (!$feof(result_fid)) begin
		c1 = $fscanf(result_fid, "%d,%d,%d\n", threshold_to_be_set, expected_ai_status_sum, expected_ai_status_comparator);
		cfg_ai_threshold = threshold_to_be_set;
		wait_unti_cfg_ai_threshold_is_set = 1;
		$display("At time %0d tb sets threshold: [0d%d] expects ai_sum as 0d%d & ai_comp : 0d%d", $time, threshold_to_be_set, expected_ai_status_sum, expected_ai_status_comparator);

		wait(sl_preceptron_tb.DUT_TOP.mac_processor.c_state_del2 == 3);  //2 is state done. or if dut had status_valid, it could had been used instead.
		@(negedge clk);
		$display("At time %0d tb stops waiting ", $time);
		if (expected_ai_status_comparator == status_ai_comparator && expected_ai_status_sum == status_ai_sum) begin
			$display("#### At time %0d tb result matchs with the expected value  ", $time);
			match_count = match_count + 1;
		end else begin
			$display("Error At time %0d tb result doesnt matchs with the expected value  ", $time);
			$display("AI status sum : %d  expected AI status sum: %d ", status_ai_sum, expected_ai_status_sum);
			$display("AI status comp : %d  expected AI status comp: %d ", status_ai_comparator, expected_ai_status_comparator);
			match_count = match_count - 1;
		end
			
	end
	wait_unti_cfg_ai_threshold_is_set = 0;
	$display("## driving data vector to DUT done");
end
endtask

endmodule