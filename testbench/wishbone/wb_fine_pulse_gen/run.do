#vlog -sv main.sv +incdir+. +incdir+../../include/wb +incdir+../include/vme64x_bfm +incdir+../../include +incdir+../include +incdir+../../sim
set StdArithNoWarnings 1
set NumericStdNoWarnings 1

vsim -modelsimini /home/twl/eda/modelsim-lib-2016.4/modelsim.ini -L unisim -L secureip -L XilinxCoreLib  work.main work.glbl -voptargs=+acc -t 10fs

set StdArithNoWarnings 1
set NumericStdNoWarnings 1

do wave.do
radix -hexadecimal
run 15us
wave zoomfull