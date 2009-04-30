#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Nagios::Plugin::OverHTTP' );
}

diag( "Testing Nagios::Plugin::OverHTTP $Nagios::Plugin::OverHTTP::VERSION, Perl $], $^X" );
