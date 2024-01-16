# Timing constrains for read word synchronizer.
# Flag handskaking is done by pulse synchroniser submodule which should have its
# own constraint file and thus isn't covered here

set src_clk [get_clocks -of_objects [get_ports clk_in_i]]
set dst_clk [get_clocks -of_objects [get_ports clk_out_i]]
set src_clk_period [get_property PERIOD $src_clk]
set dst_clk_period [get_property PERIOD $dst_clk]
set skew_value [expr {(($src_clk_period < $dst_clk_period) ? $src_clk_period : $dst_clk_period)}]

set src_ff [get_pins gc_sync_word_data*[*]/C]
set dst_ff [get_pins data_out*[*]/D]

# We use -quiet switch, because otherwise Vivado will throw critical warning
# if module is not used in the project (e.g. due to generics)
set_max_delay $skew_value -quiet -datapath_only -from $src_ff -to $dst_ff
set_bus_skew $skew_value -quiet -from $src_ff -to $dst_ff
