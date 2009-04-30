#!perl -T

use 5.008;
use strict;
use utf8;
use warnings 'all';

use Test::More;

# Only authors get to criticize code
plan skip_all => 'Set TEST_AUTHOR to enable this test'
	unless $ENV{'TEST_AUTHOR'} || -e 'inc/.author';

eval 'use File::Spec';
plan skip_all => 'File::Spec required to criticize code'
	if $@;

eval 'use Test::Perl::Critic';
plan skip_all => 'Test::Perl::Critic required to criticize code'
	if $@;

Test::Perl::Critic->import(
	'-profile' => File::Spec->catfile('t', 'author', 'perlcriticrc'),
);

# Criticize code
all_critic_ok();

