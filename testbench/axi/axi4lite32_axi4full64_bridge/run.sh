#!/bin/bash -e

# SPDX-FileCopyrightText: 2023 CERN (home.cern)
#
# SPDX-License-Identifier: CERN-OHL-W-2.0+

#This is a simple script to run simulations in GHDL

TB=tb_axi4lite32_axi4full64_bridge

if [ -z "$1" ]; then
  TIME="4"
else
  TIME="$1"
fi;

echo "Running simulation for $TB"

ghdl -r --std=08 -frelaxed-rules $TB -gg_seed=$RANDOM -gg_sim_time=$TIME
