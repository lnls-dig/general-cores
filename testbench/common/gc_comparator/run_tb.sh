#!/bin/bash

make

./gc_comparator_tb --wave=gc_comparator_tb.ghw

gtkwave gc_comparator_tb.ghw gc_comparator_tb.gtkwave
