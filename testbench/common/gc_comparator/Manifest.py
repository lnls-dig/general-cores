action   = "simulation"
sim_tool = "ghdl"

target      = "xilinx"
syn_device  = "xc6slx45t"

top_module = "gc_comparator_tb" # for hdlmake2
sim_top    = "gc_comparator_tb" # for hdlmake3

files = [
        "gc_comparator_tb.vhd",
    ]

modules = {
    "local" :  [
        "../../../",
    ],
}
