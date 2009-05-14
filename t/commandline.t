#!perl -T

use strict;
use warnings 'all';

use Test::More tests => 11;

use_ok('Nagios::Plugin::OverHTTP');

SKIP: {
	local @ARGV = '--help';

	# Create new plugin with no arguments which means it will read from
	# command line
	eval {
		Nagios::Plugin::OverHTTP->new_with_options;
	};

	my $err = $@;

	like($err, qr/^usage:/ms, 'Help should show usage');

	like($err, qr/\s+--hostname\s+/msx, 'hostname should be in usage');
	like($err, qr/\s+--path\s+/msx, 'path should be in usage');
	like($err, qr/\s+--ssl\s+/msx, 'ssl should be in usage');
	like($err, qr/\s+--url\s+/msx, 'url should be in usage');

	unlike($err, qr/\s+--message\s+/msx, 'message should not be in usage');
	unlike($err, qr/\s+--useragent\s+/msx, 'useragent should not be in usage');
}

SKIP: {
	my $url = 'http://example.net/nagios/check_service';
	local @ARGV = "--url=$url";

	# Create new plugin with no arguments which means it will read from
	# command line
	my $plugin = Nagios::Plugin::OverHTTP->new_with_options;

	skip 'Failure creating plugin.', 2 if !defined $plugin;

	is($plugin->url, $url, 'Minimal arguments');

	$plugin = Nagios::Plugin::OverHTTP->new_with_options(url => 'http://example.net/nagios/something');

	is($plugin->url, $url, 'Command line arguments override perl arguments');
}

SKIP: {
	my $url = 'http://example.net/nagios/check_service';
	local @ARGV = split /\s+/, '--hostname=example.net --path=/nagios/check_service';

	# Create new plugin with no arguments which means it will read from
	# command line
	my $plugin = Nagios::Plugin::OverHTTP->new_with_options;

	skip 'Failure creating plugin.', 1 if !defined $plugin;

	is($plugin->url, $url, 'Hostname + relative URL');
}
