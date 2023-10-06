# OHWR General cores

General cores is a library of widely used cores but still small enough not to
require a dedicated repository.

In [modules/common](modules/common) there are general purpose cores:

* The package [gencores_pkg](modules/common/gencores_pkg.vhd) provides the
  declarations of the components (this is not required, you can always
  directly instantiate the entities) but also some useful subprograms
  like functions for gray encode/decode, boolean conversions...

* The package [matrix_pkg](modules/common/matrix_pkg.vhd) declares a 2d
  array of std_logic, and some subprograms to handle it.

* Edge detectors are provided by [gc_posedge](modules/common/gc_posedge.vhd),
  [gc_negedge](modules/common/gc_negedge.vhd), and
  [gc_edge_detect](modules/common/gc_edge_detect.vhd).

* For clock-domain crossing or asynchronous signal register, use
  [gc_sync](modules/common/gc_sync.vhd).  This is the basic synchronizer.
  If you also need an edge detector, use
  [gc_sync_ffs](modules/common/gc_sync_ffs.vhd).
  The other synchronizer [gc_sync_register](modules/common/gc_sync_register.vhd)
  is deprecated.  It can synchronize multiple signals at the same time but
  doesn't ensure coherency between these signals.

  The module [gc_sync_edge](modules/common/gc_sync_edge.vhd) provides a
  synchronizer with an (positive or negative) edge detector.  The signal
  edge is always detected on the rising edge of the clock.  This module is
  simpler than the gc_sync_ffs module.

  To pass words from one clock domain to another, you can use the module
  [gc_sync_word_wr](modules/common/gc_sync_word_wr.vhd) for writing data,
  and [gc_sync_word_rd](modules/common/gc_sync_word_rd.vhd) for reading
  data.

  To pass one pulse from one domain to another, use module
  [gc_pulse_synchronizer](modules/common/gc_pulse_synchronizer.vhd)
  or the version with resets
  [gc_pulse_synchronizer2](modules/common/gc_pulse_synchronizer2.vhd)

  Module [gc_async_signals_input_stage](modules/common/gc_async_signals_input_stage.vhd)
  contains a complex handling for asynchronous signals (crossing clock
  domains, deglitcher, edge detection, pulse extension...)

  * CDC modules come also with specific timing contraints in [modules/common/xdc](modules/common/xdc).
    These constraints can be used in Vivado projects (so-called "module-bound" constraints)
    to automatically derive proper timing constraints for CDC paths in each module.
    To use it, add specific constraint file to your project and set `SCOPED_TO_REF`
    property in GUI or your TCL file.  
    (e.g. add `gc_sync.xdc` if you use `gc_sync.vhd` and set `SCOPED_TO_REF=gc_sync`)

* For reset generation, you can use [gc_reset](modules/common/gc_reset.vhd)
  which generate synchronous resets once all the PLL lock signals are set.
  The module [gc_reset_multi_aasd](modules/common/gc_reset_multi_aasd.vhd)
  generate asynchronously asserted synchronously deasserted resets for
  multiple clock domains.

  The module [gc_single_reset_gen](modules/common/gc_single_reset_gen.vhd)
  is convenient to generate a single reset from multiple sources (like
  powerup signal and a reset button).

* Words can be packed or unpacked using the module
  [gc_word_packer](modules/common/gc_word_packer.vhd)

* Module [gc_i2c_slave](modules/common/gc_i2c_slave.vhd) provides a simple
  i2c slave.  This module is used in
  [gc_sfp_i2c_adapter](modules/common/gc_sfp_i2c_adapter.vhd) to emulate an
  SFP DDM.

* The module [gc_serial_dac](modules/common/gc_serial_dac.vhd) provides an
  interface to a serial DAC.

* The module [gc_rr_arbiter](modules/common/gc_rr_arbiter.vhd) provides a
  round-robin arbiter amount an arbitrary number of requests.  Similarly
  [gc_arbitrated_mux](modules/common/gc_arbitrated_mux.vhd) provides
  a multiple channel tim-division multiplexr with round robin
  arbitration.

* The module [gc_prio_encoder](modules/common/gc_prio_encoder.vhd) provides
  a combinational priority encoder.

* Module [gc_bicolor_led_ctrl](modules/common/gc_bicolor_led_ctrl.vhd)
  controls multiple bicolor leds, including the intensity.

* Module [gc_big_adder](modules/common/gc_big_adder.vhd) provides a pipelined
  adder for wide numbers.

