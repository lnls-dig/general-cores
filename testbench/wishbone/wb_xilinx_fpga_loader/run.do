make

vsim work.main -voptargs="+acc"

do wave.do
run 30ms
wave zoomfull
radix -hex