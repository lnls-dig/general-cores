onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_gc_sync_word_wr/din
add wave -noupdate /tb_gc_sync_word_wr/dout
add wave -noupdate /tb_gc_sync_word_wr/clki
add wave -noupdate /tb_gc_sync_word_wr/clko
add wave -noupdate /tb_gc_sync_word_wr/rsti
add wave -noupdate /tb_gc_sync_word_wr/rsto
add wave -noupdate /tb_gc_sync_word_wr/wri
add wave -noupdate /tb_gc_sync_word_wr/wro
add wave -noupdate /tb_gc_sync_word_wr/ack
add wave -noupdate /tb_gc_sync_word_wr/cmp_tb/in_busy
add wave -noupdate /tb_gc_sync_word_wr/cmp_tb/wr_out
add wave -noupdate /tb_gc_sync_word_wr/cmp_tb/last_wr_out
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {90000 ps} 0}
quietly wave cursor active 1
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
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {420 ns}
