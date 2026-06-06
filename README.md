# A Space- and Time-Efficient RINEX Representation

## Overview

This repository has the paper and supporting scripts to describe the
Succinct RINEX format.
It goes along with the [reference implementation](https://github.com/entrope/srnx/)
and the [Rust clean-room implementation](https://github.com/entrope/srnx-clean/).

## Contents

`compare-pairs.sh`
: Passes pairs of filenames to `rnxcmp` in turn.
: This is primarily to benchmark reading files, as they will normally
: miscompare immediately.

`compare.mk`
: Makefile to help verify that SRNX files are faithful to the originals.
: Calls `rnxcmp` (C) and `srnx-diff` (Rust) to compare RINEX to SRNX.

`convert.mk`
: Makefile for batch conversion of RINEX or CRX to SRNX.

`do-it.pl`
: The main script for generating space and time data.
: Give it the name of an input directory, and it eventually generates a
: `sizes.dat` with space and time consumption data.

`IONconf-v2.cls`
: LaTeX document class for the paper.

`make-ninja.pl`
: Helper script for `do-it.sh`.
: Generates a `build.ninja` file to compress an input directory.

`pareto.pl`
: Generates `pareto.dat` from `sizes.dat`.
: `pareto.dat` shows the Pareto front for disk usage and wall time,
: plus some (previous) standard options.

`make-verify.pl`
: Generates a `build.ninja` file to compare SRNX to corresponding CRX.

`NOTES.md`
: More documentation.

`sample.bib`
: LaTeX helper file.

`sizes.csv`
: Raw compressed sizes and compression times for different methods.

`srnx.tex`
: LaTeX source for this paper.

`worst-ratio.sh`
: Calculates the extreme ratios of file sizes between two directories.
: Not currently used; helpful to identify outliers in compression.
