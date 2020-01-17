# SPDX-License-Identifier: CC0-1.0
#
# Copyright (C) 2019 CERN

TOPDIR ?= ../../../
GCORES ?= $(abspath $(TOPDIR))

#
# External variables and targets
#
-include Makefile.specific
-include $(REPO_PARENT)/parent_common.mk
include $(GCORES)/common.mk

#
# Local variables
#
KVERSION ?= $(shell uname -r)
LINUX ?= /lib/modules/$(KVERSION)/build

#
# Local targets
#

all: modules
install: modules_install

clean coccicheck modules:
	$(MAKE) -C $(LINUX) M=$(shell /bin/pwd) \
		GIT_VERSION=$(GIT_VERSION) \
		$@
modules_install: modules
	$(MAKE) -C $(LINUX) M=$(shell /bin/pwd) INSTALL_MOD_PATH=$(PREFIX) $@


.PHONY: all clean coccicheck modules modules_install install
