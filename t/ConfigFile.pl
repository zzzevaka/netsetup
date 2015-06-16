#!/usr/local/env perl
use lib ($ENV{'HOME'} . '/Dropbox/Autoadmin1/lib');
use strict;
use Test::More qw(no_plan);
use Data::Dumper;
use NetSetup::NetIf::Vlan;

use_ok('Config::File');

# создать конфигурационные файлы
my $fh;
my $dir = '/tmp';
# создать SWITCHES.conf
if (!open $fh, ">", "$dir/SWITCHES.conf") {
	die "can't open file $dir/SWITCHES.conf for reading";
}
print $fh "SW dev TEST-SW1 parent em0 base 100 inet 192.168.1.1/30 count 5 ignore 1";
print $fh "SW dev TEST-SW2 parent em0 base 150 inet 192.168.1.5/30 count 5";
close $fh;
# создать AP_LINK.conf
if (!open $fh, ">", "$dir/AP_LINK.conf") {
	die "can't open file $dir/AP_LINK.conf for reading";
}
print $fh "AP_LINK ap IVANOV-II dev TEST-SW1 port 3";
print $fh "AP_LINK ap SYDOROV-SS dev ROUTER port re0";
close $fh;
# создать RESOURCES.conf

if (!open $fh, ">", "$dir/RESOURCES.conf") {
	die "can't open file $dir/RESOURCES.conf for reading";
}
print $fh "RES ap IVANOV-II group Client3k inet 192.168.0.1/30 lan 10.1.1.0/24-192.168.0.2";
print $fh "RES ap IVANOV-II connected 192.168.0.5/30";
print $fh "RES SYDOROV-SS group CoNet inet 192.168.0.9/30";
close $fh;

my @conf_set = (
	"$dir/SWITCHES.conf",
	"$dir/AP_LINK.conf",
	"$dir/RESOURCES.conf",
);

my $config_file = Config::File->new(@conf_set);
