onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /main/DUT/g_num_channels
add wave -noupdate -radix hexadecimal /main/DUT/g_interface_mode
add wave -noupdate -radix hexadecimal /main/DUT/g_address_granularity
add wave -noupdate -radix hexadecimal /main/DUT/clk_sys_i
add wave -noupdate -radix hexadecimal /main/DUT/rst_n_i
add wave -noupdate -radix hexadecimal /main/DUT/wb_adr_i
add wave -noupdate -radix hexadecimal /main/DUT/wb_dat_i
add wave -noupdate -radix hexadecimal /main/DUT/wb_dat_o
add wave -noupdate -radix hexadecimal /main/DUT/wb_cyc_i
add wave -noupdate -radix hexadecimal /main/DUT/wb_sel_i
add wave -noupdate -radix hexadecimal /main/DUT/wb_stb_i
add wave -noupdate -radix hexadecimal /main/DUT/wb_we_i
add wave -noupdate -radix hexadecimal /main/DUT/wb_ack_o
add wave -noupdate -radix hexadecimal /main/DUT/wb_stall_o
add wave -noupdate -radix hexadecimal /main/DUT/pwm_o
add wave -noupdate -radix hexadecimal /main/DUT/drive
add wave -noupdate -radix hexadecimal /main/DUT/regs_in
add wave -noupdate -radix hexadecimal /main/DUT/regs_out
add wave -noupdate -radix hexadecimal /main/DUT/tick
add wave -noupdate -radix hexadecimal /main/DUT/cntr_pre
add wave -noupdate -radix hexadecimal /main/DUT/cntr_main
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1409217 ps} 0}
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
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
WaveRestoreZoom {1409154 ps} {1410045 ps}
