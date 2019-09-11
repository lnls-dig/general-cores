-include Makefile.specific
# include parent_common.mk for buildsystem's defines
#use absolute path for REPO_PARENT
REPO_PARENT ?= $(shell /bin/pwd)/../..
-include $(REPO_PARENT)/parent_common.mk

LINUX ?= /lib/modules/$(shell uname -r)/build

all: modules

modules: i2c-ocores

clean:
	rm -f *.o *.ko *.mod.o *.mod.c Module.symvers modules.order

i2c-ocores:
	make -C $(LINUX) M=$(shell pwd) CONFIG_I2C_OCORES=m modules

.PHONY: all modules clean
