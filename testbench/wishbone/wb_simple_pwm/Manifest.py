action = "simulation"
target = "xilinx"
fetchto="../../../ip_cores"

modules = { "local" :  "../../../" };

files = ["main.sv"]

vlog_opt= "+incdir+../../../sim"