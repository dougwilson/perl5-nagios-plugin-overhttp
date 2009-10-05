use inc::Module::Install;

name     'Nagios-Plugin-OverHTTP';
all_from 'lib/Nagios/Plugin/OverHTTP.pm';
author   'Douglas Christopher Wilson <doug@somethingdoug.com>';
license  'perl';
resources homepage   => 'http://github.com/dougwilson/perl5-nagios-plugin-overhttp/';
resources repository => 'git://github.com/dougwilson/perl5-nagios-plugin-overhttp.git';

requires 'Data::Validate::Domain'    => '0.02';
requires 'Data::Validate::URI'       => '0.05';
requires 'Getopt::Long::Descriptive' => 0;
requires 'HTTP::Status'              => '5.817';
requires 'LWP::UserAgent'            => 0;
requires 'Moose'                     => '0.74';
requires 'MooseX::Getopt'            => '0.19';
requires 'MooseX::StrictConstructor' => '0.08';
requires 'MooseX::Types'             => '0.08';
requires 'Readonly'                  => 0;
requires 'Scalar::Util'              => '1.19';
requires 'URI'                       => 0;
requires 'namespace::clean'          => '0.04';

build_requires 'HTTP::Response'   => 0;
build_requires 'Test::MockObject' => 0;
build_requires 'Test::More'       => '0.82';

author_requires 'File::Spec'              => 0;
author_requires 'Pod::Coverage'           => '0.18';
author_requires 'Test::CleanNamespaces'   => 0;
author_requires 'Test::ConsistentVersion' => 0;
author_requires 'Test::DistManifest'      => 0;
author_requires 'Test::MinimumVersion'    => '0.009';
author_requires 'Test::Perl::Critic'      => 0;
author_requires 'Test::Pod'               => '1.22';
author_requires 'Test::Pod::Content'      => 0;
author_requires 'Test::Pod::Coverage'     => '1.08';
author_requires 'Test::Requires'          => '0.02';

auto_provides;

# Enable tests to be in multi-level directories
tests_recursive;

# Author tests in xt/
recursive_author_tests('xt');

WriteAll;

