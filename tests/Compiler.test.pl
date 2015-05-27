use lib ($ENV{'HOME'} . '/Dropbox/Autoadmin1/lib');
use strict;
use warnings;
use Data::Dumper;
use Logger;


use Test::More qw(no_plan);

use_ok("Config::Compiler");
# Конструктор
my $comp = Config::Compiler->new();
ok($comp, "Simple constructor");
$comp = Config::Compiler->new(LINE_TEMPLATES => {TEST => 'TEST TEST'});
ok ($comp->{'LINE_TEMPLATES'}{'TEST'}, "Constructor with LINE_TEMPLATES");
$comp = Config::Compiler->new(VALUES_TEMPLATES => {TEST => '[\w]+'});
ok ($comp->{'VALUES_TEMPLATES'}{'TEST'}, "Constructor with VALUES_TEMPLATES");


my %lines = (
	'SW dev TEST-SW1 parent em0 base 200 inet 10.169.220.1/30 count 16 ignore 1,2,3' => {
		'SWITCH' = {
			DEVICE_NAME		=> 'TEST-SW1',
			PARENT	=> 'em0',
			BASE_VLAN	=> '200',
			CONNECTED	=> '10.169.220.1/30',
			POR_COUNT	=> '16',
			IGNORE	=> '1,2,3',
		}
	}
);
