action = "simulation"
sim_tool = "ghdl"
top_module = "gc_iq_demodulator_tb"

modules = {"local" : ["../"]}

ghdl_opt = "--std=08 -fsynopsys -g"

sim_post_cmd = "ghdl -r --std=08 %s --wave=%s.ghw --assert-level=error" % (top_module, top_module)
