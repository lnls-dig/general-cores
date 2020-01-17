# SPDX-License-Identifier: CC0-1.0
#
# SPDX-FileCopyrightText: 2019 CERN

TOPDIR ?= $(shell pwd)/..
include $(TOPDIR)/common.mk

NAME := general-cores
FULL_NAME := $(NAME)-$(VERSION)
DST := /tmp/dkms-source-$(FULL_NAME)

all: dkms_install

# copy necessary source file to build this driver
dkms_sources:
	mkdir -p $(DST)
	find ./ -regextype posix-extended \
	     -regex '.*(Makefile|Kbuild|dkms.conf|/[^.]+\.[ch])' \
	     -exec cp --parents {} $(DST) \;
	cp $(TOPDIR)/LICENSES/GPL-2.0.txt $(DST)


# fix the dkms source file so that the build system is consistent
# with its new location
dkms_sources_prep: dkms_sources
# we do not have git, copy the version
	@find $(DST) -name Makefile -exec \
	      sed -e 's,$$(GIT_VERSION),$(GIT_VERSION),' \
	          -i {} \;
	@sed -r -e "s/@PKGVER@/$(VERSION)/" \
	     -i $(DST)/dkms.conf
# we do not use the common.mk, but we need PREFIX
	@find $(DST) -name Makefile -exec \
	      sed -r -e 's/^include.*common.mk$$/PREFIX ?= \//' \
	          -i {} \;

dkms_install: dkms_sources_prep
	@mkdir -p $(PREFIX)/usr/src/$(FULL_NAME)/
	@cp -a $(DST)/* $(PREFIX)/usr/src/$(FULL_NAME)
