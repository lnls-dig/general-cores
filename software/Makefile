-include Makefile.specific

# include parent_common.mk for buildsystem's defines
#use absolute path for REPO_PARENT
REPO_PARENT ?= $(shell /bin/pwd)/..
-include $(REPO_PARENT)/parent_common.mk

DIRS := i2c-ocores
DIRS += spi-ocores
DIRS += htvic

.PHONY: all clean modules install modules_install

all clean modules install modules_install:
	for D in $(DIRS); do $(MAKE) -C $$D $@; done
