#!perl -T

use strict;
use warnings 'all';

use Test::More tests => 3;

use_ok('Nagios::Plugin::OverHTTP');

SKIP: {
	my $url = 'http://example.net/nagios/check_service';
	local @ARGV = "--url=$url";

	# Create new plugin with no arguments which means it will read from
	# command line
	my $plugin = new_ok('Nagios::Plugin::OverHTTP');

	skip 'Failure creating plugin.', 1 if !defined $plugin;

	is($plugin->url, $url, 'Minimal arguments.');
}
