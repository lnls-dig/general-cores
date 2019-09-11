-include Makefile.specific
# include parent_common.mk for buildsystem's defines
#use absolute path for REPO_PARENT
REPO_PARENT ?= $(shell /bin/pwd)/../..
-include $(REPO_PARENT)/parent_common.mk

all: modules

modules clean:
	make -C $(shell pwd)/drivers/spi $@

.PHONY: all modules clean
