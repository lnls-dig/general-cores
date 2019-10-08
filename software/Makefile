-include Makefile.specific

# include parent_common.mk for buildsystem's defines
#use absolute path for REPO_PARENT
REPO_PARENT ?= $(shell /bin/pwd)/..
-include $(REPO_PARENT)/parent_common.mk

DIRS := i2c-ocores
DIRS += spi-ocores
DIRS += htvic

.PHONY: all clean modules install modules_install $(DIRS)

all clean: $(DIRS)

clean:
	$(MAKE)
clean: TARGET = clean
modules: TARGET = modules
install: TARGET = install
modules_install: TARGET = modules_install

$(DIRS):
	$(MAKE) -C $@ $(TARGET)
