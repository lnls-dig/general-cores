files = [	"generated/xwb_lm32.vhd",
         	"generated/lm32_allprofiles.v",
				 	"src/lm32_mc_arithmetic.v",
				 	"src/jtag_cores.v",
					"src/lm32_adder.v",
					"src/lm32_addsub.v",
					"src/lm32_dp_ram.vhd",
					"src/lm32_logic_op.v",
					"src/lm32_ram.vhd",
					"src/lm32_shifter.v"];
					
if(target == "altera"):
	files.extend(["platform/generic/lm32_multiplier.v", "platform/altera/jtag_tap.v"]);
elif (target == "xilinx" and syn_device[0:4].upper()=="XC6S"): # Spartan6
	files.extend(["platform/spartan6/lm32_multiplier.v", "platform/spartan6/jtag_tap.v"])
else:
	files.extend(["platform/generic/lm32_multiplier.v", "platform/generic/jtag_tap.v"]);
