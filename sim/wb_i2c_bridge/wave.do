onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_wb_i2c_bridge/clk
add wave -noupdate /tb_wb_i2c_bridge/scl
add wave -noupdate /tb_wb_i2c_bridge/sscl
add wave -noupdate /tb_wb_i2c_bridge/sda
add wave -noupdate -expand /tb_wb_i2c_bridge/ssda
add wave -noupdate /tb_wb_i2c_bridge/state
add wave -noupdate /tb_wb_i2c_bridge/stim_cnt
add wave -noupdate /tb_wb_i2c_bridge/send
add wave -noupdate -expand /tb_wb_i2c_bridge/reg
add wave -noupdate -expand /tb_wb_i2c_bridge/reg_1
add wave -noupdate /tb_wb_i2c_bridge/rcvd
add wave -noupdate /tb_wb_i2c_bridge/DUT/cmp_i2c_slave/state
add wave -noupdate /tb_wb_i2c_bridge/DUT_1/cmp_i2c_slave/state
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 2} {728700000 ps} 0}
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
WaveRestoreZoom {0 ps} {1640625 ns}
