
files = [
	"genram_pkg.vhd",
	"memory_loader_pkg.vhd",
	"generic_shiftreg_fifo.vhd",
	"inferred_sync_fifo.vhd",
	"inferred_async_fifo.vhd"];

if (target == "altera"):
	modules = {"local" : "altera"}
elif (target == "xilinx" and syn_device[0:4].upper()=="XC6V"):
	modules = {"local" : ["xilinx", "xilinx/virtex6"]}
elif (target == "xilinx" and syn_device[0:3].upper()=="XC7"):
	modules = {"local" : ["xilinx", "xilinx/series7"]}
elif (target == "xilinx"):
	modules = {"local" : ["xilinx", "generic"]}
