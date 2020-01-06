vlib work

vcom -explicit -93 "../../modules/common/gc_sync_ffs.vhd"
vcom -explicit -93 "../../modules/common/gc_sync_word_wr.vhd"

vcom -explicit -93 "tb_gc_sync_word_wr.vhd"

vsim -t 1ps -voptargs="+acc" -lib work work.tb_gc_sync_word_wr

radix -hexadecimal
#add wave *
do wave.do

run 400ns
wave zoomfull
