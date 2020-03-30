..
  SPDX-License-Identifier: CC0-1.0

  SPDX-FileCopyrightText: 2019-2020 CERN

==========
Change Log
==========
- Format inspired by: `Keep a Changelog <https://keepachangelog.com/en/1.0.0/>`_
- Versioning scheme follows: `Semantic Versioning <https://semver.org/spec/v2.0.0.html>`_

Unreleased
==========
https://ohwr.org/project/general-cores/compare/master...proposed_master

Fixed
-----
- [hdl] avoid f_log2() circular dependencies in gc_extend_pulse.


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
