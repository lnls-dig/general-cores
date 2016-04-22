
files = [
	"genram_pkg.vhd",
	"memory_loader_pkg.vhd"];

if (target == "altera"):
	modules = {"local" : ["altera", "generic"]}
elif (target == "xilinx" and syn_device[0:4].upper()=="XC6V"):
	modules = {"local" : ["xilinx", "xilinx/virtex6"]}
elif (target == "xilinx"):
	modules = {"local" : ["xilinx", "generic"]}
