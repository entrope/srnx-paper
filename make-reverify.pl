#! /usr/bin/env perl

use v5.12;
use strict;
use warnings;

my $srcdir = shift or die "Usage: $0 <srcdir>\n";
opendir(my $dh, $srcdir) or die "Cannot open $srcdir";

print <<"HEADER";
# make-reverify.pl generated file: DO NOT EDIT!
ninja_required_version = 1.1

srcdir = $srcdir

rule verify
  description = VERIFY \$in
  command = IN=\$in; SRNX=\$\${IN%??o}srnx; rnx2srnx \$in \$\$SRNX && srnx2rnx \$\$SRNX \${in}.tmp && rnxcmp \$in \$\$SRNX > \$out && srnx-diff --quiet \$in \$\$SRNX >> \$out && rm \${in}.tmp

HEADER

while (readdir $dh) {
	my $fn = $_;
	next unless /\.\d\do$/;
	my $rnx = $fn;
	my $diff = $fn . '.diff';
	print "build $diff: verify $rnx\n";
}
