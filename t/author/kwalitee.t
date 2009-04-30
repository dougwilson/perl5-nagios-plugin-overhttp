#!perl
# Test::Kwalitee cannot run in taint mode for whatever reason

use 5.008;
use strict;
use utf8;
use warnings 'all';

use Test::More;

# Only authors test the Kwalitee (except for CPANTS, of course :)
plan skip_all => 'Set TEST_AUTHOR to test the Kwalitee'
	unless $ENV{'TEST_AUTHOR'} || -e 'inc/.author';

# Need Test::Kwalitee
eval 'require Test::Kwalitee';
plan skip_all => 'Test::Kwalitee required for testing the Kwalitee'
	if $@;

# The test is automatically done on the import
# of the module
Test::Kwalitee->import;

