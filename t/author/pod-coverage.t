#!perl -T

use 5.008;
use strict;
use utf8;
use warnings 'all';

use Test::More;

# Only authors test POD coverage
plan skip_all => 'set TEST_AUTHOR to enable this test'
	unless $ENV{'TEST_AUTHOR'} || -e 'inc/.author';

# Ensure a recent version of Test::Pod::Coverage
my $min_tpc = 1.08;
eval "use Test::Pod::Coverage $min_tpc";
plan skip_all => sprintf 'Test::Pod::Coverage %f required for testing POD coverage', $min_tpc
	if $@;

# Test::Pod::Coverage doesn't require a minimum Pod::Coverage version,
# but older versions don't recognize some common documentation styles
my $min_pc = 0.18;
eval sprintf 'use Pod::Coverage %f', $min_pc;
plan skip_all => 'Pod::Coverage %f required for testing POD coverage', $min_pc
    if $@;

# Test the POD, except for Moose privates
all_pod_coverage_ok({
	'also_private' => [qw(BUILD)],
});

