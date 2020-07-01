sim_tool = "modelsim"
top_module="main"
action = "simulation"
target = "xilinx"
fetchto = "../../ip_cores"
vcom_opt="-mixedsvvh l -2008"
sim_top="main"
syn_device="xc7k70t"
include_dirs=["../../../sim", "../include" ]
modelsim_ini_path="~/eda/modelsim-lib-2016.4"

files = [ "main.sv" ]

modules = { "local" :  [ "../../../" ] }

