# SPDX-FileCopyrightText: 2024 CERN (home.cern)
#
# SPDX-License-Identifier: GPL-2.0-or-later

TOPDIR ?= $(shell /bin/pwd)/../../..

CPPCHECK ?= cppcheck
FLAWFINDER ?= flawfinder
CURDIR := $(shell /bin/pwd)
KVERSION ?= $(shell uname -r)
KERNELSRC ?= /lib/modules/$(KVERSION)/build
WBGEN2 ?= wbgen2

GIT_VERSION := $(shell git describe --always --dirty --long --tags)

all: modules
install: modules_install
modules modules_install: hw_headers

hw_headers: wb_uart.h

wb_uart.h: $(TOPDIR)/modules/wishbone/wb_uart/simple_uart_wb.wb
	$(WBGEN2) -s defines -C $@ $<

clean help modules:
	$(MAKE) -C $(KERNELSRC) M=$(shell pwd) GIT_VERSION=$(GIT_VERSION) $@

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
	install -D -t $(DESTDIR)$(includedir)/linux/platform_data ../include/linux/platform_data/wb_uart_pdata.h

cppcheck:
	$(CPPCHECK) -q -I. --enable=all *.c *.h

flawfinder:
	$(FLAWFINDER) -SQDC .

.PHONY: all modules clean help install modules_install cppcheck flawfinder hw_headers
