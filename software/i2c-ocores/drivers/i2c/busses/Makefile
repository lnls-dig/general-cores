# SPDX-License-Identifier: CC0-1.0
#
# Copyright (C) 2019 CERN

TOPDIR ?= $(shell pwd)/../../../../../
GCORES ?= $(abspath $(TOPDIR))

#
# External variables and targets
#
include $(GCORES)/common.mk

#
# Local variables
#
KVERSION ?= $(shell uname -r)
KERNELSRC ?= /lib/modules/$(KVERSION)/build

#
# Local targets
#

all: modules
install: modules_install

clean coccicheck modules:
	$(MAKE) -C $(KERNELSRC) M=$(shell /bin/pwd) \
		GIT_VERSION=$(GIT_VERSION) \
		CONFIG_I2C_OCORES=m \
		$@

DESTDIR ?=
prefix ?= /usr/local
includedir ?= $(prefix)/include
INSTALL_MOD_PATH ?= $(DESTDIR)
INSTALL_MOD_DIR ?= extra/general-cores
export INSTALL_MOD_PATH
export INSTALL_MOD_DIR

modules_install: modules
	mkdir -m 0775 -p $(DESTDIR)$(includedir)/linux/platform_data
	$(MAKE) -C $(KERNELSRC) M=$(shell /bin/pwd) $@
	install -D -t $(DESTDIR)$(includedir)/linux/platform_data ../../../include/linux/platform_data/i2c-ocores.h

.PHONY: all clean coccicheck modules modules_install install
