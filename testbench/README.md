# Description
The majority of the general cores have their own testbench written in VHDL and as a verification methodology, OSVVM is used. There are also some testbenches which are written in SystemVerilog.

The common features of each test are:
  - Randomization of the input signals
  - FSM coverage (when there are FSM in the RTL design), results are shown at the end of the simulation
  - Assertions are used to verify aspects of the core's functionality, cumply with the specifications

There are two options for the users, in order to run these tests. First is to run them all by using the Makefile in the current directory. This Makefile contains all the VHDL tests. Second option, is to run each test individually.

## Requirements
  - [hdlmake](https://hdlmake.readthedocs.io/en/master/#install-hdlmake-package)
  - [ghdl](https://ghdl.github.io/ghdl/development/building/index.html#build)
  - [OSVVM](https://github.com/OSVVM/OSVVM)  version 2020.05+

## Set up environment
  - Modify the file **/usr/local/lib/ghdl/vendors/config.sh** by adding the OSVVM path (in OSVVM_settings change the Installation Directory)
  - Compile OSVVM:
```console
/usr/local/lib/ghdl/vendors/compile-osvvm --all
```
## How to test
```console
hdlmake makefile
make
./run.sh
```
 Waveform option:
```console
 ./run.sh --wave=waveform.ghw
```

## Maintainer
- [Konstantinos Blantos](mailto:konstantinos.blantos@cern.ch)

