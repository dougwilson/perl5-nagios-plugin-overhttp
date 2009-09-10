#!perl -T

use strict;
use warnings 'all';

use HTTP::Response;
use Test::More 0.82;
use Test::MockObject;

plan tests => 57;

# Create a mock LWP::UserAgent
my $fake_ua = Test::MockObject->new;
$fake_ua->set_isa('LWP::UserAgent');

use Nagios::Plugin::OverHTTP;

$fake_ua->mock('get', sub {
	my ($self, $url) = @_;

	my $time_start = time;

	($url) = $url =~ m{/(\w+)\z}msx;
	my $res;

	if ($url =~ m{_([A-Z]+)\z}msx) {
		$res = HTTP::Response->new(200, 'OK', undef, "$1 - I am something");
	}
	elsif ($url =~ m{_(\d{3})\z}msx) {
		$res = HTTP::Response->new($1, 'Some status', undef, 'OK - I am some result');
	}
	elsif ($url =~ m{_time_(\d+)\z}msx) {
		sleep $1;
		$res = HTTP::Response->new(200, 'Some status', undef, 'OK - I am some result');
	}
	elsif ($url =~ m{_(\d)_header\z}msx) {
		$res = HTTP::Response->new(200, 'Some status', undef, 'I am some result');
		$res->header('X-Nagios-Status' => $1);
	}
	elsif ($url eq 'check_ok_header') {
		$res = HTTP::Response->new(200, 'OK', undef, 'OK - I am good');
		$res->header('X-Nagios-Status' => 'WARNING');
	}
	elsif ($url =~ m{_no_status\z}msx) {
		$res = HTTP::Response->new(200, 'Some status', undef, 'I have no status');
	}
	else {
		$res = HTTP::Response->new(404, 'Not Found');
	}

	if (time - $time_start > $self->timeout) {
		$res = HTTP::Response->new(500, 'read timeout', undef, '500 read timeout');
	}

	return $res;
});
$fake_ua->mock('timeout', sub {
	my ($self, $timeout) = @_;

	my $old_timeout = $self->{timeout} || 180;

	if (defined $timeout) {
		$self->{timeout} = $timeout;
	}

	return $old_timeout;
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

check_url($plugin, 'http://example.net/nagios/check_OK'       , $Nagios::Plugin::OverHTTP::STATUS_OK      , 'OK - I am something'      , 'OK');
check_url($plugin, 'http://example.net/nagios/check_WARNING'  , $Nagios::Plugin::OverHTTP::STATUS_WARNING , 'WARNING - I am something' , 'WARNING');
check_url($plugin, 'http://example.net/nagios/check_CRITICAL' , $Nagios::Plugin::OverHTTP::STATUS_CRITICAL, 'CRITICAL - I am something', 'CRITICAL');
check_url($plugin, 'http://example.net/nagios/check_UNKNOWN'  , $Nagios::Plugin::OverHTTP::STATUS_UNKNOWN , 'UNKNOWN - I am something' , 'UNKNOWN');
check_url($plugin, 'http://example.net/nagios/check_500'      , $Nagios::Plugin::OverHTTP::STATUS_CRITICAL, qr/\ACRITICAL/msx          , '500');
check_url($plugin, 'http://example.net/nagios/check_ok_header', $Nagios::Plugin::OverHTTP::STATUS_WARNING , qr/\AWARNING - OK/ms       , 'Header override');
check_url($plugin, 'http://example.net/nagios/check_2_header' , $Nagios::Plugin::OverHTTP::STATUS_CRITICAL, qr//ms                     , 'Numberic header');

##############################
# NO STATUS TESTS
check_url($plugin, 'http://example.net/nagios/check_no_status', $plugin->default_status,  qr//ms, 'no status');
$plugin->default_status('critical');
check_url($plugin, 'http://example.net/nagios/check_no_status', $Nagios::Plugin::OverHTTP::STATUS_CRITICAL,  qr//ms, 'no status critical');

##############################
# TIMEOUT TESTS
isnt($plugin->has_timeout, 1, 'Has not timeout yet');
$plugin->timeout(10);
is($plugin->has_timeout, 1, 'Has timeout');
is($plugin->timeout, 10, 'Timeout set');
$plugin->url('http://example.net/nagios/check_time_15');
is($plugin->status, 2, 'Timeout should be CRITICAL');
$plugin->url('http://example.net/nagios/check_time_6');
is($plugin->status, 0, 'Timeout did not occur');
$plugin->clear_timeout;
isnt($plugin->has_timeout, 1, 'Timeout cleared');

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
