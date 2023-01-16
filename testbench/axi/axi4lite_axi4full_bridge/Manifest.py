action  ="simulation"
sim_tool="ghdl"
target  ="generic"
ghdl_opt="--std=08 -frelaxed-rules -Wno-hide"
sim_top ="tb_axi4lite_axi4full_bridge"

files ="tb_axi4lite_axi4full_bridge.vhd"

modules = {"local" : ["../../../",
                    "../../osvvm/",
                      ]}

