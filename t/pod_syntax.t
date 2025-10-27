#!/usr/bin/perl
use strict;
use warnings;
use Test::Most;

# Test POD documentation coverage

################################################################################
# POD Syntax Tests
################################################################################

eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;

my @pod_files = all_pod_files('lib');
plan tests => scalar(@pod_files);

for my $file (@pod_files) {
    pod_file_ok($file, "POD syntax ok in $file");
}