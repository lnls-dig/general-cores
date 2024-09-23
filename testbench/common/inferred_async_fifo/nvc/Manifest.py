action = "simulation"
sim_tool = "nvc"
top_module = "inferred_async_fifo_tb"
target = "xilinx"
syn_device = "xc7a200t"

modules = {"local" : ["../"]}

nvc_opt = "--std=2008"
nvc_elab_opt = "--no-collapse"

sim_post_cmd = "nvc -r --dump-arrays --exit-severity=error %s --wave=%s.fst --format=fst"%(top_module, top_module)
