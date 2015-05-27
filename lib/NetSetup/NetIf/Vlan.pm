#!/usr/bin/env perl

# класс, описывающий vlan. Наследуется от NetworkInterface
package NetSetup::NetIf::Vlan; {

	use strict;
	use warnings;
	use Data::Dumper;
	use NetSetup::Logger;

	my $logger = get_logger_obj() || logger_init();

	# наследование базового класса и интерфейса взаимодействия с системой
	use base qw/NetSetup::NetIf::Base
				NetSetup::NetIf::CMD::FreeBSD::ForVlan/;

	# перегрузка конструктора базового класса
	sub new {
		my $class = shift;
		my %arg = @_;
		# для vlana обязательно наличие perent-интерфейса и тэга vlan'a
		if (!defined($arg{'VLAN_TAG'}) || $arg{'VLAN_TAG'} !~ m/\d+/) {
			$logger->error("incorrect vlan tag value");
			return 0;
		}
		if (!defined($arg{'PARENT'}) || !$arg{'PARENT'}) {
			$logger->error("incorrect parent");
		}
		# вызов конструктора базовго класса
		my $self = $class->NetSetup::NetIf::Base::new(@_);
		$self->{'PARENT'} = $arg{'PARENT'};
		$self->{'VLAN_TAG'} = $arg{'VLAN_TAG'};

		return $self;
	}
	# перегрузка метода базового класса
	sub str {
		my $self = shift;
		my $string = $self->SUPER::str();
		$string .= "PARENT: " . $self->{'PARENT'} . "\n";
		$string .=  "VLAN TAG: " . $self->{'VLAN_TAG'} . "\n";
		return $string;
	}
}

1;
