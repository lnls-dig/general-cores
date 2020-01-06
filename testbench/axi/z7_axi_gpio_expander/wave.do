onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /sim_top_ps_gpio/clk
add wave -noupdate /sim_top_ps_gpio/rst_n
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/ARVALID
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/AWVALID
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/BREADY
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/RREADY
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/WVALID
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/ARADDR
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/AWADDR
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/WDATA
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/WSTRB
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/ARREADY
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/AWREADY
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/BVALID
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/RVALID
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/WREADY
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/BRESP
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/RRESP
add wave -noupdate -expand -group AXI /sim_top_ps_gpio/RDATA
add wave -noupdate /sim_top_ps_gpio/error_b1
add wave -noupdate /sim_top_ps_gpio/out_b0
add wave -noupdate /sim_top_ps_gpio/out_b1
add wave -noupdate /sim_top_ps_gpio/dir_b0
add wave -noupdate /sim_top_ps_gpio/dir_b1
add wave -noupdate /sim_top_ps_gpio/oen_b0
add wave -noupdate /sim_top_ps_gpio/oen_b1
add wave -noupdate /sim_top_ps_gpio/gpio_out
add wave -noupdate /sim_top_ps_gpio/gpio_oe
add wave -noupdate /sim_top_ps_gpio/gpio_dir
add wave -noupdate /sim_top_ps_gpio/gpio_in
add wave -noupdate /sim_top_ps_gpio/U_EXP/state
add wave -noupdate /sim_top_ps_gpio/U_EXP/gpio_oe_prev
add wave -noupdate /sim_top_ps_gpio/U_EXP/gpio_dir_prev
add wave -noupdate /sim_top_ps_gpio/U_EXP/gpio_out_prev
add wave -noupdate /sim_top_ps_gpio/U_EXP/gpio_oe_changed
add wave -noupdate /sim_top_ps_gpio/U_EXP/gpio_dir_changed
add wave -noupdate /sim_top_ps_gpio/U_EXP/gpio_out_changed
add wave -noupdate /sim_top_ps_gpio/U_EXP/refresh_all
add wave -noupdate /sim_top_ps_gpio/U_EXP/current_bank
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 fs} 0}
quietly wave cursor active 0
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
configure wave -timelineunits fs
update
WaveRestoreZoom {0 fs} {5780 fs}
