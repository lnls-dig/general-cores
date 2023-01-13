target     = "xilinx"
action     = "simulation"
sim_tool   = "ghdl" #"modelsim"
top_module = "sim_top_ps_gpio"
syn_device = "XC7Z010"
# This can be deleted when GHDL not used
ghdl_opt = "--std=08 -frelaxed-rules"

files = [ "gpio_axi.vhd", "sim_top_ps_gpio.vhd" ]

modules = { "local" : ["../../../"] }

