#!/usr/local/env perl
use lib ($ENV{'HOME'} . '/Dropbox/Autoadmin1/lib');
use strict;
use Test::More qw(no_plan);
use Data::Dumper;

BEGIN {
	use Logger;
	logger_init(STDERR => 1, LEVEL => 'ERROR');
}

use_ok("NetIf::Physical");
use_ok("NetIf::Vlan");

my $vlan102 = NetIf::Vlan->new(
	DESCRIBE	=> 'SW#2',
	NAME		=> 'vlan102',
	PARENT		=> 'em0',
	VLAN_TAG	=> '102',
	CONNECTED	=> ['192.168.1.1/24'],
);

ok($vlan102 != 0, "vlan constructor 1");
ok($vlan102->add_lan('10.10.10.0/29-192.168.1.2'), 'vlan->add_lan(10.10.10.0/29-192.168.1.2)');
ok($vlan102->add_connected('192.168.1.1/23'), 'vlan->add_connected(192.168.1.1/23)');

my $oldvlan102 = NetIf::Vlan->new(
	DESCRIBE	=> 'SW#2',
	NAME		=> 'vlan102',
	PARENT		=> 'em1',
	VLAN_TAG	=> '102',
	CONNETED	=> ['192.168.1.1/23'],
);

ok($vlan102->compare_with_old($oldvlan102), '$vlan->comapre_with_old()');
ok($vlan102->{'DIFF'}{'PARENT'}{'changed'}, "IS RIGHT DIFF PARENT COUNT?");
ok($vlan102->{'DIFF'}{'LAN'}{'changed'}, "IS RIGHT DIFF LAN COUNT?");
ok($vlan102->{'DIFF'}{'CONNECTED'}{'changed'}, "IS RIGHT DIFF CONNETED COUNT?");
