SRC  = $(wildcard *.svg)
OBJS = $(SRC:.svg=.pdf)

all: $(OBJS)
	echo $(OBJS)

%.pdf : %.svg
	inkscape -f $< -A $@

clean :
	rm -f *.pdf
