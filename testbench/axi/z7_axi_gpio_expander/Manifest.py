target = "xilinx"
action = "simulation"
sim_tool = "modelsim"
top_module = "sim_top_ps_gpio"
syn_device = "XC7Z010"

files = [ "gpio_axi.vhd", "sim_top_ps_gpio.vhd" ]

modules = { "local" : ["../../../"] }

