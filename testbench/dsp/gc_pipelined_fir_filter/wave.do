onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /main/DUT/clk_i
add wave -noupdate -radix hexadecimal /main/DUT/rst_i
add wave -noupdate -radix hexadecimal /main/DUT/coefs_i
add wave -noupdate -radix hexadecimal /main/DUT/d_i
add wave -noupdate -radix hexadecimal /main/DUT/d_valid_i
add wave -noupdate -radix hexadecimal /main/DUT/d_o
add wave -noupdate -radix hexadecimal /main/DUT/d_valid_o
add wave -noupdate -radix hexadecimal /main/DUT/dly_valid
add wave -noupdate -radix hexadecimal /main/DUT/dly
add wave -noupdate -radix hexadecimal /main/DUT/d_reg
add wave -noupdate -radix hexadecimal -childformat {{/main/DUT/premul(19) -radix hexadecimal} {/main/DUT/premul(18) -radix hexadecimal} {/main/DUT/premul(17) -radix hexadecimal} {/main/DUT/premul(16) -radix hexadecimal} {/main/DUT/premul(15) -radix hexadecimal} {/main/DUT/premul(14) -radix hexadecimal} {/main/DUT/premul(13) -radix hexadecimal} {/main/DUT/premul(12) -radix hexadecimal} {/main/DUT/premul(11) -radix hexadecimal} {/main/DUT/premul(10) -radix hexadecimal} {/main/DUT/premul(9) -radix hexadecimal} {/main/DUT/premul(8) -radix hexadecimal} {/main/DUT/premul(7) -radix hexadecimal} {/main/DUT/premul(6) -radix hexadecimal} {/main/DUT/premul(5) -radix hexadecimal} {/main/DUT/premul(4) -radix hexadecimal} {/main/DUT/premul(3) -radix hexadecimal} {/main/DUT/premul(2) -radix hexadecimal} {/main/DUT/premul(1) -radix hexadecimal} {/main/DUT/premul(0) -radix hexadecimal}} -subitemconfig {/main/DUT/premul(19) {-radix hexadecimal} /main/DUT/premul(18) {-radix hexadecimal} /main/DUT/premul(17) {-radix hexadecimal} /main/DUT/premul(16) {-radix hexadecimal} /main/DUT/premul(15) {-radix hexadecimal} /main/DUT/premul(14) {-radix hexadecimal} /main/DUT/premul(13) {-radix hexadecimal} /main/DUT/premul(12) {-radix hexadecimal} /main/DUT/premul(11) {-radix hexadecimal} /main/DUT/premul(10) {-radix hexadecimal} /main/DUT/premul(9) {-radix hexadecimal} /main/DUT/premul(8) {-radix hexadecimal} /main/DUT/premul(7) {-radix hexadecimal} /main/DUT/premul(6) {-radix hexadecimal} /main/DUT/premul(5) {-radix hexadecimal} /main/DUT/premul(4) {-radix hexadecimal} /main/DUT/premul(3) {-radix hexadecimal} /main/DUT/premul(2) {-radix hexadecimal} /main/DUT/premul(1) {-radix hexadecimal} /main/DUT/premul(0) {-radix hexadecimal}} /main/DUT/premul
add wave -noupdate -radix hexadecimal /main/DUT/premul_valid
add wave -noupdate -radix hexadecimal /main/DUT/premul_reg
add wave -noupdate -radix hexadecimal /main/DUT/postmul
add wave -noupdate -radix hexadecimal /main/DUT/postmul_reg
add wave -noupdate -radix hexadecimal /main/DUT/postmul_reg2
add wave -noupdate -radix hexadecimal /main/DUT/postmul_valid
add wave -noupdate -radix hexadecimal /main/DUT/acc_out_rounded
add wave -noupdate -radix hexadecimal /main/DUT/acc_out_valid
add wave -noupdate -radix hexadecimal /main/DUT/chain_sum
add wave -noupdate -radix hexadecimal /main/DUT/chain_sum_valid
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {219 ps} 0}
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
WaveRestoreZoom {0 ps} {1 ns}
