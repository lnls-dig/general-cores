# OHWR General cores

General cores is a library of widely used cores but still small enough not to
require a dedicated repository.

In [modules/common](modules/common) there are general purpose cores:

* The package [gencores_pkg](modules/common/gencores_pkg.vhd) provides the
  declarations of the components (this is not required, you can always
  directly instantiate the entities) but also some useful subprograms
  like functions for gray encode/decode, boolean conversions...

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
  round-robin arbiter amount an arbitrary number of requests.
