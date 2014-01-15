onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_gc_fsm_watchdog/clk
add wave -noupdate /tb_gc_fsm_watchdog/rst_n
add wave -noupdate /tb_gc_fsm_watchdog/wdt_rst
add wave -noupdate /tb_gc_fsm_watchdog/rst_from_wdt
add wave -noupdate /tb_gc_fsm_watchdog/state
add wave -noupdate /tb_gc_fsm_watchdog/cnt
add wave -noupdate /tb_gc_fsm_watchdog/cnt_tick_p
add wave -noupdate -divider watchdog
add wave -noupdate /tb_gc_fsm_watchdog/DUT/wdt_rst_i
add wave -noupdate /tb_gc_fsm_watchdog/DUT/fsm_rst_o
add wave -noupdate /tb_gc_fsm_watchdog/DUT/wdt
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {834632588 ps} 0}
configure wave -namecolwidth 280
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
WaveRestoreZoom {0 ps} {3851118211 ps}
