use inc::Module::Install;

name     'Nagios-Plugin-OverHTTP';
all_from 'lib/Nagios/Plugin/OverHTTP.pm';
author   'Douglas Christopher Wilson <doug@somethingdoug.com>';
license  'perl';
resources homepage   => 'http://github.com/dougwilson/perl5-nagios-plugin-overhttp/tree/master';
resources repository => 'git://github.com/dougwilson/perl5-nagios-plugin-overhttp.git';

requires 'Data::Validate::Domain'    => '0.02';
requires 'Data::Validate::URI'       => '0.05';
requires 'Getopt::Long::Descriptive' => 0;
requires 'LWP::UserAgent'            => 0;
requires 'Moose'                     => '0.74';
requires 'MooseX::Getopt'            => '0.18';
requires 'MooseX::StrictConstructor' => '0.08';
requires 'MooseX::Types'             => '0.08';
requires 'Readonly'                  => 0;
requires 'Scalar::Util'              => '1.19';
requires 'URI'                       => 0;
requires 'version'                   => '0.74';

build_requires 'HTTP::Response';
build_requires 'Test::MockObject';
build_requires 'Test::More';

install_script 'bin/check_over_http';

# Enable tests to be in multi-level directories
tests_recursive;

WriteAll;

