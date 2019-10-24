# SPDX-License-Identifier: CC0-1.0
#
# Copyright (C) 2019 CERN

DIRS := i2c-ocores
DIRS += spi-ocores
DIRS += htvic

.PHONY: all clean modules install modules_install

all: modules
install: modules_install

clean modules modules_install coccicheck:
	for D in $(DIRS); do $(MAKE) -C $$D $@; done
