action="simulation"
sim_tool="ghdl"
target="generic"
ghdl_opt="--std=08 -frelaxed-rules -Wno-hide"
sim_top="tb_xaxi4lite_wb_bridge"

files="tb_xaxi4lite_wb_bridge.vhd"

modules={"local" : ["../../../",
                    "../../osvvm/",
                    "../../../modules/wishbone",
                    "../../../modules/axi"]}

