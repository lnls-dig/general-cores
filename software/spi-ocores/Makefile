# SPDX-License-Identifier: CC0-1.0
#
# SPDX-FileCopyrightText: 2019 CERN

all: modules

install: modules_install
clean modules modules_install:
	make -C $(shell pwd)/drivers/spi $@

.PHONY: modules modules_install clean all
