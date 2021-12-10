# sl_preceptron
 A single layer preceptron has a Multiply and accumulate functionality, which accumulates the results of the dot product of two vectors and compares the result.

## Python script
An algorithm of the design is implemented in python3. And will generate the stimuli files for the testbench.
- `python3 sl_preceptron.py` will generate the stimuli files in the same folder. The test bench expects the file generated from this script. This will create the weight file, data file and expected result with threshold data. The length of the vector, the data width etc can be changed in the script.

## Make commands to run.
- `make elaborates` - elaborates the design in vivado
- `make elaborates` - runs the synthesis in vivado and generates report.
- `make sim_vivado/sl_preceptron_tb.v` - creates the simulation snapshot, compiles the verilog sources and run the simulation in vivado with waveform. 
All signals at the top level are already added.
- `make  sim/sl_preceptron_tb.fst` 
runs the simulations with icarus Verilog, and dumps the waveform file as sl_preceptron_tb.fst.
You can use GTKwave to view the waveform.
- `gtkwave sim/sl_preceptron_tb.fst &` - picks up the waveform dump.
