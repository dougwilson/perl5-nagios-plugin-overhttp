#!perl -T

use strict;
use warnings 'all';

use Test::MockObject;
use Test::More tests => 37;

# Create a mock LWP::UserAgent
my $fake_ua = Test::MockObject->new;
$fake_ua->set_isa('LWP::UserAgent');

use_ok('Nagios::Plugin::OverHTTP');

$fake_ua->mock('get', sub {
	my ($self, $url) = @_;

	eval 'use HTTP::Response';

	($url) = $url =~ m{/(\w+)\z}msx;
	my $res;

	if ($url =~ m{_([A-Z]+)\z}msx) {
		$res = HTTP::Response->new(200, 'OK', undef, "$1 - I am something");
	}
	elsif ($url =~ m{_(\d{3})\z}msx) {
		$res = HTTP::Response->new($1, 'Some status', undef, 'OK - I am some result');
	}
	elsif ($url eq 'check_ok_header') {
		$res = HTTP::Response->new(200, 'OK', undef, 'OK - I am good');
		$res->header('X-Nagios-Status' => 'WARNING');
	}
	else {
		$res = HTTP::Response->new(404, 'Not Found');
	}

	return $res;
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

check_url($plugin, 'http://example.net/nagios/check_OK'       , 0, 'OK - I am something', 'OK');
check_url($plugin, 'http://example.net/nagios/check_WARNING'  , 1, 'WARNING - I am something', 'WARNING');
check_url($plugin, 'http://example.net/nagios/check_CRITICAL' , 2, 'CRITICAL - I am something', 'CRITICAL');
check_url($plugin, 'http://example.net/nagios/check_UNKNOWN'  , 3, 'UNKNOWN - I am something', 'UNKNOWN');
check_url($plugin, 'http://example.net/nagios/check_500'      , 2, qr/\ACRITICAL/msx, '500');
check_url($plugin, 'http://example.net/nagios/check_ok_header', 1, qr/\AWARNING - OK/ms, 'Header override');

exit 0;

sub check_url {
	my ($plugin, $url, $status, $message, $name) = @_;

	# Change the URL
	$plugin->url($url);

	# Make sure it was changed
	is($plugin->url, $url, "[$name] URL was set");
	isnt($plugin->has_message, 1, "[$name] Has no message yet");
	isnt($plugin->has_status, 1, "[$name] Has no status yet");
	is($plugin->status, $status, "[$name] Status is correct");

	if (ref $message eq 'Regexp') {
		like($plugin->message, $message, "[$name] Message is correct");
	}
	else {
		is($plugin->message, $message, "[$name] Message is correct");
	}

	return $plugin->status, $plugin->message;
}
