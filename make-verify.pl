#! /usr/bin/env perl

use v5.12; # so readdir assigns to $_ in a lone while test
use strict;
use vars;
use warnings;

my $srcdir = shift or die "Usage: $0 <srcdir>\n";
opendir(my $dh, $srcdir) or die "Cannot open $srcdir";

print <<"HEADER";
# make-verify.pl generated file: DO NOT EDIT!
ninja_required_version = 1.1

srcdir = $srcdir

rule unbzip3
  description = UNBZ3 \$out
  command = dash -c "bz3cat \$in > \$out"

rule srnx
  description = RNX2SRNX \$out
  command = rnx2srnx \$in \$out

rule rinex
  description = SRNX2RNX \$out
  command = srnx2rnx \$in \$out

rule compare
  description = RNXCMP \$out
  command = dash -c "rnxcmp \$in > \$out"
HEADER

while (readdir $dh) {
	my $fn = $_;
	next unless /^(.*\.\d\d)d\.bz3$/;
	my $crx = $1 . 'd';
	my $rnx = $1 . 'o';
	my $srnx = $1 . 's';
	my $diff = $1 . '.diff';
	print "\nbuild $crx: unbzip3 \$srcdir/$fn\n" .
		"build $srnx: srnx $crx\n" .
		"build $rnx: rinex $srnx\n" .
		"build $diff: compare $crx $rnx\n";
}
closedir $dh;
