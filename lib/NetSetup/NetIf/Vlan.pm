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
		my $spec =	"PARENT: " . $self->{'PARENT'} . "\n" .
				"VLAN TAG: " . $self->{'VLAN_TAG'} . "\n";
		my $string = $self->SUPER::str($spec);
		return $string;
	}
	
	# перегрузка метода базового класса
	sub apply_diff {
		my $self = shift;
		my $action = shift;
		if (!defined($action) || $action !~ /ADD|DEL|ALL/) {
			$logger->error("An incorrect action");
			return 0;
		}
		if (!$self->get_diff()) {
			$logger->debug("nothing to do");
			return 1;
		}
		if ($action =~ m/ALL|DEL/) {
			# если у интерфейса изменилось имя или родительский интерфейс, его необходимо
			# рестартовать полностью. удалить интерфейс
			if ($self->{'DIFF'}{'PARENT'}{'changed'} || $self->{'DIFF'}{'NAME'}{'changed'}) {
				$logger->debug("destroy " . $self->{'DIFF'}{'OLD_OBJ'}->get_name());
				# удалить интерфейс
				if (!$self->{'DIFF'}{'OLD_OBJ'}->down_iface()) {
					$logger->error("comething wrong at the deleting " . $self->{'DIFF'}{'OLD_OBJ'}->get_name());
				}
			}
			# иначе вызвать метод базового класса
			else {
				$self->SUPER::apply_diff('DEL');
			}
			# если требуется только удалить, выходим
			return 1 if $action =~ /DEL/;
		}
		# добавить
		return $self->SUPER::apply_diff('ADD');
	}
}

1;
