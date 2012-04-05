create_clock -period "125 MHz" -name {pcie_clk125_i} {pcie_clk125_i}
create_clock -period "100 MHz" -name {pcie_refclk_i} {pcie_refclk_i}
derive_pll_clocks
derive_clock_uncertainty