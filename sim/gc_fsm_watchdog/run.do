vlib work

vcom -explicit -93 "../../modules/common/gencores_pkg.vhd"
vcom -explicit -93 "../../modules/wishbone/wishbone_pkg.vhd"
vcom -explicit -93 "../../modules/common/gc_fsm_watchdog.vhd"

vcom -explicit -93 "tb_gc_fsm_watchdog.vhd"

vsim -t 1ps -voptargs="+acc" -lib work work.tb_gc_fsm_watchdog

radix -hexadecimal
#add wave *
do wave.do

run 4 ms
wave zoomfull
