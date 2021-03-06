#!/usr/local/env perl
# класс, описывающий физический сетевой интерфейс

# Класс физического сетевого интерфейса
package NetSetup::NetIf::Physical; {

	use FindBin;
	use lib "$FindBIN::RealBin/../lib";

	use strict;
	use warnings;

	# наследование базового класса и интерфейса взаимодействия с системой
	use base qw/NetSetup::NetIf::BaseIface
				NetSetup::NetIf::CMD::FreeBSD::ForPhysical/;
}

1;

