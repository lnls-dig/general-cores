vlib work

vcom -explicit -93 "../../modules/genrams/genram_pkg.vhd"
vcom -explicit -93 "../../modules/common/gencores_pkg.vhd"
vcom -explicit -93 "../../modules/wishbone/wishbone_pkg.vhd"
vcom -explicit -93 "../../modules/common/gc_sync_ffs.vhd"
vcom -explicit -93 "../../modules/common/gc_glitch_filt.vhd"
vcom -explicit -93 "../../modules/common/gc_fsm_watchdog.vhd"
vcom -explicit -93 "../../modules/common/gc_i2c_slave.vhd"

vcom -explicit -93 "../../modules/wishbone/wb_i2c_bridge/wb_i2c_bridge.vhd"

vcom -explicit -93 "i2c_master_bit_ctrl.vhd"
vcom -explicit -93 "i2c_master_byte_ctrl.vhd"

vcom -explicit -93 "i2c_bus_model.vhd"

vcom -explicit -93 "tb_wb_i2c_bridge.vhd"
#vcom -explicit -93 "tb_gc_i2c_slave.vhd"

vsim -t 1ps -voptargs="+acc" -lib work work.tb_wb_i2c_bridge

radix -hexadecimal
#add wave *
do wave.do
#do busmdl.do
#do wave-i2cs.do

run 20 ms
wave zoomfull
