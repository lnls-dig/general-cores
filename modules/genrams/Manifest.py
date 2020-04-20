files = [
	"genram_pkg.vhd",
	"memory_loader_pkg.vhd"];

# Be sure 'target' is defined.
try:
        target
except NameError:
        target = ""

# Target specific modules.
if target == "altera":
	modules = {"local": ["altera", "generic"]}
elif target == "xilinx":
    if syn_device[0:4].upper()=="XC6V":
        modules = {"local": ["xilinx", "xilinx/virtex6"]}
    else:
        modules = {"local": ["xilinx", "generic"]}
else:
	modules = {"local" : ["generic"]}

modules["local"].extend(["common", "cheby"])
