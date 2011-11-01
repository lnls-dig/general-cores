onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /main/DUT/U_Intercon/g_num_masters
add wave -noupdate /main/DUT/U_Intercon/g_num_slaves
add wave -noupdate /main/DUT/U_Intercon/g_registered
add wave -noupdate /main/DUT/U_Intercon/clk_sys_i
add wave -noupdate /main/DUT/U_Intercon/rst_n_i
add wave -noupdate /main/DUT/U_Intercon/slave_i
add wave -noupdate /main/DUT/U_Intercon/slave_o
add wave -noupdate /main/DUT/U_Intercon/master_i
add wave -noupdate /main/DUT/U_Intercon/master_o
add wave -noupdate /main/DUT/U_Intercon/cfg_address_i
add wave -noupdate /main/DUT/U_Intercon/cfg_mask_i
add wave -noupdate /main/DUT/U_Intercon/previous
add wave -noupdate /main/DUT/U_Intercon/granted
add wave -noupdate /main/DUT/U_Intercon/issue
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {4093545 ps} 0}
configure wave -namecolwidth 350
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
WaveRestoreZoom {3879920 ps} {4290080 ps}
