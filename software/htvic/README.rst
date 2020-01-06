HT Vector Interrupt Controller
==============================
This is the driver for the Vector Interrupt Controller HDL component
developed in BE-CO-HT (CERN).

::

                                      CARRIER
                                      .------------------------------.
                                      |     FPGA                     |
                                      |     .----------------------. |
                                      |     |           .--------. | |
                                      |     |    .------| core-1 | | |
                                      |     |    v      '--------' | |
     .-------------.                  |     | .-----.   .--------. | |
     | motherboard |<-------------------------| vic |<--| core-2 | | |
     '-------------'                  |     | '-----'   '--------' | |
                                      |     |    ^      .--------. | |
                                      |     |    '------| core-N | | |
                                      |     |           '--------' | |
                                      |     '----------------------' |
                                      '------------------------------'


Driver
------
The driver is a platform driver that registers an irq chip for the
correspondent IP core present on the FPGA (the vic). The driver for
the IRQ chip will be connected in cascade to the IRQ controller
assigned to the FPGA carrier by the operating system.

From the electrical point of view, when one of the cores rise an
interrupt line the VIC will keep track of it; the VIC rises
the carrier interrupt line that will, finally, arrive to the
motherboard. This will trigger the operating system, which will
try to handle the interrupt by calling the IRQ handler associated
to the carrier interrupt line. The carrier interrupt line has been
connected directly to the VIC, so the control passes to the VIC
driver which will call the IRQ handler associated to the risen
interrupt line.

The purpose of the VIC driver (IRQ controller) is to configure the VIC
IP core and, dispatch the control to IRQ handlers that belong to it and
to acknowledge the IRQ lines when the interrupt has been handled.

The driver uses the standard Linux interface, this means that any driver
can map an IRQ handler using ``request_irq``. In principle all the Linux IRQ
API should work.

The HTVIC uses the IRQ domain concept, so each HTVIC instance has its own
IRQ domain. Any driver who wants to retrieve the Linux IRQ number
associated to an HTVIC can use the IRQ domain.

::

    irqdomain = irq_find_host((struct device_node *)irqdomain_name);
    linux_irq_number = irq_find_mapping(irqdomain, HW_IRQ_NUMBER);
    request_irq(linux_irq_number, ...);


A non trivial problem can be the detection of the correct domain name.
The source of this information can only be the FPGA carrier, or an user
space process but there is not an unique solution neither a standard one.

All the IRQs handled by the VIC IRQ controller will be visible as any
other IRQ from the operating system. By doing ``cat /proc/interrupts``,
among the other IRQ handlers, you will get the ones belonging to the VIC
IRQ controller. You can identify them because of the prefix "HT-VIC"

::

               CPU0       CPU1
    [...]
    281:          0          0    HT-VIC  fmc-tdc-svec.0
    282:          0          0    HT-VIC  fdelay-tdc-svec.0
    283:          2          0    HT-VIC  mock-turtle-svec.57005
    284:          4          0    HT-VIC  mock-turtle-svec.57005
    313:          0          0    HT-VIC  fmc-tdc-svec.1
    314:          0          0    HT-VIC  fdelay-tdc-svec.1
    315:          2          0    HT-VIC  mock-turtle-svec.48879
    316:          4          0    HT-VIC  mock-turtle-svec.48879
    345:          5          0    HT-VIC  adc-100m-svec.0
    346:          0          0    HT-VIC  adc-100m-svec.1
    [...]

Debug
-----
This driver has a *debugfs* interface. This means that you need the debug
file-system mounted first::

    mount -t debugfs none /sys/kernel/debug

The driver exports two read-only files:

info
   It contains a YAML file with general information about the device instance

reg
   It shows the VIC memory dump
