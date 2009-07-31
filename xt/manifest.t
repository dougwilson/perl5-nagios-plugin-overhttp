#!perl -T

use 5.008;
use strict;
use utf8;
use warnings 'all';

use Test::More;

# Only authors get to criticize code
plan skip_all => 'Set TEST_AUTHOR to enable this test'
	unless $ENV{'TEST_AUTHOR'} || -e 'inc/.author';

plan skip_all => 'Test::DistManifest required to check manifest'
	unless eval 'use Test::DistManifest; 1';

# Check the MANIFEST
manifest_ok();

