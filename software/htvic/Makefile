# SPDX-License-Identifier: CC0-1.0
#
# SPDX-FileCopyrightText: 2019 CERN

all: modules

install: modules_install
clean modules modules_install:
	@$(MAKE) -C drivers/ $@

gtags:
	git ls-tree -r --name-only HEAD | grep -E '.*\.(c|h)$$' | gtags -f -

.PHONY: modules modules_install clean all gtags
