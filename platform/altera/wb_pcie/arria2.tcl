qmegawiz { arria2_pcie_hip arria2_pcie_reconf }

# erase the broke SDC file that gets generated
set dir [file dirname [info script]]
open "$dir/arria2_pcie_hip.sdc" "w"
