action   = "simulation"
sim_tool = "modelsim"

target      = "xilinx"
syn_device  = "xc6slx45t"

top_module = "gc_bicolor_led_ctrl_tb" # for hdlmake2
sim_top    = "gc_bicolor_led_ctrl_tb" # for hdlmake3

files = [
        "gc_bicolor_led_ctrl_tb.vhd",
    ]

modules = {
    "local" :  [
        "../../../",
    ],
}
