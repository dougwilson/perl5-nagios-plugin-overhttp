#!perl -T

use 5.008;
use strict;
use utf8;
use warnings;

use Test::More;

# Only authors test POD
plan skip_all => 'Set TEST_AUTHOR to enable this test'
	unless $ENV{'TEST_AUTHOR'} || -e 'inc/.author';

# Ensure a recent version of Test::Pod
my $min_tp = 1.22;
eval "use Test::Pod $min_tp";
plan skip_all => sprintf 'Test::Pod %f required for testing POD', $min_tp
	if $@;

# Test the POD files
all_pod_files_ok();

