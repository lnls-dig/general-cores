create_clock -period 100Mhz -name pcie_refclk_i [get_ports {pcie_refclk_i}]
create_clock -period 125Mhz -name clk125_i [get_ports {clk125_i}]
derive_pll_clocks
derive_clock_uncertainty

set_false_path -from {*|gc_wfifo:*|r_idx_gray*} -to {*|gc_wfifo:*|r_idx_shift_w*}
set_false_path -from {*|gc_wfifo:*|r_idx_gray*} -to {*|gc_wfifo:*|r_idx_shift_a*}
set_false_path -from {*|gc_wfifo:*|w_idx_gray*} -to {*|gc_wfifo:*|w_idx_shift_r*}
