-include Makefile.specific
# include parent_common.mk for buildsystem's defines
#use absolute path for REPO_PARENT
REPO_PARENT ?= $(shell /bin/pwd)/../..
-include $(REPO_PARENT)/parent_common.mk

LINUX ?= /lib/modules/$(shell uname -r)/build

all: modules

clean modules help modules_install:
	$(MAKE) -C $(LINUX) M=$(shell /bin/pwd) CONFIG_I2C_OCORES=m $@

.PHONY: all modules clean help install modules_install