* Module [gc_comparator](modules/common/gc_comparator.vhd) provides a
  comparator with hysteresis.

* Module [gc_moving_average](modules/common/gc_moving_average.vhd) compute the
  average of values over a sliding window.  The size of the window is a power
  of 2.

* Module [gc_crc_gen](modules/common/gc_crc_gen.vhd) provides a generic
  parallel implementation of crc generator or checker.

* Module [gc_dec_8b10b](modules/common/gc_dec_8b10b.vhd) is an 8-bit to
  10-bit decoder.

* Module [gc_delay_gen](modules/common/gc_delay_gen.vhd) is a delay line based
  on a pipeline, while module [gc_delay_line](modules/common/gc_delay_line.vhd)
  implementation is based on a dual port RAM and provides a valid signal.

* Module [gc_ds182x_readout](modules/common/gc_ds182x_readout.vhd) provides
  a one-wire interface for temperature and unique id DS182X chips.  It replaces
  the deprecated [gc_ds182x_interface](modules/common/gc_ds182x_interface.vhd)

* Module [gc_dual_pi_controller](modules/common/gc_dual_pi_controller.vhd) is
  a two channels, proportional integral (PI) controller.

* To extend a pulse, several modules are provided:
  - [gc_dyn_extend_pulse](modules/common/gc_dyn_extend_pulse.vhd) has an input
    for the length.
  - [gc_extend_pulse](modules/common/gc_extend_pulse.vhd) has a fixed length.

* To deglitch a signal:
  - [gc_dyn_glitch_filt](modules/common/gc_dyn_glitch_filt.vhd) accepts
    the minimum length as an input.
  - [gc_glitch_filt](modules/common/gc_glitch_filt.vhd) is static: the
    length is provided as a parameter.

* Module [gc_fsm_watchdog](modules/common/gc_fsm_watchdog.vhd) provides a
  simple watchdog.

* To mesure a frequency:
  - [gc_frequency_meter](modules/common/gc_frequency_meter.vhd) provides a
    single channel counter.
  - [gc_multichannel_frequency_meter](modules/common/gc_multichannel_frequency_meter.vhd) is an optimized version for multiple channels.


In [modules/genrams](modules/genrams) there are fifo and ram cores:

The convention is to use generic_xxx modules whose implementation may depend
on the target.

* The package [genram_pkg](modules/genrams/genram_pkg.vhd) declares ram types,
  utility functions and the components.

* The package [memory_loader_pkg](modules/genrams/memory_loader_pkg.vhd)
  declares functions that reads data from a file.  They are useful to
  initialize the rams (and can be used for synthesis).

* The module generic_spram available for
  [altera](modules/genrams/altera/generic_spram.vhd) and for
  [xilinx](modules/genrams/xilinx/generic_spram.vhd) is a simple port synchronous
  ram.

* The module generic_simple_dpram available for
  [altera](modules/genrams/altera/generic_simple_dpram.vhd) and for
  [xilinx](modules/genrams/xilinx/generic_simple_dpram.vhd) is a dual port,
  dual clock, synchronous ram.  The port A is write-only, the port B is
  read-only.

* The module generic_dpram available for
  [altera](modules/genrams/altera/generic_dpram.vhd) and for
  [xilinx](modules/genrams/xilinx/generic_dpram.vhd) is a dual port,
  dual clock, synchronous ram.  Both ports are read/write.

* The module generic_dpram_mixed available for
  [altera](modules/genrams/altera/generic_dpram_mixed.vhd) is a dual port,
  dual clock, synchronous ram.  Both ports are read/write, and the size of
  the ports can be different.

* The module [generic_sync_fifo](modules/genrams/generic/generic_sync_fifo.vhd)
  is a synchronous fifo, with multiple flags available.

* The module [generic_async_fifo](modules/genrams/generic/generic_async_fifo.vhd)
  is also a fifo with multiple flags available, but with different clocks for
  inputs and outputs.

* The module [generic_async_fifo_dual_rst](modules/genrams/generic/generic_async_fifo_dual_rst.vhd)
  is also a fifo with multiple flags available, but with different clocks for
  inputs and outputs and with a reset input for each clock domain.

* The module [generic_shiftreg_fifo](modules/genrams/common/generic_shiftreg_fifo.vhd)
  is a synchronous fifo based on shift registers.

Directory [modules/wishbone](modules/wishbone) contains modules for wishbone.

