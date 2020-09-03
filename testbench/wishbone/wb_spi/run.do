vsim -t 1ps -voptargs="+acc" -lib work work.tb_spi

radix -hexadecimal
#add wave *
#do wave.do

run 400ns
#wave zoomfull
