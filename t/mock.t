#!perl -T

use strict;
use warnings 'all';

use Test::MockObject;
use Test::More tests => 17;

# Create a mock LWP::UserAgent
my $fake_ua = Test::MockObject->new;
$fake_ua->set_isa('LWP::UserAgent');

use_ok('Nagios::Plugin::OverHTTP');

$fake_ua->mock('get', sub {
	my ($self, $url) = @_;

	eval 'use HTTP::Response';

	if ($url =~ m{check_ok\z}msx) {
		return HTTP::Response->new(200, 'OK', undef, 'OK - I am good');
	}
	elsif ($url =~ m{check_500\z}msx) {
		return HTTP::Response->new(500, 'Internal Server Error');
	}
	else {
		return HTTP::Response->new(404, 'Not Found');
	}
});

my $plugin = new_ok('Nagios::Plugin::OverHTTP' => [
	url => 'http://example.net/nagios/check_nonexistant',
	useragent => $fake_ua,
]);

is($plugin->url, 'http://example.net/nagios/check_nonexistant', 'URL is what was set');
isnt($plugin->has_message, 1, 'Has no message yet');
isnt($plugin->has_status, 1, 'Has no status yet');
is($plugin->status, 3, 'Nonexistant plugin has UNKNOWN status');
like($plugin->message, qr/\A UNKNOWN .+ Not \s Found/msx, 'Nonexistant plugin message');

$plugin->url('http://example.net/nagios/check_ok');

is($plugin->url, 'http://example.net/nagios/check_ok', 'URL is changed');
isnt($plugin->has_message, 1, 'Has no message yet');
isnt($plugin->has_status, 1, 'Has no status yet');
is($plugin->status, 0, 'Good plugin has OK status');
like($plugin->message, qr/\A OK/msx, 'OK plugin message');

$plugin->url('http://example.net/nagios/check_500');

is($plugin->url, 'http://example.net/nagios/check_500', 'URL is changed');
isnt($plugin->has_message, 1, 'Has no message yet');
isnt($plugin->has_status, 1, 'Has no status yet');
is($plugin->status, 2, '500 plugin has CRITICAL status');
like($plugin->message, qr/\A CRITICAL/msx, 'CRITICAL plugin message');
