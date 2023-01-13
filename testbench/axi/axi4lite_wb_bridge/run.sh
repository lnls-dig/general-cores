#!/bin/bash -e

#This is a simple script to run simulations in GHDL

TB=tb_xaxi4lite_wb_bridge

if [ -z "$1" ]; then
  TIME="4"
else
  TIME="$1"
fi;

echo "Running simulation for $TB"

ghdl -r --std=08 -frelaxed-rules $TB -gg_seed=$RANDOM -gg_sim_time=$TIME


