..
  SPDX-License-Identifier: CC0-1.0

  SPDX-FileCopyrightText: 2019-2020 CERN

==========
Change Log
==========
- Format inspired by: `Keep a Changelog <https://keepachangelog.com/en/1.0.0/>`_
- Versioning scheme follows: `Semantic Versioning <https://semver.org/spec/v2.0.0.html>`_

1.1.3 - 2021-08-23
==================
https://www.ohwr.org/project/general-cores/tags/v1.1.2

Fixed
-----
- sw: kernel crash of htvic removal on modern kernel

1.1.2 - 2021-07-29
==================
https://www.ohwr.org/project/general-cores/tags/v1.1.2

Fixed
-----
- sw: improve compatibility with newer (> 3.10) Linux kernel versions

1.1.1 - 2020-09-14
==================
https://www.ohwr.org/project/general-cores/tags/v1.1.1

Fixed
-----
- sw: fix SPI driver to update the spi_message->actual_length

1.1.0 - 2020-07-24
==================
https://www.ohwr.org/project/general-cores/tags/v1.1.0

Added
-----
- hdl: New indirect wishbone master (driven by an address and data register).
- hdl: New memory wrapper for Cheby.
- hdl: Provide a simple vhdl package to generate WB transactions.
- hdl: New wb_xc7_fw_update module.
- bld: Introduce gen_sourceid.py script to generate a package with the source id.

Changed
-------
- bld: gen_buildinfo.py now adds tag and dirty flag.

Fixed
-----
- hdl: regression to gc_sync_ffs introduced by v1.0.4.
- hdl: add dummy generic to generic_dpram in altera.
- hdl: add missing generics to generic_sync_fifo in genram_pkg.
- hdl: avoid f_log2() circular dependencies in gc_extend_pulse.


1.0.4 - 2020-03-26
==================
https://www.ohwr.org/project/general-cores/tags/v1.0.4

Added
-----
- [hdl] VHDL functions to convert characters and strings to upper/lower case.
- [sw][i2c] Support for kernel greater than 4.7.
- [hdl] Separate synchroniser and edge detection modules.
- [hdl] 8b10b encoder.

Changed
-------
- [hdl] Rewritten the WB master interface used in simulations.
- [hdl] Reimplement gc_sync_ffs using new synchroniser and edge detectors.

Fixed
-----
- [sw][spi] Align polarity and phase for Rx and Tx.
- [hdl][i2c] Fix reset lock for I2C master.
- [hdl] Avoid cyclic dependencies for log2 ceiling functions.

1.0.3 - 2020-01-15
==================
https://www.ohwr.org/project/general-cores/tags/v1.0.3

Changed
-----
- [sw] add more file to .gitignore

1.0.2 - 2019-10-24
==================
https://www.ohwr.org/project/general-cores/tags/v1.0.2

Fixed
-----
- [ci] forgot rule to publish RPMs

1.0.1 - 2019-10-24
==================
https://www.ohwr.org/project/general-cores/tags/v1.0.1

Added
-----
- [ci] building and publish RPMs automatically on new releases

Changed
-------
- [sw] Makefiles have been changed to better support RPM generation

1.0.0 - 2019-10-21
==================
https://www.ohwr.org/project/general-cores/tags/v1.0.0

Added
-----
- First release of general-cores.
