# Makefile for the SRNX paper and benchmark pipeline.
#
# Targets:
#   all (default)  Compile the paper: srnx.pdf
#   sizes.dat      Run benchmark pipeline (requires SRNX_DIR=/path/to/rinex)
#   pareto.dat     Compute Pareto front from sizes.dat
#   pareto.pdf     Render the compression/time scatter plot
#   srnx.pdf       Compile the LaTeX paper
#   compare        Compare RINEX vs SRNX fidelity (requires SRNX_DIR)
#   convert        Batch-convert RINEX to SRNX (requires SRNX_DIR)
#   clean          Remove generated files (keeps sizes.dat)
#
# Variables:
#   SRNX_DIR  Directory of input RINEX files (required for sizes.dat, compare, convert)
#   NCPU      Parallel ninja jobs when building sizes.dat (default: 16)

NCPU ?= 16

.SUFFIXES:
.PHONY: all compare convert clean

# SRNX file-structure diagram (railroad DSL → SVG → PDF)
DIAGRAM_DSL  = figures/srnx-file.dsl
DIAGRAM_SVG  = $(DIAGRAM_DSL:.dsl=.svg)
DIAGRAM_PDF  = $(DIAGRAM_DSL:.dsl=.pdf)

all: srnx.pdf

# -- Benchmark data ---------------------------------------------------------

sizes.dat: do-it.pl make-ninja.pl
ifndef SRNX_DIR
	$(error SRNX_DIR must be set to a directory containing RINEX files)
endif
	NCPU=$(NCPU) perl $< $(SRNX_DIR) .

pareto.dat: sizes.dat pareto.pl
	perl pareto.pl --keep < sizes.dat > pareto.dat

# -- Plots and images -------------------------------------------------------

$(DIAGRAM_SVG): $(DIAGRAM_DSL)
	railroad $<

$(DIAGRAM_PDF): $(DIAGRAM_SVG) fix-svg-bg.sh
	sh fix-svg-bg.sh < $< | inkscape --export-background=white --export-filename=$@ -p > $@

pareto.dat: sizes.dat
	perl pareto.pl --keep < $< > $@

figures/pareto.pdf: make-plots.gp pareto.dat 
	gnuplot -e "set terminal pdfcairo enhanced font 'Helvetica,10' size 6in,4in; \
	            set output '$@'" $<

# -- Paper ------------------------------------------------------------------

# First pdflatex pass produces srnx.bcf, which biber needs.
srnx.bcf: srnx.tex $(DIAGRAM_PDF) figures/pareto.pdf
	pdflatex -interaction nonstopmode srnx.tex

# Biber reads srnx.bcf + sample.bib and produces srnx.bbl.
srnx.bbl: srnx.bcf sample.bib
	biber srnx

# Run pdflatex until cross-references stabilise (at most 3 passes).
srnx.pdf: srnx.tex srnx.bbl $(DIAGRAM_PDF)
	@for i in 1 2 3; do \
		pdflatex -interaction nonstopmode srnx.tex || exit 1; \
		grep -qE '(Rerun|undefined|citation)' srnx.log 2>/dev/null || break; \
	done
	@if grep -qE '(Rerun|undefined|citation)' srnx.log 2>/dev/null; then \
		echo "Warning: unresolved references remain; re-run make." >&2; \
	fi

# -- Helpers ----------------------------------------------------------------

compare:
ifndef SRNX_DIR
	$(error SRNX_DIR must be set for comparison)
endif
	$(MAKE) -f compare.mk SRNX_DIR="$(SRNX_DIR)"

convert:
ifndef SRNX_DIR
	$(error SRNX_DIR must be set for conversion)
endif
	$(MAKE) -f convert.mk SRNX_DIR="$(SRNX_DIR)"

clean:
	rm -f srnx.aux srnx.bbl srnx.bcf srnx.blg srnx.log srnx.out srnx.pdf srnx.run.xml
	rm -f build.ninja pareto.dat pareto.pdf
	rm -f $(DIAGRAM_SVG) $(DIAGRAM_PDF)
