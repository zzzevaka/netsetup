#!/usr/bin/env perl

package NetSetup::CMD::Vtysh; {

	use strict;
	use warnings;
	use NetSetup::CMD::CMD_Base;
	
	BEGIN {
	use Exporter();
	our @ISA = qw(Exporter);
	our $VERSION = 1.00;
	our @EXPORT = qw (
		&get_all_lan
		);
	}

	my $VTYSH = 'vtysh';
	
	sub get_all_lan {
		my @list = ();
		# выполнение команды
		@list = exec_cmd("${VTYSH} -c 'sh run' | grep 'ip route'");
		# первый объект в списке - код завершения. он не нужен
		shift @list;
		#обработка строк
		@list = map {
			s/^ip route (.*)/$1/i;
			join '-', split / /;
		} split /\n/, $list[0];
	}

}

1;
