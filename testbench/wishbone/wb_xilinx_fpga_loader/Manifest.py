action = "simulation"
target = "xilinx"
fetchto="../../../ip_cores"

modules = { "local" :  "../../../" };

files = ["main.sv", "SIM_CONFIG_S6_SERIAL.v", "glbl.v" ]

vlog_opt= "+incdir+../../../sim"