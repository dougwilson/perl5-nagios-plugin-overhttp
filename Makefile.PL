use inc::Module::Install;

name     'Nagios-Plugin-OverHTTP';
all_from 'lib/Nagios/Plugin/OverHTTP.pm';
author   'Douglas Christopher Wilson <doug@somethingdoug.com>';
license  'gpl';

build_requires 'Test::More';

# Enable tests to be in multi-level directories
tests_recursive;

WriteAll;

