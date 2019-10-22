# SPDX-License-Identifier: CC0-1.0
#
# SPDX-FileCopyrightText: 2019 CERN

# Project
TOP_DIR ?= $(shell pwd)/../
GCORES ?= $(TOP_DIR)
include $(GCORES)/common.mk

# Local
NAME := general-cores
DIR_NAME := $(NAME)-$(VERSION)
BUILD ?= $(abspath build)
SOURCES ?= $(abspath sources)
RPM_SPEC := $(shell mktemp /tmp/$(DIR_NAME)-XXXXXX.spec)

# Tools
GIT ?= git

# Targets
sources-tar:
	@mkdir -p $(SOURCES)
	cd $(GCORES) && $(GIT) archive --format=tar \
	                       --prefix=$(DIR_NAME)/ \
	                       -o $(SOURCES)/$(DIR_NAME).tar \
	                       HEAD:software
	@tar -rf $(SOURCES)/$(DIR_NAME).tar \
	     --transform "s,^,"$(DIR_NAME)"/," \
	     $(GCORES)/LICENSES $(GCORES)/common.mk $(GCORES)/CHANGELOG.rst

sources-tar-gz: sources-tar
	@gzip $(SOURCES)/$(DIR_NAME).tar

sources: sources-tar-gz
	@tar -C $(SOURCES) -xf $(SOURCES)/$(DIR_NAME).tar.gz $(DIR_NAME)/CHANGELOG.rst
	@mv $(SOURCES)/$(DIR_NAME)/CHANGELOG.rst $(SOURCES)/CHANGELOG
	@rmdir $(SOURCES)/$(DIR_NAME)

srpm-changelog: sources
	$(eval $@_pattern := ^\[([0-9]+\.[0-9]+\.[0-9]+)\]\s-\s([0-9]{4}-[0-9]{2}-[0-9]{2})$)
	$(eval $@_replace := echo -e "\n"\\* `date --date="\2" "+%a %b %d %Y"` "\1")
	@sed -r -i -e "/^[.]{2}/d" -e "/^\s{2}.*$$/d" $(SOURCES)/CHANGELOG
	@sed -r -i -e "/Change Log/d" -e "/^(=|-|\s)*$$/d" $(SOURCES)/CHANGELOG
	@sed -r -i -e 's,$($@_pattern),$($@_replace),e' $(SOURCES)/CHANGELOG

rpm-spec: general-cores.spec
# The fmc.spec file is good when we can define variables. With tools like
# koji it is not possible, so we need to create a .spec file without using
# package-specific variables.
	@cp $< $(RPM_SPEC)
	@sed -i -e "s/%{?_build_version}/$(VERSION)/" $(RPM_SPEC)

srpm: sources rpm-spec srpm-changelog
	@mkdir -p $(BUILD)
	@rpmbuild -bs --define "_topdir $(BUILD)" \
		--define '_sourcedir $(SOURCES)' \
		--define "_build_version $(VERSION)" \
		$(RPM_SPEC)
ifeq ($(KEEP_TEMP), n)
	@rm -f $(RPM_SPEC)
endif

clean:
	@rm -rf $(BUILD) $(SOURCES) *.tar.gz $(RPM_SPEC)

.PHONY:  sources-tar sources-tar-gz sources srpm-changelog rpm-spec srpm-changelog srpm
