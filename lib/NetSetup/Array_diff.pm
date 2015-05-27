#!/usr/bin/perl
# сравнение двух массивов

package NetSetup::Array_diff;

use strict;
use warnings;
use Switch;

BEGIN {
	use Exporter();
	our @ISA = qw/Exporter/;
	our $VERSION = 1.00;
	our @EXPORT = qw(array_diff);
}

# сравнение двух массивов
# предполагается, что все значения в сравниваемых массивах уникальны
# ВХОД:
#	2 ссылки на массивы
# ВЫХОД:
# 	ссылка на хэш {
#		added => [элементы, которые есть только во втором массиве]
#		deleted => [элементы, которые есть только в первом массиве]
#		both => [элементы, которые есть в обоих массивах]
#		changed => есть ли изменения (1 или 0)
#	}
#	0: ошибка
sub array_diff {
	my $old = shift;
	my $new = shift;
	return 0 if ref($old) ne 'ARRAY' || ref($new) ne 'ARRAY';
	my $diff = {
		changed => 0,
		added => [],
		deleted => [],
		both => [],
	};
	my %seen = ();
	$seen{$_} = 1 foreach @$old;
	foreach (@$new) {
		$seen{$_} = defined $seen{$_}? 0 : 2;
	}
	while (my ($k,$v) = each %seen) {
		switch($v) {
			case 0 {push @{$diff->{'both'}},$k}
			case 1 {push @{$diff->{'deleted'}},$k; $diff->{'changed'} = 1}
			case 2 {push @{$diff->{'added'}},$k; $diff->{'changed'} = 1}
			else {return 0}
		}
	}
	return $diff;
}

1;
