#!/usr/bin/env perl

package NetSetup::NetIf::CMD::FreeBSD::ForVlan; {

	use strict;
	use warnings;
	use NetSetup::Logger;
	use NetSetup::NetIf::CMD::Base;
	my $logger = get_logger_obj() || logger_init();

	#наследование класса
	use base qw/NetSetup::NetIf::CMD::FreeBSD::ForPhysical/;
	
	# внешние команды
	my $IFCONFIG = '/sbin/ifconfig';
	my $VTYSH	= "vtysh";
	
	# Конструктор класса
	# Синтаксис:
	#	my $class_obj = SystemInterface::FreeBSD::ForVlan->new(NAME => 'vlan150', VLAN_TAG => '150', PARENT => 'em0');
	# Вход:
	# 	хэш. обязательный ключ - IFACE (имя интерфейса)
	# Выход:
	#	ссылка на объект класса
	#	0: ошибка
	sub new {
		my $class = shift;
		my %arg = @_;
		$logger->debug("called ${class} construcor");
		if (!defined($arg{'VLAN_TAG'}) || !defined($arg{'PARENT'}) ||
			!$arg{'VLAN_TAG'} || !$arg{'PARENT'}) {
			$logger->error("Incorrect arguments");
			return 0;
		}
		# объект класса
		my $self = $class->SUPER::new(%arg);
		$self->{'VLAN_TAG'} = $arg{'VLAN_TAG'};
		$self->{'PARENT'} = $arg{'PARENT'};
		
		return $self;
	}
	
	# up интерфейса
	# Синтаксис:
	#	$class_obj->down_iface(CONNECTED => ..., LAN => ..., GROUP => ...);
	#	$class_obj->down_iface();
	# Вход:
	# Выход:
	#	1: норма
	#	0: ошибка		
	sub up_iface {
		my $self = shift;
		$logger->debug2("up " . $self->get_name());
		# создаем интерфейс
		if (!exec_cmd ("${IFCONFIG} " . $self->{'NAME'} . " create vlan " . $self->{"VLAN_TAG"} . " vlandev " . $self->{"PARENT"})) {
			return 0;
		}
		# поднимаем ресурсы, если они были объявлены
		$self->up_connected($self->{'CONNECTED'}) if defined($self->{'CONNECTED'});
		$self->up_lan($self->{'LAN'}) if defined($self->{'LAN'});
		$self->up_group($self->{'GROUP'}) if defined($self->{'GROUP'});
		# даже, если часть ресурсов не была настроена, вернуть 1.
		return 1;
	}
	
	# down интерфейса
	# Синтаксис:
	#	$class_obj->down_iface(CONNECTED => ..., LAN => ..., GROUP => ...);
	#	$class_obj->down_iface();
	# Вход:
	# Выход:
	#	1: норма
	#	0: ошибка
	sub down_iface {
		my $self = shift;
		$self->down_lan($self->{'LAN'}) if @{$self->{'LAN'}};
		return scalar exec_cmd("${IFCONFIG} " . $self->{'NAME'} . " destroy")
	}
}

1;
