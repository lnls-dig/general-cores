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

* For clock-domain crossing or asynchronous signal register, use
  [gc_sync_ffs](modules/common/gc_sync_ffs.vhd).  It also has an edge
  detector.
  The other synchronizer [gc_sync_register](modules/common/gc_sync_register.vhd)
  is deprecated.  It can synchronize multiple signals at the same time but
  doesn't ensure coherency between these signals.

  To pass words from one clock domain to another, you can use the module
  [gc_sync_word_wr](modules/common/gc_sync_word_wr.vhd)

  To pass one pulse from one domain to another, use module
  [gc_pulse_synchronizer](modules/common/gc_pulse_synchronizer.vhd)
  or the version with resets
  [gc_pulse_synchronizer2](modules/common/gc_pulse_synchronizer2.vhd)

  Module [gc_async_signals_input_stage](modules/common/gc_async_signals_input_stage.vhd)
  contains a complex handling for asynchronous signals (crossing clock
  domains, deglitcher, edge detection, pulse extension...)

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
