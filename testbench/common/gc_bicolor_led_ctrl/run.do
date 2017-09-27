vsim -novopt -t 1ps bicolor_led_ctrl_tb
log -r /*

do wave.do

view wave
view transcript

run 100 ms



