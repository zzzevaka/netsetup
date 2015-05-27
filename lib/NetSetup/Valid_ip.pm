#!/usr/local/env perl
# проверка ip-данных
#
# Для всех функций:
# Вход:
#	строка
# Выход:
#	1: валидна
#	0: не валидна

package NetSetup::Valid_ip;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our @ISA = qw(Exporter);
	our $VERSION = 1.00;
	our @EXPORT = qw (
			&valid_ip
			&valid_subnet
			&valid_lan
	);
}

# проверка ip-адреса x.x.x.x
sub valid_ip {
	my $ip = shift;
	if (!defined($ip)) {
		return 0;
	}
	if ($ip =~ /^(\d+\.){3}\d+$/ && 4 == grep {$_ <= 255} split /\./, $ip) {
		return 1;
	}
	else {
		return 0;
	}
}

# проверка подсети x.x.x.x/x
# 4-ый октет может быть не только идентфикатором подсети
sub valid_subnet {
	my ($ip, $mask) = split /\//, shift;
	if (!defined($mask)) {
		return 0;
	}
	if (valid_ip($ip) && $mask =~ /^\d{1,2}$/ && $mask <= 32) {
		return 1;
	}
	else {
		return 0;
	}
}

# проверка LAN-подсети x.x.x.x/x-x.x.x.x
sub valid_lan {
	my ($subnet, $via_ip) = split /-/, shift;
	if (!defined($via_ip)) {
		return 0;
	}
	if (valid_subnet($subnet) && valid_ip($via_ip)) {
		return 1;
	}
	else {
		return 0;
	}
}

1;
