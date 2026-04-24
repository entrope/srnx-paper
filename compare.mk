# Makefile for batch-comparing RINEXv2 *.??o files to *.srnx
#
# Copy this file into your data directory (as Makefile) and run:
#   make -j8
#
# Or invoke it from anywhere:
#   make -f tools/compare.mk SRNX_DIR=/path/to/data
#
# Override RNXCMP or SRNX_DIFF to point to those binaries if they are not
# on your path
#   make -j8 RNXCMP=../+release/rnxcmp

# Paths to the rnxcmp and srnx-diff utilities.
RNXCMP ?= rnxcmp
SRNX_DIFF ?= srnx-diff

# Directory containing the source RINEXv2 files.
# Defaults to the current working directory.
SRNX_DIR ?= $(CURDIR)

# Auto-detect year from first .??o file found in SRNX_DIR
YEAR := $(shell ls -1 "$(SRNX_DIR)"/*.??o 2>/dev/null | head -1 | grep -oE '\.([0-9]{2})o' | tr -d '.o')
ifeq ($(YEAR),)
$(error No RINEX files found in $(SRNX_DIR). Please ensure *.??o files exist.)
endif

# Discover all RINEXv2 observation files (*.$(YEAR)o) via wildcard.
RNX_SOURCES := $(wildcard $(SRNX_DIR)/*.$(YEAR)o)

# Derive the corresponding *.srnx targets.
# e.g.  data/MYSITE00.$(YEAR)o  ->  data/MYSITE00.srnx
DIFF_TARGETS := $(patsubst $(SRNX_DIR)/%.$(YEAR)o,$(SRNX_DIR)/%.diff,$(RNX_SOURCES))

# Print summary when make is invoked without a target.
.DEFAULT_GOAL := all

.PHONY: all clean

all: $(DIFF_TARGETS)
	@echo ""
	@echo "Compared $(words $(DIFF_TARGETS)) file(s)."

# Pattern rule: compare RINEXv2 to SRNX.
# Each .diff depends only on its matching .??o and .srnx, so make -j is safe.
$(SRNX_DIR)/%.diff: $(SRNX_DIR)/%.$(YEAR)o $(patsubst %.$(YEAR)o,%.srnx,$(SRNX_DIR)/%.$(YEAR)o)
	$(RNXCMP) $^ > "$@"
	$(SRNX_DIFF) $^ >> "$@"

clean:
	rm -f $(DIFF_TARGETS)
