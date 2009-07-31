#!perl
# This uses default File::Find, so chdir won't
# work in taint mode

use 5.008;
use strict;
use utf8;
use warnings;

use Test::More;

# Only authors test this
plan skip_all => 'Set TEST_AUTHOR to enable this test'
	unless $ENV{'TEST_AUTHOR'} || -e 'inc/.author';

# Ensure a recent version of Test::MinimumVersion
my $min = 0.009;
eval "use Test::MinimumVersion $min";
plan skip_all => "Test::MinimumVersion $min required for test"
	if $@;

# Test
all_minimum_version_from_metayml_ok();

