# the "-quiet" option is added for the use case where this module is added to
# the project, but not instatiated (e.g. because of generic settings)
# in that case Vivado would throw critical warnings during P&$

set_false_path -quiet -to [get_pins -hierarchical *rst_chains_reg[*]/CLR] 
