try:
        target
except NameError:
        target = ""

if target=="altera":
	modules = {"local" : "altera"}
elif target=="xilinx":
	modules = {"local" : "xilinx"}
else:
        pass
