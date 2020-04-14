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
	local_modules = ["altera", "generic"]
elif target == "xilinx":
    if syn_device[0:4].upper()=="XC6V":
        local_modules = ["xilinx", "xilinx/virtex6"]
    else:
        local_modules = ["xilinx", "generic"]
else:
	local_modules = ["generic"]

modules = {"local" : local_modules + ["common", "cheby"]}
