target = "altera"
action = "synthesis"

#syn_device = "xc6slx45t"
#syn_grade = "-3"
#syn_package = "fgg484"
syn_top = "wishbone_demo"
syn_project = "wishbone_demo.qpf"

modules = { 
  "local" : [ "../../../top/gsi_pexaria2a/wishbone_demo" ]
}
