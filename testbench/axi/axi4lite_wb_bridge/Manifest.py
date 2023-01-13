action="simulation"
sim_tool="ghdl"
target="generic"
ghdl_opt="--std=08 -frelaxed-rules"
sim_top="tb_xaxi4lite_wb_bridge"

files="tb_xaxi4lite_wb_bridge.vhd"
modules={"local" : ["../../../",
                    "../../../modules/wishbone",
                    "../../../modules/axi"]}