* The package [wishbone_pkg](modules/wishbone/wishbone_pkg.vhd) declare
  the records for the wishbone bus and some utilities.

* There are several peripherals:
  - [wb_dma](modules/wishbone/wb_dma) is a dma controller.
  - [wb_dpram](modules/wishbone/wb_dpram) is a dual port ram controlled by two
    wishbone buses.
  - [wb_gpio_port](modules/wishbone/wb_gpio_port) is a gpio controller.
  - [wb_i2c_bridge](modules/wishbone/wb_i2c_bridge) is an i2c slave to
    wishbone master.
  - [wb_i2c_master]](modules/wishbone/wb_i2c_master) is an i2c master.
  - [wb_irq](modules/wishbone/wb_irq) contains irq controllers and generators.
  - [wb_onewire_master](modules/wishbone/wb_onewire_master) is a onewire master.
  - [wb_serial_lcd](modules/wishbone/wb_serial_lcd) is an lcd controller.
  - [wb_simple_pwm](modules/wishbone/wb_simple_pwm) is a pwm controller supporting
    up to 8 channels.
  - [wb_simple_timer](modules/wishbone/wb_simple_timer) is a simple counter.
  - [wb_spi](modules/wishbone/wb_spi) is an spi controller
  - [wb_spi_flash](modules/wishbone/wb_spi_flash) is an spi flash controller
  - [wb_uart](modules/wishbone/wb_uart) is an uart.
  - [wb_vic](modules/wishbone/wb_vic) is the vectored interrupt controller.
  - [wb_ds182x_readout](modules/wishbone/wb_ds182x_readout) is a direct
    interface to the digital thermometer.
  - [wb_xc7_fw_update](modules/wishbone/wb_xc7_fw_update) is an SPI interface
    to drive the xc7 bitstream spi flash (using the ht-flash tool).
  - [wb_clock_monitor](modules/wishbone/wb_clock_monitor) is clock frequency
    measurement/monitoring core with a programmable number of channels.
  - [wb_lm32_mcs](modules/wishbone/wb_lm32_mcs) is a single-entity microcontroller
    based on the LM32 softcore, featuring internal code/data RAM, UART, timer and
    a pipelined Wishbone peripheral interface.

* There are utilities to handle a wishbone bus:
  - [wb_clock_crossing](modules/wishbone/wb_clock_crossing) handle clock domain
    crossing.
  - [wb_register](modules/wishbone/wb_register) adds a pipeline register.
  - [wb_skidpad2](modules/wishbone/wb_register) adds a pipeline register to
    a pipelined wishbone bus (in one direction only) without downgrading
    the throughput.

* There are modules to convert to a different bus
  - [wb_async_bridge](modules/wishbone/wb_async_bridge) is a bridge with the
    AT91SAM9x CPU external bus interface.
  - [wb_axi4lite_bridge](modules/wishbone/wb_axi4lite_bridge) is an axi4lite
    to wishbone bridge
  - [wb16_to_wb32](modules/wishbone/wb16_to_wb32) is an adapter from a
    16 data bit wishbone master to a 32 data bit wishbone slave.  It uses
    an intermediate register.  Refer to the module for how to use it.

* There are modules for axi4 bus
  - [axi4lite32_axi4full64_bridge](modules/axi/axi4lite32_axi4full64_bridge) is
    a bridge from axi4full64 to axi4lite32.  It was defined to interface with
    the Vivado PCI-e bridge and doesn't support all the axi4full features
    (in particular the burst accesses).
  - [mpsoc_int_gen](modules/axi/mpsoc_int_gen) is a module that generates a
    PCIe interrupt when a signal goes high (by writting a specific register
    in the PS).

* There a modules to build a bus hierarchy:
  - [wb_bus_fanout](modules/wishbone/wb_bus_fanout) is a simple master to
    multiple slave decoder.
  - [wb_crossbar](modules/wishbone/wb_crossbar) is a generic multiple masters
    and multiple slaves crossbar.
  - [wb_split](modules/wishbone/wb_split) is a very simple crossbar for 1
    master and 2 slaves.
  - [wb_remapper](modules/wishbone/wb_remapper) allows to remap addresses.
  - [wb_conmax](modules/wishbone/wb_conmax) is an interconnect matrix,
    superseeded by the crossbar.
  - [wb_metadata](modules/wishbone/wb_metadata) is a little helper to
    create metadata for the convention.
  - [wb_indirect](modules/wishbone/wb_indirect) provides a wishbone
    master driven by an address and a data registers.
