SRC  = $(wildcard *.svg)
OBJS = $(SRC:.svg=.pdf)

all: $(OBJS)

%.pdf : %.svg
	inkscape -f $< -A $@

clean :
	rm -f *.pdf
