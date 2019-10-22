# SPDX-License-Identifier: CC0-1.0
#
# Copyright (C) 2019 CERN

TOP_DIR ?= $(shell pwd)/..

-include Makefile.specific

# include parent_common.mk for buildsystem's defines
#use absolute path for REPO_PARENT
REPO_PARENT ?= $(shell /bin/pwd)/..
-include $(REPO_PARENT)/parent_common.mk

GCORES ?= $(TOP_DIR)
include $(GCORES)/common.mk
DIR_NAME := general-cores-$(VERSION)
DST := $(PREFIX)/usr/src/$(DIR_NAME)/

DIRS := i2c-ocores
DIRS += spi-ocores
DIRS += htvic

GIT ?= git
ifeq (,$(shell which $(GIT)))
$(error "Missing git")
endif

.PHONY: all clean modules install modules_install dkms_install

all clean modules install modules_install:
	for D in $(DIRS); do $(MAKE) -C $$D $@; done

dkms_install:
	$(eval $@_dst := $(shell mktemp -d))
	@mkdir -p $($@_dst)
	@mkdir -p $(DST)
ifdef RPMBUILD
# We already did the file selection when producing the tar.gz
# Just copy
	@cp -a $(GCORES)/* $(DST)
else
	@$(GIT) archive --format=tar -o $($@_dst)/$(DIR_NAME).tar --prefix=$(DIR_NAME)/ HEAD
	@cd $($@_dst) && tar -xf $(DIR_NAME).tar
	@mv $($@_dst)/$(DIR_NAME)/* $(DST) && rm -rf $($@_dst)
	@cp $(GCORES)/common.mk $(DST)
endif
	@sed -e '2,$$d' -i $(DST)/common.mk
	@sed -r -i -e "s/@PKGVER@/$(VERSION)/" $(DST)/dkms.conf
	@sed -e "15d" -e "6,13d" -e "23,26d" -e '33,$$d' \
	     -i $(DST)/Makefile
	@find $(DST) -name Makefile -exec \
	      sed -r -e "s,^(TOP_DIR.*)[.]{2}/?$$,\1," -i {} \;
