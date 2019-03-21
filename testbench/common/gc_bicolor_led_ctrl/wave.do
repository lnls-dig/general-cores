onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /bicolor_led_ctrl_tb/uut/rst_n_i
add wave -noupdate /bicolor_led_ctrl_tb/uut/clk_i
add wave -noupdate /bicolor_led_ctrl_tb/uut/led_state_i
add wave -noupdate -radix unsigned /bicolor_led_ctrl_tb/uut/led_intensity_i
add wave -noupdate /bicolor_led_ctrl_tb/uut/line_o(0)
add wave -noupdate /bicolor_led_ctrl_tb/uut/line_oen_o(0)
add wave -noupdate /bicolor_led_ctrl_tb/uut/line_o(1)
add wave -noupdate /bicolor_led_ctrl_tb/uut/line_oen_o(1)
add wave -noupdate /bicolor_led_ctrl_tb/uut/column_o(3)
add wave -noupdate /bicolor_led_ctrl_tb/uut/column_o(2)
add wave -noupdate /bicolor_led_ctrl_tb/uut/column_o(1)
add wave -noupdate /bicolor_led_ctrl_tb/uut/column_o(0)
add wave -noupdate -divider internals
add wave -noupdate -radix unsigned /bicolor_led_ctrl_tb/uut/refresh_rate_cnt
add wave -noupdate /bicolor_led_ctrl_tb/uut/refresh_rate
add wave -noupdate /bicolor_led_ctrl_tb/uut/line_oen_cnt
add wave -noupdate /bicolor_led_ctrl_tb/uut/line_oen
add wave -noupdate /bicolor_led_ctrl_tb/uut/line_ctrl
add wave -noupdate -radix unsigned /bicolor_led_ctrl_tb/uut/intensity_ctrl_cnt
add wave -noupdate /bicolor_led_ctrl_tb/uut/intensity_ctrl
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {281251037500 ps} 0}
configure wave -namecolwidth 295
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
configure wave -timelineunits ps
update
WaveRestoreZoom {279730374924 ps} {301066822373 ps}
