# SPDX-License-Identifier: CC0-1.0
#
# SPDX-FileCopyrightText: 2019 CERN

.PHONY: all clean modules install modules_install

DIR := drivers/i2c/busses

all: modules
install: modules_install

clean modules modules_install coccicheck:
	@$(MAKE) -C $(DIR) $@
