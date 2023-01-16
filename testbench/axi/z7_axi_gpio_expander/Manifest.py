# SPDX-FileCopyrightText: 2023 CERN (home.cern)
#
# SPDX-License-Identifier: CERN-OHL-W-2.0+

target     = "xilinx"
action     = "simulation"
sim_tool   = "ghdl"
top_module = "sim_top_ps_gpio"
syn_device = "XC7Z010"
ghdl_opt = "--std=08 -frelaxed-rules -Wno-hide"

files = [ "gpio_axi.vhd", "sim_top_ps_gpio.vhd" ]

modules = { "local" : ["../../../",
                       "../../osvvm/"] }

