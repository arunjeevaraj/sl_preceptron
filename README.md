# sl_preceptron

## Make commands to run.
- `make elaborates` - elaborates the design in vivado
- `make elaborates` - runs the synthesis in vivado and generates report.
- `make sim_vivado/sl_preceptron_tb.v` - creates the simulation snapshot, compiles the verilog sources and run the simulation in vivado with waveform. 
All signals at the top level are already added.
- `make  sim/sl_preceptron_tb.fst` 
runs the simulations with icarus Verilog, and dumps the waveform file as sl_preceptron_tb.fst.
You can use GTKwave to view the waveform.
- `gtkwave sim/sl_preceptron_tb.fst &` - picks up the waveform dump.
