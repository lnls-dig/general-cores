-include Makefile.specific
# include parent_common.mk for buildsystem's defines
#use absolute path for REPO_PARENT
REPO_PARENT ?= $(shell /bin/pwd)/../..
-include $(REPO_PARENT)/parent_common.mk

LINUX ?= /lib/modules/$(shell uname -r)/build
export LINUX=/user/fvaga/workspace/projects/centos/cern-beco-kernel-rt/BUILD/kernel-3.10.0/linux-3.10.0.x86_64

export CONFIG_I2C_OCORES=m

all: modules

modules help install modules_install:
	make -C $(LINUX) M=$(shell pwd)

.PHONY: all modules clean help install modules_install
