#! /usr/bin/env perl
# Usage: make-ninja.pl <input-dir> [-n] [-c bzip2,bzip3,...]
# Generates a build.ninja file.
#   <input-dir>  directory containing source data files
#   -c <list>    selects a list of compressors (default: all available)
#
# Scans <input-dir> for:
#   *.??o         RINEX v2 observation files  -> copy to orig/
#   *.??d         CRX v2 files                -> crx2rnx to orig/*.??o
#   *.??d.bz3     bzip3-compressed CRX v2     -> bz3cat | crx2rnx to orig/*.??o
#   *.sp3.bz3, *.SP3.bz3, md5sums             -> ignored
#   other patterns                            -> warning

require v5.36;
use strict;
use warnings;

use File::Path qw(make_path);
use Getopt::Long;

my %methods = (
	'bzip2' => '.bz2',
	'bzip3' => '.bz3',
	'gzip' => '.gz',
	'kanzi' => '.knz',
	'zstd' => '.zst',
);

# Check command-line syntax.
my $input_dir = shift @ARGV;
unless ($input_dir && -d $input_dir) {
    die "Usage: $0 <input-dir> [-c bz2,bz3,...]\n";
}

# Build @comps.
my (@comps, $dry_run);
GetOptions("c=s" => \@comps, "n" => \$dry_run)
  or die("Error in command line arguments\n");
@comps = split(/,/, join(',', @comps));
for my $c (@comps) {
    die "Unknown compressor $c" unless exists $methods{$c};
}
@comps = sort keys %methods unless @comps;

# Build %origs.
opendir(my $dh, $input_dir) or die "Cannot open $input_dir: $!\n";
my (%origs, %bz3, %crx, %bz3crx);
while (readdir $dh) {
	if (/\.(\d\d)o$/) {
		$origs{$_} = ['copy', $_];
	} elsif (/^(.*\.\d\d)d$/) {
		my $rnx = $1 . 'o';
		$crx{$rnx} = $_;
	} elsif (/^(.*\.\d\d)o.bz3$/) {
		my $rnx = $1 . 'o';
		$bz3{$rnx} = $_;
	} elsif (/^(.*\.\d\d)d.bz3$/) {
		my $rnx = $1 . 'o';
		$bz3crx{$rnx} = $_;
	} elsif (/^\./ or /\.sp3\.bz3$/ or /\.SP3\.bz3$/ or /^brdc\d\d\d\d.\d\d[ng](.bz3)?/ or /^md5sums$/) {
		# silently ignore
	} else {
		warn "unhandled: $_\n";
	}
}
foreach my ($rnx, $src) (%bz3) {
	$origs{$rnx} //= ['unbzip3', $src];
}
foreach my ($rnx, $src) (%crx) {
	$origs{$rnx} //= ['crx2rnx', $src];
}
foreach my ($rnx, $src) (%bz3crx) {
	$origs{$rnx} //= ['bz3crx', $src];
}
closedir($dh);

# Emit our fixed header.
print <<'HEADER';
# make-ninja.pl generated file: DO NOT EDIT!
ninja_required_version = 1.1

rule copy
  description = CP $out
  command = cp $in $out

rule crx2rnx
  description = CRX2RNX $out
  command = dash -c "crx2rnx $in - > $out"

rule bz3crx
  description = BZ3CRX $out
  command = dash -c "bz3cat $in | crx2rnx - > $out"

rule unbzip3
  description = UNBZIP3 $out
  command = dash -c "bz3cat $in > $out"

rule rnx2crx
  description = RNX2CRX $out
  command = dash -c "rnx2crx $in - > $out"

rule decimate
  description = DECIMATE $out
  command = dash -c "teqc -O.dec 30s $in > $out"

rule bzip2
  description = BZIP2 $out
  command = dash -c "bzip2 -zc9 $in > $out"

rule bzip3
  description = BZIP3 $out
  command = dash -c "bzip3 -zc -b 511 $in > $out"

rule gzip
  description = GZIP $out
  command = dash -c "gzip -9c $in > $out"

