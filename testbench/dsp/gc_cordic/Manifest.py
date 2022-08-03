action   = "simulation"
sim_tool = "modelsim"

vcom_opt = "-mixedsvvh l"

target      = "xilinx"
syn_device  = "xc6slx45t"

top_module = "main" # for hdlmake2
sim_top    = "main" # for hdlmake3

include_dirs = [
    "../../../sim/"
]

modules = {
    "local" :  [
        "../../../", "../../../sim/"
    ],
}

files = [
    "main.sv",
]
