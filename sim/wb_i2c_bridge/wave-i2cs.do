onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_gc_i2c_slave/clk
add wave -noupdate /tb_gc_i2c_slave/state_mst
add wave -noupdate /tb_gc_i2c_slave/state_slv
add wave -noupdate /tb_gc_i2c_slave/scl_to_slv
add wave -noupdate /tb_gc_i2c_slave/sda_to_slv
add wave -noupdate /tb_gc_i2c_slave/sda_fr_slv
add wave -noupdate /tb_gc_i2c_slave/scl_fr_mst
add wave -noupdate /tb_gc_i2c_slave/sda_to_mst
add wave -noupdate /tb_gc_i2c_slave/sda_fr_mst
add wave -noupdate -divider BUS
add wave -noupdate /tb_gc_i2c_slave/scl_to_slv
add wave -noupdate /tb_gc_i2c_slave/scl_fr_slv
add wave -noupdate /tb_gc_i2c_slave/sda_to_slv
add wave -noupdate /tb_gc_i2c_slave/sda_fr_slv
add wave -noupdate /tb_gc_i2c_slave/scl_to_mst
add wave -noupdate /tb_gc_i2c_slave/scl_fr_mst
add wave -noupdate /tb_gc_i2c_slave/sda_to_mst
add wave -noupdate /tb_gc_i2c_slave/sda_fr_mst
add wave -noupdate -divider loopback
add wave -noupdate /tb_gc_i2c_slave/txb
add wave -noupdate /tb_gc_i2c_slave/rxb
add wave -noupdate /tb_gc_i2c_slave/rcvd
add wave -noupdate /tb_gc_i2c_slave/tmp
add wave -noupdate -divider slave
add wave -noupdate /tb_gc_i2c_slave/DUT/scl_i
add wave -noupdate /tb_gc_i2c_slave/DUT/sda_i
add wave -noupdate /tb_gc_i2c_slave/DUT/tick_p
add wave -noupdate /tb_gc_i2c_slave/DUT/tick_en
add wave -noupdate /tb_gc_i2c_slave/DUT/tick_cnt
add wave -noupdate /tb_gc_i2c_slave/DUT/ack_i
add wave -noupdate /tb_gc_i2c_slave/DUT/sda_en_o
add wave -noupdate /tb_gc_i2c_slave/DUT/tx_byte_i
add wave -noupdate /tb_gc_i2c_slave/DUT/rx_byte_o
add wave -noupdate /tb_gc_i2c_slave/DUT/state
add wave -noupdate /tb_gc_i2c_slave/DUT/txsr
add wave -noupdate /tb_gc_i2c_slave/DUT/rxsr
add wave -noupdate /tb_gc_i2c_slave/DUT/bit_cnt
add wave -noupdate /tb_gc_i2c_slave/cnt
add wave -noupdate /tb_gc_i2c_slave/DUT/op_o
add wave -noupdate /tb_gc_i2c_slave/DUT/sta_p_o
add wave -noupdate /tb_gc_i2c_slave/DUT/sto_p_o
add wave -noupdate /tb_gc_i2c_slave/DUT/addr_good_p_o
add wave -noupdate /tb_gc_i2c_slave/DUT/r_done_p_o
add wave -noupdate /tb_gc_i2c_slave/DUT/w_done_p_o
add wave -noupdate /tb_gc_i2c_slave/DUT/op_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2555133080 ps} 0}
configure wave -namecolwidth 400
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {4200 us}
