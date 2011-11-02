onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /main/clk_sys
add wave -noupdate /main/DUT/U_CPU/dwb_o
add wave -noupdate /main/DUT/U_CPU/dwb_i
add wave -noupdate /main/DUT/U_Intercon/granted
add wave -noupdate /main/DUT/U_CPU/gen_profile_medium/U_Wrapped_LM32/D_STB_O
add wave -noupdate /main/DUT/U_CPU/gen_profile_medium/U_Wrapped_LM32/D_ACK_I
add wave -noupdate /main/DUT/U_CPU/data_was_busy
add wave -noupdate /main/DUT/U_CPU/data_addr_reg
add wave -noupdate /main/DUT/U_CPU/data_remaining
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2672526 ps} 0}
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
WaveRestoreZoom {2262366 ps} {3082686 ps}
