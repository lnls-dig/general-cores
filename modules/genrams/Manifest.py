files = ["genram_pkg.vhd"]

if (target == "altera"):
	modules = {"local" : "altera"}
elif (target == "xilinx"):
	modules = {"local" : "xilinx"}
else:
	modules = {"local" : "altera"}