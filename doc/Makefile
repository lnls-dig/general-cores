#
# Makefile for the documentation directory
#
# Copyright 1994,2000,2010,2011   Alessandro Rubini <rubini@linux.it>
#
#################

# There is not basenames here, all *.in are considered input
INPUT = general-cores.in

TEXI = $(INPUT:.in=.texi)
INFO = $(INPUT:.in=.info)
HTML = $(INPUT:.in=.html)
TXT  = $(INPUT:.in=.txt)
PDF  = $(INPUT:.in=.pdf)

ALL    =  $(TXT) $(PDF)

MAKEINFO ?= makeinfo

%.texi: %.in
	@rm -f $@
	sed -f ./infofilter $< > $@
	emacs -batch --no-site-file -l fixinfo $@
	chmod -w $@


#%.info: %.texi
#	$(MAKEINFO) $< -o $@

#%.html: %.texi
#	$(MAKEINFO) --html --no-split -o $@ $<

%.txt: %.texi
	$(MAKEINFO) --no-headers $< > $@

%.pdf: %.texi
	texi2pdf --batch $<

##############################################
.PHONY: all images check terse clean install
.INTERMEDIATE: $(TEXI)

all: images $(ALL)
	$(MAKE) terse
	$(MAKE) -C gc_i2c_slave
	$(MAKE) -C wb_i2c_bridge
	$(MAKE) -C wb_xil_multiboot

images::
	if [ -d images ]; then $(MAKE) -C images || exit 1; fi

check: _err.ps
	gs -sDEVICE=linux -r320x200x16 $<

terse:
	for n in cp fn ky pg toc tp vr aux log; do rm -f *.$$n; done
	rm -f *~

clean: terse
	rm -f $(ALL) $(TEXI)

install:

