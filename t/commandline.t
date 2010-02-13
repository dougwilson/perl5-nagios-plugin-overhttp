#!perl

use strict;
use warnings 'all';

use Test::More tests => 14;

use Nagios::Plugin::OverHTTP;

SKIP: {
	local @ARGV = '--help';

	my $skip = 1;
	# Create new plugin with no arguments which means it will read from
	# command line
	eval {
		local *{'CORE::GLOBAL::exit'} = sub { $skip = 1; };
		Nagios::Plugin::OverHTTP->new_with_options;
	};

	skip 'Usage failed out', 9, if $skip;

	my $err = $@;

	like($err, qr/^usage:/ms, 'Help should show usage');

	like($err, qr/\s+--default_status\s+/msx, 'default_status should be in usage');
	like($err, qr/\s+--hostname\s+/msx, 'hostname should be in usage');
	like($err, qr/\s+--path\s+/msx, 'path should be in usage');
	like($err, qr/\s+--ssl\s+/msx, 'ssl should be in usage');
	like($err, qr/\s+--timeout\s+/msx, 'timeout should be in usage');
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

SKIP: {
	my $url = 'http://example.net/nagios/check_service';
	local @ARGV = split /\s+/, "--url=$url --critical time=4 --critical other=3.5"
		." --warning time=10:3 --warning other=4:";

	# Create new plugin with no arguments which means it will read from
	# command line
	my $plugin = Nagios::Plugin::OverHTTP->new_with_options;

	skip 'Failure creating plugin.', 2 if !defined $plugin;

	is_deeply($plugin->critical, {time => 4, other => 3.5}, 'Critical set');
	is_deeply($plugin->warning, {time => '10:3', other => '4:'}, 'Warning set');
}
