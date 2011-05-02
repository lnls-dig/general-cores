#!/bin/bash

mkdir -p doc
wbgen2 -D ./doc/wb_uart.html -V uart_wb_slave.vhd -C ../../../../software/include/hw/wb_uart.h --cstyle defines --lang vhdl -K ../../../sim/wb_uart_defs.v uart.wb 
