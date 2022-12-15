# Timing constrains for basic 1 bit synchroniser.
# In many cases this could be solved with simple set_false_path, but in some
# cases this module is used in more time-critical applications, eg. inferred FIFO.
# In that case it makes sense to apply some max_delay constraint.
#
# You can always override any of these max_delay constraints in your global XDC
# with set_false_path because it has the highest priority.

set clk [get_clocks -of_objects [get_ports clk_i]]
set clk_period [get_property PERIOD $clk]

# ATTENTION: we can't use "all_fanin" to find the source register because
# apparently this command doesn't traverse outside of scoped reference (even with -flat switch)
# This method won't work properly if there's a combinational path between a source and target FF;
# but in a proper CDC circuit it's forbidded to have logic between FFs anyway!
set dst_ff [get_pins sync_*.sync0_*/D]
set src_ff [get_cells -of_objects [get_pins -filter {IS_LEAF && DIRECTION == OUT} -of_objects [get_nets -segments -of_objects $dst_ff]]]

# We use -quiet switch, because otherwise Vivado will throw critical warning
# if module is not used in the project (e.g. due to generics)
set_max_delay $clk_period -quiet -datapath_only -from $src_ff -to $dst_ff
