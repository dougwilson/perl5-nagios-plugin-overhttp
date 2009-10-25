use inc::Module::Install;

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
	'Getopt::Long::Descriptive' => 0,
	'HTTP::Request'             => '5.827',
	'HTTP::Status'              => '5.817',
	'LWP::UserAgent'            => 0,
	'Moose'                     => '0.74',
	'MooseX::Getopt'            => '0.19',
	'MooseX::StrictConstructor' => '0.08',
	'MooseX::Types'             => '0.08',
	'Readonly'                  => '1.03',
	'Scalar::Util'              => '1.19',
	'URI'                       => 0,
	'namespace::clean'          => '0.04';

# Modules that are required for tests
test_requires
	'HTTP::Response'   => 0,
	'Test::MockObject' => 0,
	'Test::More'       => '0.82';

# Modules that are required for author tests
author_requires
	'File::Spec'                      => 0,
	'Module::Install'                 => '0.91',
	'Module::Install::AuthorRequires' => '0.02',
	'Module::Install::AuthorTests'    => '0.002',
	'Pod::Coverage'                   => '0.18',
	'Test::CleanNamespaces'           => 0,
	'Test::ConsistentVersion'         => 0,
	'Test::DistManifest'              => 0,
	'Test::MinimumVersion'            => '0.009',
	'Test::Perl::Critic'              => 0,
	'Test::Pod'                       => '1.22',
	'Test::Pod::Content'              => 0,
	'Test::Pod::Coverage'             => '1.08',
	'Test::Requires'                  => '0.02';

auto_provides;

# Enable tests to be in multi-level directories
tests_recursive;

# Author tests in xt/
recursive_author_tests('xt');

WriteAll;
