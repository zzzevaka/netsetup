#!/usr/local/env perl
# класс, описывающий сетевой интерфейс

# Класс физического сетевого интерфейса
package NetSetup::NetIf::BaseIface; {

	use FindBin;
	use lib "$FindBIN::RealBin/../lib";

	use strict;
	use warnings;
	use Switch;
	use Data::Dumper;
	use NetSetup::Valid_ip;
	use NetSetup::Array_diff;
	use NetSetup::Logger;
	use overload {
		'""' => \&str,
	};
	
	# получиение объекта логгера. Если он не был инициализирован ранее, выкинуть ошибку
	my $logger = get_logger_obj() or die "logger isn't initialized";
	
	# Конструктор
	# Принимает именованные параметры
	# NAME		=> имя интерфейса [обязательный]
	# DESCRIBE	=> произвольное описание
	# CONNECTED	=> IP-подсеть x.x.x.x/x
	# LAN		=> маршрутизируемая IP-подсеть x.x.x.x/x-x.x.x.x
	# GROUP		=> группы
	sub new {
		my $class = shift;
		my %arg = @_;
		#~ $logger->debug("called ${class} construcor");
		# для каждого объекта класса обязательно должно быть определено имя
		if (!defined($arg{'NAME'}) || !$arg{'NAME'}) {
			$logger->error("An incorrect argument '$_'");
			return 0;
		}
		# инициализация объекта
		my $self = {
			RES_SET		=> [qw/DESCRIBE CONNECTED LAN GROUP/],
			TITLE		=> $arg{'TITLE'} || $arg{'NAME'},
			NAME		=> $arg{'NAME'},
			DESCRIBE	=> [],
			CONNECTED	=> [],
			LAN			=> [],
			GROUP		=> [],
		};
		
		bless $self, $class;
		# добавление ресурсов, если они были объявлены
		$self->add_connected($arg{'CONNECTED'}) if defined($arg{'CONNECTED'});
		$self->add_lan($arg{'LAN'}) if defined($arg{'LAN'});
		$self->add_group($arg{'GROUP'}) if defined($arg{'GROUP'});
		$self->add_describe($arg{'DESCRIBE'}) if defined($arg{'DESCRIBE'});

		return $self;
	}
	
	# Добавление ресурса
	# ! предполагается, что метод приватный
	# Вход:
	# 	ссылка на массив или скаляр с значением
	#	тип ресурса (GROUP LAN...)
	#	ссылка на функцию для проверки валидности
	# Выход:
	#	1: норма
	#	0: ошибка
	sub __add_resource {
		my $self = shift;
		# значение
		my $value = shift;
		# тип ресурса
		my $type = shift;
		# ссылка на функцию для проверки значения
		my $check_sub = shift;
		# возвращаемое значение
		my $return_value = 1;
		# проверка аргументов
		if (!defined($value) || !$value ||
			!defined($type) || !defined($self->{$type}) || ref($self->{$type}) ne 'ARRAY') {
		
			$logger->error('incorrect arguments');
			return 0;
		}
		# value - ссылка на массив?
		# если не ссылка, сделать таковой
		# если ссылка, но не на массив - ошибка
		if (ref($value) eq 'ARRAY') {
			$value = $value;
		}
		elsif (!ref($value)) {
			$value = [$value];
		}
		else {
			$logger->error("incorrect value");
			return 0;
		}
		$logger->debug2("TYPE: $type, VALUE: @${value}");
		# записать все значения в ссылке на массив
		foreach my $x (@$value) {
			# если определена функция для проверки значения, проверить
			if (defined($check_sub) && ref($check_sub) eq 'CODE') {
				# если не проходит проверку, пропустить
				if (!&$check_sub($x)) {
					$logger->error("incorrect value ${x} (${type})");
					$return_value = 0;
					next;
				}
			}
			# добавить, если не дубль
			if (!grep $x eq $_, @{$self->{$type}}) {
				push @{$self->{$type}}, $x;
			}
		}
		return $return_value;
	}
	
	# функции для добавления конкретных ресурсов
	sub add_connected {
		my $self = shift;
		return $self->__add_resource(shift, 'CONNECTED', \&valid_subnet);
	}
	sub add_lan {
		my $self = shift;
		return $self->__add_resource(shift, 'LAN', \&valid_lan);
	}
	sub add_group {
		my $self = shift;
		return $self->__add_resource(shift, 'GROUP');
	}
	sub add_describe {
		my $self = shift;
		return $self->__add_resource(shift, 'DESCRIBE');
	}
	
	# еще одна функция для добавления ресурсов
	# ВХОД:
	#	имя ресурса
	#	объект ресурса (см. __add_resource)
	# ВЫХОД:
	#	см. __add_resource
	sub add_resource_by_type {
		my $self = shift;
		my $type = shift;
		if (!defined($type)) {
			$logger->error("resource type hasn't been defined");
			return 0;
		}
		switch ($type) {
			case 'CONNECTED'	{return $self->add_connected(shift)}
			case 'GROUP'		{return $self->add_group(shift)}
			case 'LAN'			{return $self->add_lan(shift)}
			else				{return $logger->debug3("${type} has been ignored")}
		}
	}
	
	# получить описание интерфейса в читаемом виде
	# ВХОД:
	# 	строка, которую нужно вставить между основным описанием и diff
	sub str {
		my $self = shift;
		my $added_str = shift;
		my $string = '';
		$string .= $self->{'NAME'} . ' ' . $self->{'TITLE'} . ":\n";
		foreach my $res (@{$self->{'RES_SET'}}) {
			my @res_array = @{$self->{$res}};
			next if !@res_array;
			$string .= "$res: @res_array\n";
		}
		if (defined($added_str) && $added_str) {
			$string .= $added_str;
		}
		if ($self->get_diff()) {
			$string .= "--DIFF--\n";
			$string .= $self->get_diff();
		}
		return $string;
	}
	
	# получить имя интерфейса
	sub get_name {
		my $self = shift;
		return $self->{'NAME'};
	}
	
	# пуст ли интерфейс?
	# пустым считается интерфейс, если в нем нет никаких ресурсов
	sub is_empty {
		my $self = shift;
		# проверить все ресурсы
		foreach (@{$self->{'RES_SET'}}) {
			# если что-то есть, вернуть 0 - не пуст
			if (@{$self->{$_}}) {
				return 0;
			}
		}
		# вернуть 1 - пуст
		return 1;
	}
	
	# сравнение со старым описанием
	# Вход:
	#	ссылка на объект того же класса
	# Выход:
	#	1: норма
	#	0: ошибка
	sub compare_with_old {
		my $self = shift;
		my $old_iface = shift;
		# проверка аргументов
		# если сравнение уже производилось, выйти с ошибкой
		if (defined($self->{'DIFF'})) {
			$logger->error("The comparison has been made earlier");
			return 0;
		}
		# сравнение может происхлодить только с аналогичным классом
		# с другими классами, даже наследниками, сравнивать нельзя
		if (!defined($old_iface) || ref($old_iface) ne ref($self)) {
			$logger->error("An incorrect argument: 'OLD': ${old_iface}");
			return 0;
		}
		$logger->debug2("comparison: $self->{TITLE}");
		# сравнивание всех ресурсов
		foreach my $res_name (keys %$self) {
			# сравниваем скаляры
			if (!ref($self->{$res_name})) {
				$self->{'DIFF'}{$res_name} = array_diff([$old_iface->{$res_name}], [$self->{$res_name}]);
			}
			# сравниваем ссылки на массивы
			elsif (ref($self->{$res_name}) eq 'ARRAY') {
				$self->{'DIFF'}{$res_name} = array_diff($old_iface->{$res_name}, $self->{$res_name});
			}
			else {
				$logger->warn("${res_name} has been ignored");
			}
		}
		$self->{'DIFF'}{'OLD_OBJ'} = $old_iface;
		return 1;
	}
	
	# получить изменения в читаемом виде
	sub get_diff {
		my $self = shift;
		my @added = ();
		my @deleted = ();
		my $string = '';
		if (!defined($self->{'DIFF'})) {
			return $string
		}
		while (my ($k,$v) = each %{$self->{'DIFF'}}) {
			next if $k eq 'OLD_OBJ';
			$logger->debug3("resource ${k}");
			@added = @{$v->{'added'}};
			@deleted = @{$v->{'deleted'}};
			if (!@added && !@deleted) {
				next;
			}
			$string .= "+ " . $self->{'TITLE'} . " ${k} @added" . "\n" if @added;
			$string .= "- " . $self->{'TITLE'} . " ${k} @deleted" . "\n" if @deleted;
		}
		return $string;
	}
	
	# применить изменения
	# применить изменения
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
		# производим удаление ресурсов
		if ($action =~ m/ALL|DEL/) {
			$self->down_connected($self->{'DIFF'}{'CONNECTED'}{'deleted'});
			$self->down_lan($self->{'DIFF'}{'LAN'}{'deleted'});
			$self->down_group($self->{'DIFF'}{'GROUP'}{'deleted'});
			# если требуется только удалить, выходим
			return 1 if $action =~ /DEL/;
		}
		# если нужно добавить, идем дальше
		# если интерфейс не поднят, создаем его полностью и выходим
		if (!$self->is_up()) {
			$logger->debug("create " . $self->{'NAME'});
			if (!$self->up_iface()) {
				$logger->error("can't up " . $self->get_name());
				return 0;
			}
		}
		# если поднят, добавляем новые ресурсы
		else {
			$self->up_connected($self->{'DIFF'}{'CONNECTED'}{'added'});
			$self->up_lan($self->{'DIFF'}{'LAN'}{'added'});
			$self->up_group($self->{'DIFF'}{'GROUP'}{'added'});
		}
		return 1;
	}
}

1;

