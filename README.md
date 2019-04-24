# OHWR General cores

General cores is a library of widely used cores but still small enough not to
require a dedicated repository.

In [modules/common](modules/common) there are general purpose cores:

* For clock-domain crossing or asynchronous signal register, use
  [gc_sync_ffs](modules/common/gc_sync_ffs.vhd).  It also has an edge
  detector.
  The other synchronizer [gc_sync_register](modules/common/gc_sync_register.vhd)
  is deprecated.  It can synchronize multiple signals at the same time but
  doesn't ensure coherency between these signals.

* ...
