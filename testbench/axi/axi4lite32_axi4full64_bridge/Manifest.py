action="simulation"
sim_tool="ghdl"
target="generic"
ghdl_opt="--std=08 -frelaxed-rules"
sim_top="tb_axi4lite32_axi4full64_bridge"

files="tb_axi4lite32_axi4full64_bridge.vhd"

modules={"local" : ["../../../",
                    "../../../modules/wishbone",
                    "../../../modules/axi"]}

