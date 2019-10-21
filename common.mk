PREFIX ?= /

GIT_VERSION := $(shell git describe --always --dirty --long --tags)
VERSION := $(shell git describe --tags --abbrev=0 | tr -d 'v')

GCORES_SW := $(GCORES)/software
