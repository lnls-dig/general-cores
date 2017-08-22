action = "simulation"
target = "xilinx"

syn_device = "5agxma3d4f"
top_module = "main"
sim_tool = "modelsim"

modules = {"local" : [ "../../.." ]	};
files = ["main.sv", "lm32_test_system.vhd"]		
