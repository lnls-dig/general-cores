FILE=gc_i2c_slave

all:
	$(MAKE) -C fig
	pdflatex -synctex=1 -interaction=nonstopmode $(FILE).tex *.tex
	bibtex $(FILE).aux
	pdflatex -synctex=1 -interaction=nonstopmode $(FILE).tex *.tex
	pdflatex -synctex=1 -interaction=nonstopmode $(FILE).tex *.tex
	evince $(FILE).pdf &

clean:
	$(MAKE) -C fig clean
	rm -rf *.aux *.dvi *.log $(FILE).pdf *.lof *.lot *.out *.toc *.bbl *.blg *.gz

