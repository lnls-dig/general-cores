onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /main/DUT/g_interface_mode
add wave -noupdate /main/DUT/g_address_granularity
add wave -noupdate /main/DUT/clk_sys_i
add wave -noupdate /main/DUT/rst_n_i
add wave -noupdate /main/DUT/wb_cyc_i
add wave -noupdate /main/DUT/wb_stb_i
add wave -noupdate /main/DUT/wb_we_i
add wave -noupdate /main/DUT/wb_adr_i
add wave -noupdate /main/DUT/wb_sel_i
add wave -noupdate /main/DUT/wb_dat_i
add wave -noupdate /main/DUT/wb_dat_o
add wave -noupdate /main/DUT/wb_ack_o
add wave -noupdate /main/DUT/wb_stall_o
add wave -noupdate /main/DUT/xlx_cclk_o
add wave -noupdate /main/DUT/xlx_din_o
add wave -noupdate /main/DUT/xlx_program_b_o
add wave -noupdate /main/DUT/xlx_init_b_i
add wave -noupdate /main/DUT/xlx_done_i
add wave -noupdate /main/DUT/xlx_suspend_o
add wave -noupdate /main/DUT/xlx_m_o
add wave -noupdate /main/DUT/state
add wave -noupdate /main/DUT/clk_div
add wave -noupdate /main/DUT/tick
add wave -noupdate /main/DUT/init_b_synced
add wave -noupdate /main/DUT/done_synced
add wave -noupdate /main/DUT/timeout_counter
add wave -noupdate /main/DUT/wb_in
add wave -noupdate /main/DUT/wb_out
add wave -noupdate /main/DUT/regs_in
add wave -noupdate /main/DUT/regs_out
add wave -noupdate /main/DUT/d_data
add wave -noupdate /main/DUT/d_size
add wave -noupdate /main/DUT/d_last
add wave -noupdate /main/DUT/bit_counter
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {211850000 ps} 0}
configure wave -namecolwidth 226
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
WaveRestoreZoom {0 ps} {3937501184 ps}
