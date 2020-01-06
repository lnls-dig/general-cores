Wishbone
--------

most of the cores available on OHWR are wishbone based.  The official
document describing the bus can be read from ohwr at
https://www.ohwr.org/attachments/179/wbspec_b4.pdf or from
opencores.org at https://cdn.opencores.org/downloads/wbspec_b4.pdf
The previous version (b3) can also be read for historical reasons at
https://cdn.opencores.org/downloads/wbspec_b3.pdf

You can refer to https://zipcpu.com/zipcpu/2017/11/07/wb-formal.html
for some issues about wishbone.

The specifications define several variants of the bus and also several
optional signals.  The purpose of this document is to define which
variants are commonly used and to clarify some ambiguities.


Variants
~~~~~~~~

* Only the standard cycle or the pipelined cycle are supported.  In
  particular, registered feedback bus cycles aren't supported.

* Although RTY is present in the VHDL records that declare types for the
  wishbone bus, it must not be used.

* ERR is also present, but may not be correctly conveyed to the
  original master.  The reason is that the semantic may be different
  from the wishbone semantic (for example, VME allows to report an
  error only on the first cycle of a burst transaction, while wishbone
  allows it on any cycle).

* So the wishbone signals are: RST, CLK, ADR, DATI, DATO, WE, SEL,
  STB, ACK, CYC and STALL.

* Whether the protocol is standard or pipelined wishbone is indicated
  either by the documentation or through a generic.  It would have
  been better to use two different types for the two different
  protocols.


Clarifications for standard cycle
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

* The master is always synchronous for its outputs and always sample
  its inputs synchronously.

* The slave can be synchronous or asynchronous.  Asynchronous slaves
  allow to build very simple slaves.

* Although Rule 3.50 hints that ACK cannot be deasserted before STB is
  deasserted, this is not clearly stated and all waveforms show that
  ACK and STB are deasserted together.  In all waveforms, ACK is
  asserted for only one cycle.

* So a a slave asserts ACK for only one cycle and a master deasserts
  STB once ACK has been asserted.  A transfer is completed when STB,
  CYC and ACK are asserted.


Rationale
~~~~~~~~~

* How long ACK can stay asserted once STB is deasserted?  That's an
  important point.  If ACK is asynchronous, it can be deasserted
  almost immediately.  If ACK is synchronous, it can be deasserted in
  the next cycle.  But if we want to be able to easily insert
  registers, the deassertion can be delayed for more cycles.

* Should master wait for ACK to be deasserted before starting a new
  transaction ?  That depends on the previous answer.  But note this
  has some consequences on the throughoutput: if yes, there will be
  one data transfer every 4 clock edges (set STB, set ACK, clear STB,
  clear ACK), if no one every 3 edges (in the case of a synchronous
  slave: set STB, set ACK, clear STB, and a new transaction can start
  again where ACK is cleared on the first cycle).

Examples
~~~~~~~~

Using wavedrom.

This is a standard cycle.  As often shown in the wishbone specification
(eg illustration 3-2 and 3-3), the stb signal is deasserted at the same
time as ack.

{signal: [
  {name: 'clk', wave: 'p....'},
  {name: 'dat', wave: 'x.=.x'},
  {name: 'stb', wave: '0.1.0'},
  {name: 'cyc', wave: '0.1.0'},
  {},
  {name: 'ack', wave: '0..10'}
]}

If rule 3.50 is closely followed (ACK/ERR/RTY signals are asserted and
negated in response to the assertion and negation of STB), this can
only happen if ACK is combinational.

Assuming a synchronous ACK signal and following closely the rule 3.50,
a transaction would look like:

{signal: [
  {name: 'clk', wave: 'p.....'},
  {name: 'dat', wave: 'x.=.x.'},
  {name: 'stb', wave: '0.1.0.'},
  {name: 'cyc', wave: '0.1.0.'},
  {},
  {name: 'ack', wave: '0..1.0'}
]}

Can a transaction start when the ACK is still asserted ?  The wishbone
specification says in permission 3.35 that the ACK signal can stay asserted.
And if rule 3.55 is followed (master must operate normally when the slave
inteface holds ACK asserted), the master doesn't know the state of ACK in
the next cycle and starting a new transaction would be ambiguous (how to
interpret the ACK? is it still part of the previous transaction or is it an
ack for this transaction?).