rule kanzi
  description = KANZI $out
  command = kanzi -c -j 1 -x -l 9 -v 0 -i $in -o $out

rule srnx
  description = SRNX $out
  command = rnx2srnx $in $out

rule zstd
  description = ZSTD $out
  command = zstd -z -q -15 $in -o $out
HEADER

# Create output directories.
if (not $dry_run) {
	make_path('orig', 'crx', 'srnx', '30s', '30s_crx', '30s_crx_srnx');
	foreach my $c (@comps) {
		make_path($c . "_orig", $c . "_crx", $c . "_srnx", $c . "_30s", $c . "_30s_crx", $c . "_30s_srnx");
	}
}

sub name_crx_srnx($) {
	my ($orig) = @_;
	if ($orig =~ /^(.*)\.rnx$/) {
		return $1 . ".crx", $1 . ".srnx";
	}
	if ($orig =~ /^(.*\.\d\d)o$/) {
		return $1 . "d", $1 . "o";
	}
	die "unexpected RINEX file name $orig\n";
}

# Emit rules for each `orig` file.
my @origs = sort keys %origs;
my (@crx, @srnx);
foreach my $orig (@origs) {
	my $rule = $origs{$orig}->[0];
	my $source = $origs{$orig}->[1];
	my ($crx, $srnx) = name_crx_srnx($orig);
	push @crx, $crx;
	push @srnx, $srnx;

	print <<"ORIG";

build orig/$orig: $rule $input_dir/$source
build 30s/$orig: decimate orig/$orig
build crx/$crx: rnx2crx orig/$orig
build 30s_crx/$crx: rnx2crx 30s/$orig
build srnx/$srnx: srnx orig/$orig
build crx_srnx/$srnx: srnx crx/$crx
build 30s_srnx/$srnx: srnx 30s/$orig
build 30s_crx_srnx/$srnx: srnx 30s_crx/$crx
ORIG
	for my $c (@comps) {
		my $ext = $methods{$c};
		print <<"METHOD";
build ${c}_orig/$orig$ext: $c orig/$orig
build ${c}_30s/$orig$ext: $c 30s/$orig
build ${c}_crx/$crx$ext: $c crx/$crx
build ${c}_30s_crx/$crx$ext: $c 30s_crx/$crx
build ${c}_srnx/$srnx$ext: $c srnx/$srnx
build ${c}_30s_srnx/$srnx$ext: $c 30s_srnx/$srnx
METHOD
	}
}

print "\n\nbuild orig_all: phony" . join('', map { " orig/$_" } @origs) . "\n";
print "build crx_all: phony" . join('', map { " crx/$_" } @crx) . "\n";
print "build srnx_all: phony" . join('', map { " srnx/$_" } @srnx) . "\n";
print "build crx_srnx_all: phony" . join('', map { " crx_srnx/$_" } @srnx) . "\n";
print "build 30s_all: phony" . join('', map { " 30s/$_" } @origs) . "\n";
print "build 30s_srnx_all: phony" . join('', map { " 30s_srnx/$_" } @srnx) . "\n";
print "build 30s_crx_all: phony" . join('', map { " 30s_crx/$_" } @crx) . "\n";
print "build 30s_crx_srnx_all: phony" . join('', map { " 30s_crx_srnx/$_" } @srnx) . "\n";
for my $c (@comps) {
	my $ext = $methods{$c};
	print "build ${c}_orig_all: phony". join('', map { " ${c}_orig/$_$ext" } @origs) . "\n";
	print "build ${c}_crx_all: phony". join('', map { " ${c}_crx/$_$ext" } @crx) . "\n";
	print "build ${c}_srnx_all: phony". join('', map { " ${c}_srnx/$_$ext" } @srnx) . "\n";
	print "build ${c}_30s_all: phony". join('', map { " ${c}_30s/$_$ext" } @origs) . "\n";
	print "build ${c}_30s_crx_all: phony". join('', map { " ${c}_30s_crx/$_$ext" } @crx) . "\n";
	print "build ${c}_30s_srnx_all: phony". join('', map { " ${c}_30s_srnx/$_$ext" } @srnx) . "\n";
}
