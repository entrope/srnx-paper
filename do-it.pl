#! /usr/bin/env perl
use strict;
use warnings;
use File::Find;
use File::Basename;

# Usage: do-it.pl <sourcedir> [execdir]
my $sourcedir = shift or die "Usage: $0 <sourcedir> [execdir]\n";
my $execdir = shift || dirname($0);
my $ncpu = $ENV{NCPU} || 16;

# 1. Ninja Setup
system("$execdir/make-ninja.pl $sourcedir > build.ninja") == 0
    or die "make-ninja.pl failed: $?";

# Helper to run a command with time -p if the time file doesn't exist
sub run_time_cmd {
    my ($time_file, $cmd, $cwd) = @_;
    return if -f $time_file;

    warn "Running: $cmd\n";
    if ($cwd) {
        system("cd $cwd && time -p -o ../$time_file $cmd") == 0
            or die " ... failed: $?";
    } else {
        system("time -p -o $time_file $cmd") == 0
            or die " ... failed: $?";
    }
}

# 2. Configuration
my @core_methods = qw(bzip2 bzip3 gzip kanzi zstd pcompress zpaq);

# Pipelines: name => { steps => [time_files], dir => directory_name }
# These must be run in dependency order, so we cannot use a hash.
my @pipelines = (
    { name => "orig"        , steps => [],            dir => "orig" },
    { name => "crx"         , steps => ["crx.time"],  dir => "crx" },
    { name => "srnx"        , steps => ["srnx.time"], dir => "srnx" },
    { name => "30s"         , steps => ["30s.time"],  dir => "30s" },
    { name => "30s+crx"     , steps => ["30s.time", "30s_crx.time"], dir => "30s_crx" },
    { name => "30s+srnx"    , steps => ["30s.time", "30s_srnx.time"], dir => "30s_srnx" },
    { name => "crx+srnx"    , steps => ["crx.time", "crx_srnx.time"], dir => "crx_srnx" },
    { name => "30s+crx+srnx", steps => ["30s.time", "30s_crx.time", "30s_crx_srnx.time"], dir => "30s_crx_srnx"}
);

# 3. Data Collection Helpers
sub parse_time_file {
    my $file = shift;
    return (0, 0) unless -f $file;
    my ($real, $user, $sys) = (0, 0, 0);
    open my $fh, '<', $file or return (0, 0);
    while (<$fh>) {
        if (/^real\s+(\S+)/)  { $real = $1; }
        elsif (/^user\s+(\S+)/) { $user = $1; }
        elsif (/^sys\s+(\S+)/)  { $sys  = $1; }
    }
    close $fh;
    return ($real, $user + $sys);
}

sub sum_sizes {
    my $dir = shift;
    return 0 unless -d $dir;
    my $total = 0;
    find(sub { $total += -s $_ if -f $_; }, $dir);
    return $total;
}

sub get_pipeline_time {
    my $pipe = shift;
    my ($total_wall, $total_cpu) = (0, 0);
    for my $time_file (@{$pipe->{steps}}) {
        my ($w, $c) = parse_time_file($time_file);
        $total_wall += $w;
        $total_cpu += $c;
    }
    return ($total_wall, $total_cpu);
}

# 4. Execution
open(my $out, '>', 'sizes.dat') or die "Cannot open sizes.dat: $!";

sub emit {
    my ($name, $disk, $cpu, $wall, $rinex_disk) = @_;
    return unless $disk && $disk > 0;
    my $ratio = $rinex_disk / $disk;
    printf $out "\"%s\" %.4f %s %s %s\n", $name, $ratio, $wall, $cpu, $disk;
}

# A. Run all preprocessing targets
for my $p (@pipelines) {
    my $dir = $p->{dir};
    # We run the 'all' target for the resulting directory
    run_time_cmd("${dir}.time", "ninja -j $ncpu ${dir}_all");
}

# B. Run core compression methods
my $rinex_disk = sum_sizes("orig");

for my $p (@pipelines) {
    my ($base_wall, $base_cpu) = get_pipeline_time($p);

    # Emit the pipeline itself as a result
    my $p_size = sum_sizes($p->{dir});
    emit($p->{name}, $p_size, $base_cpu, $base_wall, $rinex_disk);
    next if $p->{name} =~ /crx\+srnx/; # these only do the base pipeline

    for my $m (@core_methods) {
        my $method_time_file = "${m}_$p->{dir}.time";
        my $size = 0;
        my ($m_wall, $m_cpu) = (0, 0);

        if ($m =~ /^(pcompress|zpaq)/) {
            # Archivers: run directly
            my $ext = ($m eq "pcompress") ? "pz" : "zpaq";
            my $out_file = "$p->{dir}.$ext";
            my $cmd = ($m eq "pcompress")
                ? "pcompress -a -l 14 -D -G -L -s 64m -t $ncpu * ../$out_file"
                : "zpaq a ../$out_file * -m56 -t$ncpu > /dev/null";
            run_time_cmd($method_time_file, $cmd, $p->{dir});
            $size = -s $out_file if -f $out_file;
        } else {
            # Standard: run via ninja
            run_time_cmd($method_time_file, "ninja -j $ncpu ${m}_$p->{dir}_all");
            $size = sum_sizes("${m}_$p->{dir}");
        }

        ($m_wall, $m_cpu) = parse_time_file($method_time_file);
        my $full_name = ($p->{name} eq "orig") ? $m : "$p->{name}+$m";
        emit($full_name, $size, $base_cpu + $m_cpu, $base_wall + $m_wall, $rinex_disk);
    }
}

close($out);
