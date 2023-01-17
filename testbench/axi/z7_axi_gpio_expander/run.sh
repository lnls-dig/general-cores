#!/bin/bash -e

# SPDX-FileCopyrightText: 2023 CERN (home.cern)
#
# SPDX-License-Identifier: CERN-OHL-W-2.0+

#This is a simple script to run simulations in GHDL

TB=sim_top_ps_gpio

echo "Running simulation for $TB"

ghdl -r --std=08 -frelaxed-rules $TB --stop-time=2ms
echo "********************************************"
