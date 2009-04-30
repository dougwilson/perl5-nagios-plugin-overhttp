use inc::Module::Install;

name     'Nagios-Plugin-OverHTTP';
all_from 'lib/Nagios/Plugin/OverHTTP.pm';
author   'Douglas Christopher Wilson <doug@somethingdoug.com>';
license  'gpl';

build_requires 'Test::More';

auto_install;

WriteAll;

