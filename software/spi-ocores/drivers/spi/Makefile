# SPDX-License-Identifier: CC0-1.0
#
# Copyright (C) 2019 CERN

TOP_DIR ?= $(shell pwd)/../../../../

-include Makefile.specific
REPO_PARENT ?= $(shell /bin/pwd)/../..
-include $(REPO_PARENT)/parent_common.mk

GCORES ?= $(TOP_DIR)
include $(GCORES)/common.mk

LINUX ?= /lib/modules/$(shell uname -r)/build

all: modules

clean modules help:
	$(MAKE) -C $(LINUX) M=$(shell /bin/pwd) CONFIG_SPI_OCORES=m $@

modules_install:
	$(MAKE) -C $(LINUX) M=$(shell /bin/pwd) INSTALL_MOD_PATH=$(PREFIX) $@

.PHONY: all modules clean help install modules_install
