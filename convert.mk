# Makefile for batch-converting RINEXv2 *.26o files to *.srnx
#
# Copy this file into your data directory (as Makefile) and run:
#   make -j8
#
# Or invoke it from anywhere:
#   make -f tools/convert.mk SRNX_DIR=/path/to/data
#
# Override SRNX to point to the rnx2srnx binary if it is not on your PATH:
#   make -j8 SRNX=../+release/bin/rnx2srnx

# Path to the rnx2srnx converter.
# Override on the command line or in your environment.
SRNX ?= rnx2srnx

# Directory containing the source RINEXv2 files.
# Defaults to the current working directory.
SRNX_DIR ?= $(CURDIR)

# Auto-detect year from first .??o file found in SRNX_DIR
YEAR := $(shell ls -1 "$(SRNX_DIR)"/*.??o 2>/dev/null | head -1 | grep -oE '\.([0-9]{2})o' | tr -d '.o')
ifeq ($(YEAR),)
$(error No RINEX files found in $(SRNX_DIR). Please ensure *.??o files exist.)
endif

# Discover all RINEXv2 observation files (*.$(YEAR)o) via wildcard.
SRNX_SOURCES := $(wildcard $(SRNX_DIR)/*.$(YEAR)o)

# Derive the corresponding *.srnx targets.
# e.g.  data/MYSITE00.$(YEAR)o  ->  data/MYSITE00.srnx
SRNX_TARGETS := $(patsubst $(SRNX_DIR)/%.$(YEAR)o,$(SRNX_DIR)/%.srnx,$(SRNX_SOURCES))

# Print summary when make is invoked without a target.
.DEFAULT_GOAL := all

.PHONY: all clean

all: $(SRNX_TARGETS)
	@echo ""
	@echo "Converted $(words $(SRNX_TARGETS)) file(s)."

# Pattern rule: convert one RINEXv2 file to SRNX.
# Each .srnx depends only on its matching .$o, so make -j is safe.
$(SRNX_DIR)/%.srnx: $(SRNX_DIR)/%.$(YEAR)o
	$(SRNX) "$<" "$@"

clean:
	rm -f $(SRNX_TARGETS)
