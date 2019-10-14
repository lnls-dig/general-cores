-include Makefile.specific
# include parent_common.mk for buildsystem's defines
#use absolute path for REPO_PARENT
REPO_PARENT ?= $(shell /bin/pwd)/../..
-include $(REPO_PARENT)/parent_common.mk

all: modules

install: modules_install
clean modules modules_install:
	make -C $(shell pwd)/drivers/spi $@

.PHONY: modules modules_install clean all
