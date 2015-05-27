#!/usr/local/env perl
use lib ($ENV{'HOME'} . '/Dropbox/Autoadmin1/lib');
use strict;
use Test::More qw(no_plan);
#~ use Logger;
#~ my $logger = logger_init(STDERR => 1, LEVEL => 'DEBUG');
use Data::Dumper;
use NetIf::Vlan;

use_ok('Config::File');

my $config_file = Config::File->new(
	$ENV{'HOME'} . '/Dropbox/Autoadmin1/lib/tests/test_conf/SWITCHES.conf',
	$ENV{'HOME'} . '/Dropbox/Autoadmin1/lib/tests/test_conf/AP_LINK.conf',
	$ENV{'HOME'} . '/Dropbox/Autoadmin1/lib/tests/test_conf/RESOURCES.conf',
);



$config_file->compile_files();
print  $config_file->{'IMAGE'}{'TEST-SW1#3'}->get_info() . "\n";
print  $config_file->{'IMAGE'}{'TEST-SW1#4'}->get_info();
