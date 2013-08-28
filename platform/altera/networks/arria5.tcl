set files { arria5/dual_region arria5/single_region arria5/global_region }

set dir [file dirname [info script]]
post_message "Testing for megawizard regeneration in $dir:$files"

foreach i $files {
  if {![file exists "$dir/$i.qip"] || [file mtime "$dir/$i.txt"] > [file mtime "$dir/$i.qip"]} {
    post_message "Regenerating $i using qmegawiz"
    file copy -force "$dir/$i.txt" "$dir/$i.vhd"
    set sf [open "| qmegawiz -silent $dir/$i.vhd" "r"]
    while {[gets $sf line] >= 0} { post_message "$line" }
    close $sf
    file mtime "$dir/$i.qip" [file mtime "$dir/$i.vhd"]
  }
}
