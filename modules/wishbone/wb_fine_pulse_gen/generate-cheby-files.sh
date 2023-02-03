#!/bin/bash

cheby -i fine_pulse_gen_wb.cheby --gen-hdl fine_pulse_gen_wb.vhd
cheby -i fine_pulse_gen_wb.cheby --consts-style sv --gen-consts ../../../sim/regs/fine_pulse_gen_regs.sv
