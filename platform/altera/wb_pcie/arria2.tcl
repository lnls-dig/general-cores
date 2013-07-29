set files { arria2_pcie_hip arria2_pcie_reconf }

set dir [file dirname [info script]]
post_message "Testing for megawizard regeneration in $dir:$files"

foreach i $files {
  if {![file exists "$dir/$i.qip"] || [file mtime "$dir/$i.txt"] > [file mtime "$dir/$i.qip"]} {
    post_message "Regenerating $i using qmegawiz"
    file copy -force "$dir/$i.txt" "$dir/$i.vhd"
# disable error reporting as arria2 hip is broken
#    set sf [open "| qmegawiz -silent $dir/$i.vhd" "r"]
#    while {[gets $sf line] >= 0} { post_message "$line" }
#    close $sf
    qexec "qmegawiz -silent $dir/$i.vhd"
    file mtime "$dir/$i.qip" [file mtime "$dir/$i.vhd"]
  }
}

# erase the broke SDC file that gets generated
open "$dir/arria2_pcie_hip.sdc" "w"