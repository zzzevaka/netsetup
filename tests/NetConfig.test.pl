use lib ($ENV{'HOME'} . '/Dropbox/Autoadmin1/lib');
use strict;
use warnings;
use Data::Dumper;
use Logger;

use Test::More qw(no_plan);

logger_init(LEVEL => 'DEBUG', STDERR => 1);


use_ok ('NetConfig');
print "TESTING CONSTRUCTOR:\n";
my $conf = NetConfig->new();
ok(ref($conf) eq 'NetConfig', "A simple constructor");
print "TESTING compile_file_set():\n";
