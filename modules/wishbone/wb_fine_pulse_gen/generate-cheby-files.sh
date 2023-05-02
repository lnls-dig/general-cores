#!/bin/bash

cheby -i wb_fpgen_regs.cheby --gen-hdl wb_fpgen_regs.vhd
cheby -i wb_fpgen_regs.cheby --consts-style sv --gen-consts ../../../sim/regs/wb_fpgen_regs.sv
cheby -i wb_fpgen_regs.cheby --gen-c wb_fpgen_regs.h
cheby -i wb_fpgen_regs.cheby --consts-style h --gen-consts wb_fpgen_regs2.h