This means a transaction would require at least 4 cycles (assertion of CYC+STB,
assertion of ACK, deassertion of CYC+STB, deassertion of ACK).

The rule 3.50 looks badly written, so let's assume ACK can be immediately
negated:

{signal: [
  {name: 'clk', wave: 'p....'},
  {name: 'dat', wave: 'x.=.x'},
  {name: 'stb', wave: '0.1.0'},
  {name: 'cyc', wave: '0.1.0'},
  {},
  {name: 'ack', wave: '0..10'}
]}

As a consequence, a transaction requires at least 3 cycles.  Hence the
clarification about 1 cycle ACK.

Note that if ACK is combinational, a transaction requires at least 2 cycles:

{signal: [
  {name: 'clk', wave: 'p...'},
  {name: 'dat', wave: 'x.=x'},
  {name: 'stb', wave: '0.10'},
  {name: 'cyc', wave: '0.10'},
  {},
  {name: 'ack', wave: '0.10'}
]}

  _
_| |_
  ____      __
_^    v____/  \__[]
 _____ ____
X_____X____

For block read/write, STB has to be deasserted before starting a transfer:

{signal: [
  {name: 'clk', wave: 'p.......'},
  {name: 'dat', wave: 'x.3.x4.x'},
  {name: 'stb', wave: '0.1.01.0'},
  {name: 'cyc', wave: '0.1....0'},
  {},
  {name: 'ack', wave: '0..10.10'}
]}

Considerations beyond the spec
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If we could suppose that the both master and slave knew that the ACK
were asserted for one cycle, we could even have shorter transfers without
deasserting STB:

{signal: [
  {name: 'clk', wave: 'p......'},
  {name: 'dat', wave: 'x.3.4.x'},
  {name: 'stb', wave: '0.1...0'},
  {name: 'cyc', wave: '0.1...0'},
  {},
  {name: 'ack', wave: '0..1010'}
]}

Note that this is not allowed by these clarifications.  We could even go
farther by not requiring ACK to be deasserted:

{signal: [
  {name: 'clk', wave: 'p.....'},
  {name: 'dat', wave: 'x.3.4x'},
  {name: 'stb', wave: '0.1..0'},
  {name: 'cyc', wave: '0.1..0'},
  {},
  {name: 'ack', wave: '0..1.0'}
]}

(Again, this is not allowed by the specifications or the
clarifications).  But this means the slave tries to do forecast.
Compare with just one transfer:

{signal: [
  {name: 'clk', wave: 'p.....'},
  {name: 'dat', wave: 'x.3.x.'},
  {name: 'stb', wave: '0.1.0.'},
  {name: 'cyc', wave: '0.1.0.'},
  {},
  {name: 'ack', wave: '0..1.0'}
]}

In that case, because master/slaves know the ACK is asserted only for one
cycle, it is asserted for two cycles...

Examples of a bus register
~~~~~~~~~~~~~~~~~~~~~~~~~~

This is a waveform with a synchronous slave for a register on bus between
a master and a slave:

{signal: [
  {name: 'clk',  wave: 'p......'},
  {name: 'dat1', wave: 'x.=...x'},
  {name: 'stb1', wave: '0.1...0'},
  {name: 'cyc1', wave: '0.1...0'},
  {name: 'ack1', wave: '0....10'},
  {},
  {name: 'dat2', wave: 'x..=..x'},
  {name: 'stb2', wave: '0..1.0.'},
  {name: 'cyc2', wave: '0..1.0.'},
  {name: 'ack2', wave: '0...10.'}
]}


Same but with an asynchronous slave:

{signal: [
  {name: 'clk',  wave: 'p.....'},
  {name: 'dat1', wave: 'x.=..x'},
  {name: 'stb1', wave: '0.1..0'},
  {name: 'cyc1', wave: '0.1..0'},
  {name: 'ack1', wave: '0...10'},
  {},
  {name: 'dat2', wave: 'x..=.x'},
  {name: 'stb2', wave: '0..10.'},
  {name: 'cyc2', wave: '0..10.'},
  {name: 'ack2', wave: '0..10.'}
]}
