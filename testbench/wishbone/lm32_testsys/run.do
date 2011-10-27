make

vsim -L XilinxCoreLib -L secureip work.main -voptargs="+acc"
radix -hexadecimal
do wave.do
set StdArithNoWarnings 1
set NumericStdNoWarnings 1

run 100us
wave zoomfull