use inc::Module::Install;

name     'Nagios-Plugin-OverHTTP';
all_from 'lib/Nagios/Plugin/OverHTTP.pm';
author   'Douglas Christopher Wilson <doug@somethingdoug.com>';
license  'perl';

requires 'Getopt::Long::Descriptive' => 0;
requires 'LWP::UserAgent'            => 0;
requires 'Moose'                     => '0.74';
requires 'MooseX::Getopt'            => '0.18';
requires 'MooseX::StrictConstructor' => '0.08';
requires 'Scalar::Util'              => '1.19';

build_requires 'Test::More';

# Enable tests to be in multi-level directories
tests_recursive;

WriteAll;

