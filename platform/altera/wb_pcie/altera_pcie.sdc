# The refclk assignment may need to be renamed to match design top level port name.
# May be desireable to move refclk assignment to a top level SDC file.
create_clock -period "100 MHz" -name {refclk} {refclk}
create_clock -period "100 MHz" -name {fixedclk_serdes} {fixedclk_serdes}
# testin bits are either static or treated asynchronously, cut the paths.
set_false_path -to [get_pins -hierarchical {*hssi_pcie_hip|testin[*]} ]
# SERDES Digital Reset inputs are asynchronous
set_false_path -to {*|altera_pcie_serdes:serdes|*|tx_digitalreset_reg0c[0]}
set_false_path -to {*|altera_pcie_serdes:serdes|*|rx_digitalreset_reg0c[0]}
#
# The following multicycle path constraints are only valid if the logic use to sample the tl_cfg_ctl and tl_cfg_sts signals 
# are as designed in the Altera provided files altpcierd_tl_cfg_sample.v and altpcierd_tl_cfg_sample.vhd   
# 
# These constraints are only valid when the altpcierd_tl_cfg_sample module or entity is used with the PCI Express
# Hard IP block in Stratix IV, Arria II, Cyclone IV and HardCopy IV devices. 
#
set_multicycle_path -end -setup -from [get_keepers {*|altera_pcie_core:wrapper|altpcie_hip_pipen1b:altpcie_hip_pipen1b_inst|tl_cfg_ctl_wr_hip}] 2
set_multicycle_path -end -hold  -from [get_keepers {*|altera_pcie_core:wrapper|altpcie_hip_pipen1b:altpcie_hip_pipen1b_inst|tl_cfg_ctl_wr_hip}] 1
set_multicycle_path -end -setup -from [get_keepers {*|altera_pcie_core:wrapper|altpcie_hip_pipen1b:altpcie_hip_pipen1b_inst|tl_cfg_ctl_hip[*]}] 3
set_multicycle_path -end -hold  -from [get_keepers {*|altera_pcie_core:wrapper|altpcie_hip_pipen1b:altpcie_hip_pipen1b_inst|tl_cfg_ctl_hip[*]}] 2
#
set_multicycle_path -end -setup -from [get_keepers {*|altera_pcie_core:wrapper|altpcie_hip_pipen1b:altpcie_hip_pipen1b_inst|tl_cfg_sts_wr_hip}] 2
set_multicycle_path -end -hold  -from [get_keepers {*|altera_pcie_core:wrapper|altpcie_hip_pipen1b:altpcie_hip_pipen1b_inst|tl_cfg_sts_wr_hip}] 1
set_multicycle_path -end -setup -from [get_keepers {*|altera_pcie_core:wrapper|altpcie_hip_pipen1b:altpcie_hip_pipen1b_inst|tl_cfg_sts_hip[*]}] 3
set_multicycle_path -end -hold  -from [get_keepers {*|altera_pcie_core:wrapper|altpcie_hip_pipen1b:altpcie_hip_pipen1b_inst|tl_cfg_sts_hip[*]}] 2
