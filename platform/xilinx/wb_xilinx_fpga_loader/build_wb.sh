#!/bin/bash

wbgen2 -V xloader_wb.vhd -H record -p xloader_registers_pkg.vhd -K ../../../sim/regs/xloader_regs.vh -s defines -C xloader_regs.h -D wb_xilinx_fpga_loader.html xloader_wb.wb 