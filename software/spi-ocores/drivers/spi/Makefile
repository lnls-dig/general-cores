-include Makefile.specific
# include parent_common.mk for buildsystem's defines
#use absolute path for REPO_PARENT
REPO_PARENT ?= $(shell /bin/pwd)/../..
-include $(REPO_PARENT)/parent_common.mk

LINUX ?= /lib/modules/$(shell uname -r)/build

all: modules

modules help install modules_install:
	make -C $(LINUX) M=$(shell pwd) CONFIG_SPI_OCORES=m

.PHONY: all modules clean help install modules_install
