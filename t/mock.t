#!perl -T

use strict;
use warnings 'all';

use Test::MockObject;
use Test::More tests => 5;

# Create a mock LWP::UserAgent
my $fake_ua = Test::MockObject->new;
$fake_ua->set_isa('LWP::UserAgent');

use_ok('Nagios::Plugin::OverHTTP');

my $plugin = new_ok('Nagios::Plugin::OverHTTP' => [
	url => 'http://example.net/nagios/check_nonexistant',
	useragent => $fake_ua,
]);

is($plugin->url, 'http://example.net/nagios/check_nonexistant', 'URL is what was set');
isnt($plugin->has_message, 1, 'Has no message yet');
isnt($plugin->has_status, 1, 'Has no status yet');
#is($plugin->message, '', 'Nonexistant plugin has empty message');
#is($plugin->status, 2, 'Nonexistant plugin has UNKNOWN status');
