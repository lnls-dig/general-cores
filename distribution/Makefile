# SPDX-License-Identifier: CC0-1.0
#
# SPDX-FileCopyrightText: 2019 CERN

TOPDIR ?= $(shell pwd)/../
TRTL ?= $(TOPDIR)
include $(TRTL)/common.mk

NAME := general-cores
SPEC_RPM := $(NAME).spec
DEST := rpmbuild

tar-post = \
	$(eval tmpdir := $(shell mktemp -d)) \
	tar --extract -C $(tmpdir)/ -f $(1) \
	    $(2)/common.mk && \
	sed -e "s,^GIT_VERSION.*$$,GIT_VERSION := "$(GIT_VERSION)"," \
	    -e "s,^VERSION.*$$,VERSION := "$(VERSION)"," \
	    -i $(tmpdir)/$(2)/common.mk && \
	tar --update -C $(tmpdir) -f $(1) \
	    $(2)/common.mk && \
	rm -rf $(tmpdir)

all: rpmbuild-all
clean: rpmbuild-clean

include rpmbuild.mk

.PHONY: all clean
