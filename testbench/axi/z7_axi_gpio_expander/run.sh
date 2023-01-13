#!/bin/bash -e

#This is a simple script to run simulations in GHDL

TB=sim_top_ps_gpio

echo "Running simulation for $TB"

ghdl -r --std=08 -frelaxed-rules $TB 
echo "********************************************"
