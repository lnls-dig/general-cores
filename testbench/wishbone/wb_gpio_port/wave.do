onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix decimal /main/DUT/g_num_pins
add wave -noupdate -radix decimal /main/DUT/c_NUM_BANKS
add wave -noupdate -radix hexadecimal /main/DUT/clk_sys_i
add wave -noupdate -radix hexadecimal /main/DUT/rst_n_i
add wave -noupdate -radix hexadecimal /main/DUT/wb_*
add wave -noupdate -radix hexadecimal /main/DUT/gpio_in_i
add wave -noupdate -radix hexadecimal /main/DUT/gpio_out_o
add wave -noupdate -radix hexadecimal /main/DUT/gpio_oen_o
add wave -noupdate -radix hexadecimal /main/DUT/sor_wr
add wave -noupdate -radix hexadecimal /main/DUT/cor_wr
add wave -noupdate -radix hexadecimal /main/DUT/ddr_wr
TreeUpdate [SetDefaultTree]
update
