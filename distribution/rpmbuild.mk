# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2019 CERN
# Author: Federico Vaga <federico.vaga@cern.ch>


#
# Required Project Variables And Functions
#
ifndef TOPDIR
$(error "Define project top-level directory: TOPDIR")
endif
ifndef NAME
$(error "Define project name: NAME")
endif
ifndef VERSION
$(error "Define project version: VERSION")
endif
ifndef SPEC_RPM
$(error "Define RPM spec file: SPEC_RPM")
endif


#
# Internal Variables
#
FULL_NAME := $(NAME)-$(VERSION)
DEST ?= rpmbuild
RPMBUILD := $(shell /bin/pwd)/$(DEST)
SOURCES := $(RPMBUILD)/SOURCES
SRC_TAR := $(SOURCES)/$(FULL_NAME).tar
SRC_TAR_GZ := $(SOURCES)/$(FULL_NAME).tar.gz
CHANGELOG := $(SOURCES)/CHANGELOG
SPEC := $(RPMBUILD)/SPECS/$(FULL_NAME).spec

#
# Requirements
# - git (if this is a git repository)
#
GIT ?= git
ifeq (,$(shell which $(GIT)))
$(error "The tool 'git' is required to process '$@'")
endif

#
# Targets
#

# Prepare working directories
$(RPMBUILD):
	@mkdir -p $@/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

# Build a tar with all sources with the assumption that sources
# are handled with a git repository. Otherwise, rewrite this rule
# in order to get get a clean tar.
$(SRC_TAR): $(RPMBUILD)
	@cd $(TOPDIR) && \
	 $(GIT) archive --format=tar -o $@ --prefix=$(FULL_NAME)/ HEAD
ifdef tar-post
# Extra processing on the tar file.
# Modify this target according to project needs, if you do not use git-archive
# then do everything right while you are building your tar file
	$(warning "Post processing tar file")
	@$(call tar-post,$@,$(FULL_NAME))
endif

# Compress sources (optional)
$(SRC_TAR_GZ): $(SRC_TAR) $(RPMBUILD)
	@rm -f $@ # remove any previous archive
	@gzip $<

# Create an RPM compatible CHANGELOG from the project format
# (see https://keepachangelog.com/en/1.0.0/)
$(CHANGELOG): $(SRC_TAR_GZ)
	$(eval $@_pattern := ^\[([0-9]+\.[0-9]+\.[0-9]+)\]\s-\s([0-9]{4}-[0-9]{2}-[0-9]{2})$)
	$(eval $@_replace := echo -e "\n"\\* `date --date="\2" "+%a %b %d %Y"` "\1")
	@tar -C $(SOURCES) -xf $< $(FULL_NAME)/CHANGELOG.rst
	@mv $(SOURCES)/$(FULL_NAME)/CHANGELOG.rst $(CHANGELOG)
	@rmdir $(SOURCES)/$(FULL_NAME)
	@sed -r -i -e "1,+10d" -e "/^(=|-|\s)*$$/d" $(CHANGELOG)
	@sed -r -i -e 's,$($@_pattern),$($@_replace),e' $(CHANGELOG)

# Put all necessary sources in the source directory
sources: $(SRC_TAR_GZ) $(CHANGELOG) $(RPMBUILD)

# Build the RPM spec file to embed in the .src.rpm file for a specific version
$(SPEC): $(SPEC_RPM) $(RPMBUILD)
	@cp $< $@
	@sed -i -e "s/%{?_build_version}/$(VERSION)/" $@

# rpmbuild targets
rpmbuild: $(SPEC) sources $(RPMBUILD)

rpmbuild-source: rpmbuild
	@rpmbuild -bs --define "_topdir $(RPMBUILD)" $(SPEC)

rpmbuild-binary: rpmbuild
	@rpmbuild -bb --define "_topdir $(RPMBUILD)" $(SPEC)

rpmbuild-all: rpmbuild
	@rpmbuild -ba --define "_topdir $(RPMBUILD)" $(SPEC)

rpmbuild-clean:
	@rm -rf $(RPMBUILD)

.PHONY: srpm sources $(SRC_TAR_GZ) $(SRC_TAR) $(CHANGELOG) $(SPEC)
