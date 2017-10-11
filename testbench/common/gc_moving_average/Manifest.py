action   = "simulation"
sim_tool = "ghdl"

target      = "xilinx"
syn_device  = "xc6slx45t"

top_module = "gc_moving_average_tb" # for hdlmake2
sim_top    = "gc_moving_average_tb" # for hdlmake3

files = [
        "gc_moving_average_tb.vhd",
    ]

modules = {
    "local" :  [
        "../../../",
    ],
}
