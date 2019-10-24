vsim -t 10fs work.sim_top_ps_gpio -voptargs="+acc"
set StdArithNoWarnings 1
set NumericStdNoWarnings 1
do wave.do
radix -hexadecimal
run 200ms
wave zoomfull
radix -hexadecimal
