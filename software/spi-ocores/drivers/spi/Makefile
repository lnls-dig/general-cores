# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 CERN

-include Makefile.specific
REPO_PARENT ?= $(shell /bin/pwd)/../..
-include $(REPO_PARENT)/parent_common.mk

LINUX ?= /lib/modules/$(shell uname -r)/build

all: modules

clean modules help modules_install:
	$(MAKE) -C $(LINUX) M=$(shell /bin/pwd) CONFIG_SPI_OCORES=m $@

.PHONY: all modules clean help install modules_install
