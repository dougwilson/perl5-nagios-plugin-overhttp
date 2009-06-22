#!perl
# Test::CleanNamespaces cannot run in taint mode for whatever reason

use 5.008;
use strict;
use utf8;
use warnings 'all';

use Test::More;

# Only authors get to run this test
plan skip_all => 'Set TEST_AUTHOR to enable this test'
	unless $ENV{'TEST_AUTHOR'} || -e 'inc/.author';

plan skip_all => 'Test::CleanNamespaces required to test namespace cleanliness'
	unless eval 'use Test::CleanNamespaces; 1';

# Run tests
all_namespaces_clean();

