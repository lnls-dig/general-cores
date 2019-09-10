-include Makefile.specific
# include parent_common.mk for buildsystem's defines
#use absolute path for REPO_PARENT
REPO_PARENT ?= $(shell /bin/pwd)/../..
-include $(REPO_PARENT)/parent_common.mk

all: modules

modules help install modules_install clean:
	export CONFIG_I2C_OCORES=m
	make -C $(shell pwd)/drivers/i2c/busses $@

.PHONY: all modules clean help install modules_install
