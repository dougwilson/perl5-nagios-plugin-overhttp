#!perl -T

use strict;
use warnings 'all';

use Test::More tests => 23;

use_ok('Nagios::Plugin::OverHTTP');

# Create new plugin
my $plugin = new_ok('Nagios::Plugin::OverHTTP');

# Set the URL
$plugin->url('http://test/check_ok');

# Setting the URL should cause everything else to set
is($plugin->hostname, 'test', 'hostname set from URL');
is($plugin->path, '/check_ok', 'path set from URL');
isnt($plugin->ssl, 1, 'SSL set from URL');

# Change the hostname
$plugin->hostname('server1');

# Changing the hostname should update the URL
is($plugin->url, 'http://server1/check_ok', 'URL updated');
is($plugin->hostname, 'server1', 'hostname changed');
is($plugin->path, '/check_ok', 'path still the same');
isnt($plugin->ssl, 1, 'SSL still the same');

# Change the SSL
$plugin->ssl(1);

# Changing the SSL should update the URL
is($plugin->url, 'https://server1/check_ok', 'URL updated');
is($plugin->hostname, 'server1', 'hostname stil the same');
is($plugin->path, '/check_ok', 'path still the same');
is($plugin->ssl, 1, 'SSL changed');

# Change the path
$plugin->path('check_new');

# Changing the path should update the URL
is($plugin->url, 'https://server1/check_new', 'URL updated');
is($plugin->hostname, 'server1', 'hostname stil the same');
is($plugin->path, '/check_new', 'path updated');
is($plugin->ssl, 1, 'SSL still the same');

# Change to blank path
$plugin->path(q{});
is($plugin->path, '/', 'Blank path changed to /');
is($plugin->url, 'https://server1/', 'Blank path correct in URL');

# Change the timeout
isnt($plugin->has_timeout, 1, 'Has no timeout');
$plugin->timeout(2);
is($plugin->has_timeout, 1, 'Has timeout');
is($plugin->timeout, 2, 'timeout updates');
$plugin->clear_timeout;
isnt($plugin->has_timeout, 1, 'timeout cleared');
