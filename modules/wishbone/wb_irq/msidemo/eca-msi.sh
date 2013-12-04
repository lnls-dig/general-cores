dev=$1

eca-ctl $dev enable
eca-ctl $dev -c 1 activate
eca-table $dev flush
eca-table $dev add 0xDEADBE00/64 +0 1 0x000
eca-table $dev add 0xDEADBE01/64 +0 1 0x004
eca-table $dev add 0xDEADBE10/64 +0 1 0x100
eca-table $dev add 0xDEADBE11/64 +0 1 0x104
eca-table $dev flip-active

eca-ctl $dev send -s0 0xDEADBE11 +0 0xAB
eb-read $dev 0x2000d08/4
