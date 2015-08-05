#!/usr/bin/env perl

package NetSetup::NetIf::CMD::FreeBSD::ForPhysical; {

	use FindBin;
	use lib "$FindBin::RealBin/../lib";

	use strict;
	use warnings;
	use Net::Netmask;
	use Switch;
	use Data::Dumper;
	use NetSetup::Valid_ip;
	use NetSetup::Logger;
	use NetSetup::CMD::CMD_Base;

	# получиение объекта логгера. Если он не был инициализирован ранее, выкинуть ошибку
	my $logger = get_logger_obj() or die "logger isn't initialized";

	# внешние команды
	my $IFCONFIG = '/sbin/ifconfig';
	my $VTYSH = 'vtysh';
	my $ROUTE = '/sbin/route';
	my $IPACC = 'ipacc';
	
	# Конструктор класса
	# Синтаксис:
	#	my $class_obj = SystemInterface::FreeBSD::ForPhysical->new(NAME => 'em0');
	# Вход:
	# 	хэш. обязательный ключ - IFACE (имя интерфейса)
	# Выход:
	#	ссылка на объект класса
	#	0: ошибка
	sub new {
		my $class = shift;
		my %arg = @_;
		$logger->debug("called ${class} construcor");
		if (!defined($arg{'NAME'})) {
			$logger->error("An incorrect argument");
			return 0;
		}
		# объект класса
		my $self = {
			NAME => $arg{'NAME'},
		};
		bless $self, $class;
	}
	
	# удаление маршрута
	sub route_delete {
		my $self = shift;
		my $return_code = 1;
		foreach my $subnet (@_) {
			if (ref($subnet) eq 'ARRAY') {
				$logger->debug3("ref to array. recoursion");
				$self->route_delete(@$subnet);
			}
			else {
				if (!valid_subnet($subnet)) {
					$logger->error("invalid subnet ${subnet}");
					return 0;
				}
				my $CIDR = new Net::Netmask ($subnet);
				if (!$CIDR) {
					$logger->error("invelid CIDR ${CIDR}");
					return 0;
				}
				if (!exec_cmd("${ROUTE} delete ${CIDR}")) {
					$return_code = 0;
				}
			}
		}
		return $return_code;
	}
	
	# up интерфейса
	# Синтаксис:
	#	$class_obj->up_iface(CONNECTED => [10.1.1.1/30, 192.168.1.1/24])
	#	$class_obj->up_iface(CONNECTED => '192.168.1.1/30')
	#	$class_obj->up_iface(CONNECTED => ..., LAM => ..., GROUP => ...)
	# Вход:
	#	значениями может быть скаляр или ссылка на массив
	# Выход:
	#	1: интерфейс создан
	#	0: ошибка
	sub up_iface {
		my $self = shift;
		# поднимаем интерфейс
		my @cmd_output = exec_cmd("${IFCONFIG} " . $self->{'NAME'} . " up");
		# если не поднялся, выйти с ошибкой
		if (!$cmd_output[0]) {
			$logger->error("coldn't create ". $self->{'NAME'} ." :\n@cmd_output");
			return 0;
		}
		# включаем ipacc
		@cmd_output = exec_cmd("${IPACC} output on int " . $self->{'NAME'});
		if (!shift @cmd_output) {
			$logger->error("coldn't create ". $self->{'NAME'} ." :\n@cmd_output");
		}		
		# поднимаем ресурсы, если они были объявлены
		$self->up_connected($self->{'CONNECTED'}) if @{$self->{'CONNECTED'}};
		$self->up_lan($self->{'LAN'}) if @{$self->{'LAN'}};
		$self->up_group($self->{'GROUP'}) if @{$self->{'GROUP'}};
		# даже если некоторые ресурсы не поднялись, вернуть 1, т.к. в целом интерфйес создан
		return 1;
	}
	
	# down интерфейса
	# Синтаксис:
	#	$class_obj->down_iface(CONNECTED => ..., LAN => ..., GROUP => ...);
	#	$class_obj->down_iface();
	# Вход:
	# Выход:
	#	см. NetSetup::CMD::exec_cmd
	sub down_iface {
		my $self = shift;
		down_connected($self->{'CONNECTED'}) if @{$self->{'CONNECTED'}};
		down_lan($self->{'LAN'}) if @{$self->{'LAN'}};
		down_group($self->{'GROUP'}) if @{$self->{'GROUP'}};
		return exec_template {"$IFCONFIG " . $self->{'NAME'} . " down"}
	}
	
	# поднят ли интерфейс?
	sub is_up {
		my $self = shift;
		return scalar exec_template {"$IFCONFIG $_"} $self->{'NAME'};
	}
	
	# функции для настройки/снятия ресурсов
	# Синтаксис:
	#	$class_obj->up_connected("192.168.1.1/30");
	#	$class_obj->down_group(["Client3k", "CoNet"]);
	#	$class_obj->up_lan("192.168.1.0/29-10.10.10.10");
	# Вход:
	#	скаляр, массив или ссылка на массив
	# Выход:
	#	см. выход exec_template
	sub up_connected {
		my $self = shift;
		$self->route_delete(@_);
		return exec_template {"${IFCONFIG} " . $self->{'NAME'} . " inet $_ alias"} @_;
	}
	sub up_lan {
		my $self = shift;
		return exec_template {"${VTYSH} -c 'conf t' -c 'ip route " . join (' ', split /-/) . "' -c 'end'"} @_;
	}
	sub up_group {
		my $self = shift;
		return exec_template {"${IFCONFIG} " . $self->{'NAME'} . " group $_"} @_;
	}
	sub down_connected {
		my $self = shift;
		return exec_template {"${IFCONFIG} " . $self->{'NAME'} . " -alias " . (split /\//)[0]} @_;
	}
	sub down_lan {
		my $self = shift;
		return exec_template {"${VTYSH} -c 'conf t' -c 'no ip route " . join (' ', split /-/) . "' -c 'end'"} @_;
	}
	sub down_group {
		my $self = shift;
		return 1 if !@_;
		return exec_template {"${IFCONFIG} " . $self->{'NAME'} . " -group $_"} @_;
	}
	
	# универсальная функция, которая вызывает остальные.
	# не подойдет, если вернуть нужно STDOUT команды
	# Вход:
	#	хэш, в котром возможны ключи:
	#		UP_CONNECTED, UP_LAN, UP_GROUP
	#		DOWN_CONNECTED, DOWN_LAN, DOWN_GROUP
	#	значением может быть скаляр или ссылка на массив
	# Выход:
	#	1: норма
	#	0: ошибка
	sub config_resource {
		my $self = shift;
		my %arg = shift;
		my $return_code_inside = undef;
		my $return_code_outside = 1;
		# пройтись по всем переданным аргументам
		while (my ($key, $val) = each %arg) {
			# пропустить если не определно имя ресурса или значение
			next if (!defined($key) || !defined($val));
			# выбрать и выполнить действие
			switch ($key) {
				case 'UP_CONNECTED'		{$return_code_inside = $self->up_connected($val)}
				case 'UP_LAN'			{$return_code_inside = $self->up_lan($val)}
				case 'UP_GROUP'			{$return_code_inside = $self->up_group($val)}
				case 'DOWN_CONNECTED'	{$return_code_inside = $self->down_connected($val)}
				case 'DOWN_LAN'			{$return_code_inside = $self->down_lan($val)}
				case 'DOWN_GROUP'		{$return_code_inside = $self->down_group($val)}
				else 					{$logger->error("unknown value: $key")}
			# если действие неудачно, подменить возвращемое значение
			}
			$return_code_outside = 0 if !$return_code_inside;
		}
		return $return_code_outside;
	}
}

1;
