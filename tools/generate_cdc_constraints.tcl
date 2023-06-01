##-------------------------------------------------------------------------------
## CERN BE-CEM-EDL
## General Cores
## https://www.ohwr.org/projects/general-cores
##-------------------------------------------------------------------------------
##
## Tcl script to produce CDC (Clock Domain Crossing) constraints for the CDC primitives
## used in your Vivado design:
## - gc_sync
## - gc_sync_register
## - gc_reset_multi_aasd
##
## Instructions for use:
## - synthesize your design
## - open the synthesized design in Vivado
## - run this script (source generate_cdc_constraints.tcl)
## - the result of operation is a file called "gencores_constraints.xdc". Add it
##   to the project's sources.
## - note: you must rerun this script every time you change (add/remove/modify)
##   gencores's CDC primtives in your design.
## - enjoy and profit!
##
##-------------------------------------------------------------------------------
## Copyright CERN 2023
##-------------------------------------------------------------------------------
## This Source Code Form is subject to the terms of the Mozilla Public License,
## version 2.0. If a copy of the MPL was not distributed with this file, You can
## obtain one at https://mozilla.org/MPL/2.0/.
##-------------------------------------------------------------------------------

proc generate_gc_sync_constraints { f_out } {
    set the_cells [ get_cells -hier -filter { REF_NAME=~gc_sync* } ]
    set count 0

    foreach cell $the_cells {

#skip gc_sync_ffs instances (as they contain a gc_sync inside)
        if {[string first "gc_sync_ffs" [get_property REF_NAME [get_cells $cell]]] != -1} {
            puts $f_out "#WARNING: skip gc_sync_ffs cell '$cell'"
            continue
        }

        set dst_ff_clr [get_pins "$cell/sync_*.sync*_*/CLR" ]
        set dst_ff [get_pins "$cell/sync_*.sync0_*/D" ]

        if { "$dst_ff" == "" } {
            set dst_ff [get_pins -hier -filter "name=~$cell/sync_*.sync0_*/D" ]
        }
        if { "$dst_ff_clr" == "" } {
            set dst_ff_clr [get_pins -hier -filter "name=~$cell/sync_*.sync*_*/CLR" ]
        }

        if { "$dst_ff" == "" } {
            puts $f_out "#WARNING: can't find destination FF for cell '$cell'"
            continue
        }

        set clk [ get_clocks -of_objects [ get_pins -filter {REF_PIN_NAME=~clk_i*} -of $cell ] ]
        set src_cells [get_cells -of_objects [get_pins -filter {IS_LEAF && DIRECTION == OUT} -of_objects [get_nets -segments -of_objects $dst_ff]]]
        set src_ff [ get_pins -filter {DIRECTION == OUT} -of_objects $src_cells ]
        set clk_period [get_property PERIOD [ lindex $clk 0 ] ]

        puts $f_out "#Cell: $cell, src $src_ff, dst $dst_ff, clock $clk, period $clk_period"
        puts $f_out "set_max_delay $clk_period -datapath_only -from { $src_ff } -to { $dst_ff }"
        foreach clr_pin $dst_ff_clr {
            puts $f_out "set_false_path -to { $clr_pin }"
        }
        incr count
    }

    return $count
}

proc generate_gc_sync_register_constraints { f_out } {
    set the_cells [ get_cells -hier -filter { REF_NAME=~gc_sync_register* } ]
    set count 0

    foreach cell $the_cells {

        set dst_ff_clr [get_pins "$cell/sync*_*[*]/CLR" ]
        set dst_ff [get_pins "$cell/sync0_*[*]/D" ]


        if { "$dst_ff" == "" } {
            set dst_ff [get_pins -hier -filter "name=~$cell/sync0_*[*]/D" ]
        }
        if { "$dst_ff_clr" == "" } {
            set dst_ff_clr [get_pins -hier -filter "name=~$cell/sync*_*[*]/CLR" ]
        }

        puts $dst_ff

        if { "$dst_ff" == "" } { 
            puts $f_out "#WARNING: can't find destination FF for cell '$cell'"
            continue
        }

        set clk [ get_clocks -of_objects [ get_pins -filter {REF_PIN_NAME=~clk_i*} -of $cell ] ]
        set src_ff [get_cells -of_objects [get_pins -filter {IS_LEAF && DIRECTION == OUT} -of_objects [get_nets -segments -of_objects $dst_ff]]]
        set clk_period [get_property PERIOD [ lindex $clk 0 ] ]

        puts "Cell: $cell, src $src_ff, dst $dst_ff, clock $clk, period $clk_period"
        puts $f_out "set_max_delay $clk_period -quiet -datapath_only -from { $src_ff } -to { $dst_ff }"
        puts $f_out "set_bus_skew $clk_period -quiet -from { $src_ff } -to { $dst_ff }"
        
        foreach clr_pin $dst_ff_clr {
            puts $f_out "set_false_path -to { $clr_pin }"
        }
        incr count
    }

    return $count
}

proc generate_gc_reset_multi_aasd_constraints { f_out } {
    set the_cells [ get_cells -hier -filter { REF_NAME=~gc_reset_multi_aasd* } ]
    set count 0

    foreach cell $the_cells {

        set dst_ff_clr [get_pins "$cell/*rst_chains_reg[*]/CLR" ]
        if { "$dst_ff_clr" == "" } {
            set dst_ff_clr [get_pins -hier -filter "name=~$cell/*rst_chains_reg[*]/CLR" ]
        }

        if { "$dst_ff_clr" == "" } { 
            puts $f_out "#WARNING: can't find destination FF CLR pin for cell '$cell'"
            continue
        }

        foreach clr_pin $dst_ff_clr {
            puts $f_out "set_false_path -to { $clr_pin }"
        }
        incr count
    }

    return $count
}

proc generate_gc_falsepath_waiver_constraints { f_out } {
    set the_cells [ get_cells -hier -filter { REF_NAME=~gc_falsepath_waiver* } ]
    set count 0

    foreach cell $the_cells {

        set src_ff [get_pins "$cell/in_i[*]" ]
        if { "$src_ff" == "" } {
            set src_ff [get_pins -hier -filter "name=~$cell/in_i[*]" ]
        }

        if { "$src_ff" == "" } { 
            puts $f_out "#WARNING: can't find source pin for '$cell'"
            continue
        }

        foreach pin $src_ff {
            puts $f_out "set_false_path -from { $pin }"
        }
        incr count
    }

    return $count
}


set f_out [open "gencores_constraints.xdc" w]
set n_gc_sync_cells [ generate_gc_sync_constraints $f_out ]
set n_gc_sync_register_cells [ generate_gc_sync_register_constraints $f_out ]
set n_gc_reset_multi_aasd_cells  [ generate_gc_reset_multi_aasd_constraints $f_out ]
#set n_gc_falsepath_waiver_cells  [ generate_gc_falsepath_waiver_constraints $f_out ]
puts "gencores CDC statistics: "
puts " - gc_sync:             $n_gc_sync_cells instances"
puts " - gc_sync_register:    $n_gc_sync_register_cells instances"
puts " - gc_reset_multi_aasd: $n_gc_reset_multi_aasd_cells instances"
#puts " - gc_falsepath_waiver: $n_gc_falsepath_waiver_cells instances"

close $f_out

