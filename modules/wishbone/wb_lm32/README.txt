GenCores LM32 VHDL configurable wrapper
---------------------------------------

This is a VHDL-ized distribution of LM32 CPU core with pre-implemented feature sets selectable using a "profile" generic. 
Note that this core uses the new (spec rev. B4) pipelined mode, therefore it requires a *pipelined* interconnect. 

Currently there are 6 different profiles (all support interrupts)
- minimal - bare minimum (just LM32 core)
- medium - LM32 core with pipelined multiplier, barrel shifter and sign extension unit 
- medium_icache - the above + instruction cache (up to 3 times faster execution)
- medium_(icache_)debug - the above 2 versions with full JTAG debugger
- full - full LM32 core (all instructions + I/D caches + bus errors)
- full_debug - full core with debug
- wrnode - special profile with internal single-cycle code/data RAM, for the WR node design

The profiles are defined in lm32.profiles file. If you want to add/remove any, re-run gen_lmcores.py script afterwards (requires
Modelsim vlog compiler for preprocessing Verilog sources).

Acknowledgements:
- Lattice Semiconductor, for open-sourcing this excellent CPU
- Sebastien Bordeauducq, for making the LM32 more platform-agnostic
- Wesley W. Terpstra (GSI) - for excellent pipelined Wishbone wrapper (used in auto-generated xwb_lm32.vhd) 
	and Xilinx/Altera embedded JTAG cores.

