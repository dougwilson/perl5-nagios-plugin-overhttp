use inc::Module::Install;

use Module::Install::AuthorRequires 0.02;
use Module::Install::AuthorTests 0.002;

name     'Nagios-Plugin-OverHTTP';
all_from 'lib/Nagios/Plugin/OverHTTP.pm';
author   'Douglas Christopher Wilson <doug@somethingdoug.com>';
license  'perl';

# Resources
resources homepage   => 'http://github.com/dougwilson/perl5-nagios-plugin-overhttp/';
resources repository => 'git://github.com/dougwilson/perl5-nagios-plugin-overhttp.git';

# Modules that are required
requires
	'Data::Validate::Domain'    => '0.02',
	'Data::Validate::URI'       => '0.05',
	'Carp'                      => 0,
	'Getopt::Long::Descriptive' => 0,
	'HTTP::Request'             => '5.827',
	'HTTP::Status'              => '5.817',
	'LWP::UserAgent'            => 0,
	'Moose'                     => '0.74',
	'MooseX::Getopt'            => '0.19',
	'MooseX::StrictConstructor' => '0.08',
	'MooseX::Types'             => '0.08',
	'MooseX::Types::Moose'      => 0,
	'Readonly'                  => '1.03',
	'Scalar::Util'              => '1.19',
	'URI'                       => 0,
	'namespace::clean'          => '0.04';

# Modules that are required for tests in t/
test_requires
	'HTTP::Response'   => 0,
	'HTTP::Status'     => '5.817',
	'Test::Exception'  => 0,
	'Test::MockObject' => 0,
	'Test::More'       => '0.94';

# Modules that are required for tests in xt/
author_requires
	'Test::More'     => 0,
	'Test::Requires' => '0.02';

# Enable tests to be in multi-level directories
tests_recursive;

# Author tests in xt/
recursive_author_tests('xt');

# Write the provided classes in the META
auto_provides;

if (eval "require Getopt::Long::Descriptive 0.082; 1;") {
	# Getopt::Long::Descriptive is install, make sure it's not a broken version
	if (Getopt::Long::Descriptive->VERSION ge '0.082'
	    && Getopt::Long::Descriptive->VERSION lt '0.084') {
		# Two versions of Getopt::Long::Descriptive have a bug that affects this
		# package, and so if you have that version, we require the version where
		# it was fixed.
		requires 'Getopt::Long::Descriptive' => '0.084';
	}
}

WriteAll;
