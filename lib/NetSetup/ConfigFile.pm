#!/usr/bin/env perl
# класс, поисывающий набор конфигурационных файлов.
# предоставляет интерфейс для коспиляции, сравнения и применения разницы конфигурационных сэтов

package NetSetup::ConfigFile; {

	use strict;
	use warnings;
	use Data::Dumper;
	use Switch;
	use NetSetup::Array_diff;
	use NetSetup::Logger;
	use NetSetup::NetIf::Vlan;
	use NetSetup::ConfigFile::Compiler;
	use overload {
		'""' => \&str,
	};

	my $logger = get_logger_obj() || logger_init();

	# конструктор класса
	# приниммает список конфигурационных файлов
	sub new {
		my $class = shift;
		my %arg = @_;
		# проверка обязательных аргументов
		if (!defined($arg{'FILES'}) || ref($arg{'FILES'}) ne 'ARRAY') {
			$logger->error("required parametr FILES (ref to ARRAY) is missing");
			return 0;
		}
		my $self = {
			# список файлов конфигурации
			FILES => $arg{'FILES'},
			# компилятор
			COMPILER => NetSetup::ConfigFile::Compiler->new(),
			# сюда будут складываться интерфейсы
			IMAGE => {},
			# группы, в которые будут добавлены MGMT интерфейсы коммутаторов
			SW_GROUP => $arg{'SW_GROUP'} || ['CoNet'],
			# количество vlan'ов
			MAX_VLANS => $arg{'MAX_VLANS'} || 4026,
			# максимальное колчиество портов в коммутаторе
			MAX_PORTS => $arg{'MAC_PORTS'} || 48,
		};
		bless $self, $class;
		# компиляция файлов
		if (!$self->compile_files()) {
			return 0;
		}
		$logger->debug3(Dumper $self);
		return $self;
	}
	
	# компиляция всех файлов
	# создание и заполнение ресурсами интерфейсов, описанных в конфиге
	sub compile_files {
		my $self = shift;
		# файловый дескриптор
		my $fh;
		# переменные хранения данных из строк конфига
		my %switch = ();
		my %ap_link = ();
		my %resources = ();
		# получить информацию из файлов
		foreach my $file (@{$self->{'FILES'}}) {
			if (!open ($fh, "<", $file)) {
				$logger->error("can't open ${file} for reading");
				return 0;
			}
			# скомпилировать все строки в файлах
			while (<$fh>) {
				$logger->debug2($_);
				my $line_data = $self->{'COMPILER'}->compile_line($_);
				# если возвращен 0, перейти к следующей строке
				if (!$line_data) {
					$logger->debug2('ignore line');
					next;
				}
				# если строка совпала с несколькими типами данных, ее нельзя интерпретировать однозначно.
				# игнорировать
				if ( (keys %$line_data) > 1) {
					$logger->error("String '$_' is ambiguous. Matched types: " . (keys %$line_data) .
					"\nCheck the data templates. The line has been ignored" );
					next;
				}
				# $data_type - название типа данных, которое было определено компилятором
				# $data - данные, найденные в этой строке
				my ($data_type,$data) = each %$line_data;
				# обработка данных SWITCH
				if ($data_type eq 'SWITCH') {
					# если уже известен такой свич, игнорировать
					if (defined($ap_link{$data->{'DEVICE_NAME'}})) {
						$logger->warning("SWITCH " . $data->{'DEVICE_NAME'} . "has been defined twice");
						next;
					}
					# проверка данных коммутатора
					# не превышено ли максимальное значение портов?
					if ($data->{'PORT_COUNT'} > $self->{'MAX_PORTS'}) {
						$logger->error($data->{'DEVICE_NAME'} . ": max ports == " . $self->{'MAX_PORTS'});
					}
					# не достигнуто ли максимальное значение vlan?
					if ($data->{'BASE_VLAN'} + $data->{'PORT_COUNT'} > $self->{'MAX_VLANS'}) {
						$logger->error($data->{'DEVICE_NAME'} . ": too large value of vlan");
						next;
					}
					$switch{$data->{'DEVICE_NAME'}} = $data;
				}
				# обработка данных AP_LINK
				elsif ($data_type eq 'AP_LINK') {
					# если уже известен AP_LINK для этого AP_NAME, игнрорировать.
					if (defined($ap_link{$data->{'AP_NAME'}})) {
						$logger->warning("AP LINK for " . $data->{'AP_LINK'} . "has been defined twice");
						next;
					}
					$ap_link{$data->{'AP_NAME'}} = $data->{'DEVICE_NAME'} . "#" . $data->{'PORT'};
				}
				# обработка данных RESOURCES
				elsif ($data_type eq 'RESOURCES') {
					# для одной AP может быть несколько строчек, описывающих ресурсы
					# записываем в массив.
					# Если ресурсы для данной точки ранее не встречались, инициализировать массив.
					if (!defined($resources{$data->{'AP_NAME'}})) {
						$resources{$data->{'AP_NAME'}} = [];
					}
					push @{$resources{$data->{'AP_NAME'}}}, $data;
				}
				else {
					$logger->warn("unknown type of data: ${data_type}");
				}
			}
			close $fh;
		}
		$logger->debug2("SWITCHES:\n" . Dumper(\%switch));
		$logger->debug2("AP_LINK:\n" . Dumper(\%ap_link));
		$logger->debug2("RESOURCES:\n" . Dumper(\%resources));
		# подготовка "базы" интерфейсов на основании описания коммутаторов
		while (my ($sw_name, $sw_data) = each %switch) {
			# базовый vlan
			$self->{'IMAGE'}{$sw_name . "#MGMT"} = NetSetup::NetIf::Vlan->new (
				TITLE		=> $sw_name . "#MGMT",
				NAME		=> 'vlan' . $sw_data->{'BASE_VLAN'},
				PARENT		=> $sw_data->{'PARENT'},
				VLAN_TAG	=> $sw_data->{'BASE_VLAN'},
				CONNECTED	=> [split /,/, $sw_data->{'CONNECTED'}],
				GROUP		=> $self->{'SW_GROUP'}
			);
			# если базовый vlan не создался, больше с этим коммутатором ничего не делать
			if (!defined($self->{'IMAGE'}{$sw_name . "#MGMT"}) || !$self->{'IMAGE'}{$sw_name . "#MGMT"}) {
				$logger->error("can't configure ${sw_name}");
				next;
			}
			# создать интерфесы для остальных портов этого коммутатора
			foreach my $port (1..$sw_data->{'PORT_COUNT'}) {
				# пропустить порт, если он игнорируется
				if (defined($sw_data->{'IGNORE'})) {
					if (grep $port == $_, split /,/, $sw_data->{'IGNORE'}) {
						$logger->debug3("ignore port ${sw_name}#${port}");
						next;
					}
				}
				# создать интерфейс
				$logger->debug3("create netif for ${sw_name}#${port}");
				$self->{'IMAGE'}{$sw_name . "#" . $port} = NetSetup::NetIf::Vlan->new(
					TITLE	=> $sw_name . "#" . $port,
					NAME		=> 'vlan' . ($sw_data->{'BASE_VLAN'} + $port),
					PARENT		=> $sw_data->{'PARENT'},
					VLAN_TAG	=> $sw_data->{'BASE_VLAN'} + $port,
				);
			}
		}
		# добавить к интерфейсам ресурсы
		# пройтись по данным AP_LINK и сопоставить с интерфесом маршрутизатора
		while (my ($ap_name, $device_port) = each %ap_link) {
			$logger->debug3("compile resiurces for ${ap_name}");
			#если device - ROUTER, создать физический интерфейс
			if ($device_port =~ m/^ROUTER#(\w*)/i) {
				$self->{'IMAGE'}{$1} = NetSetup::NetIf::Physical->new(
					DESCRIBE	=> $ap_name,
					NAME		=> $1,
				);
			}
			# если клиент подключен в свич, то vlan уже должен быть создан
			# иначе игнорировать эту AP
			if (!defined($self->{'IMAGE'}{$device_port})) {
				$logger->error("Iface for ${ap_name} (${device_port}) doesn't exist. Ignore");
				next;
			}
			# добавить описание к интерфейсу
			$self->{'IMAGE'}{$device_port}->add_describe($ap_name);
			# если AP_LINK описан, а RESOURCES нет, выдать предупреждение и пропустить эту AP
			if (!defined($resources{$ap_name})) {
				$logger->warn("Hasn't found resources for ${ap_name}");
				next;
			}
			# пройтись по всем строкам для данной AP
			foreach my $res_obj (@{$resources{$ap_name}}) {
				$logger->debug3(Dumper $res_obj);
				# пройтись по всем ресурсам в строке
				while (my ($res_type, $res) = each (%$res_obj)) {
					$self->{'IMAGE'}{$device_port}->add_resource_by_type($res_type, [split /,/, $res])
				}
			}
		}
		return 1;
	}
	
	# сравнение со старым конфигом.
	# Вход:
	#	ссылка на старй конфиг (объект того же класса)
	# Выход:
	#	1: норма
	#	0: ошибка
	sub compare_with_old {
		my $self = shift;
		my $old = shift;
		my $return_code = 1;
		# проверка аргументов
		# если сравнение уже производилось, выйти с ошибкой
		if (defined($self->{'DIFF'})) {
			$logger->error('The comparison has been made earlier');
			return 0;
		}
		$self->{'DIFF'} = {
			ADDED => [],
			DELETED => [],
			BOTH => [],
			OLD_OBJ => $old,
			
		};
		# сравнение может происходить только с аналогичным классом
		# с другими классами, даже наследниками, сравнивать нельзя
		if (!defined($old) || ref($old) ne ref($self)) {
			$logger->error("An incorrect argument: 'OLD': ${old}");
			return 0;
		}
		# Сравнить имена интерфейсов в обоих конфигах
		my $diff = array_diff([keys %{$old->{'IMAGE'}}], [keys %{$self->{'IMAGE'}}]);
		$self->{'DIFF'}{'ADDED'} = $diff->{'added'};
		$self->{'DIFF'}{'DELETED'} = $diff->{'deleted'};
		$self->{'DIFF'}{'BOTH'} = $diff->{'both'};
		# сравнить интерфейсы, которые есть в обоих конфигах
		foreach (@{$self->{'DIFF'}{'BOTH'}}) {
			$self->{'IMAGE'}{$_}->compare_with_old($old->{'IMAGE'}{$_})
		}
		$logger->debug2("BOTH: @{$self->{DIFF}{BOTH}}");
		$logger->debug2("DELETED: @{$self->{DIFF}{DELETED}}");
		$logger->debug2("ADDED: @{$self->{DIFF}{ADDED}}");
		return $return_code;
	}
	
	# получить разницу конфигов
	sub get_diff {
		my $self = shift;
		my @templates = @_ ? @_ : '.+';
		my $template = join '|', @templates;
		my $string = '';
		if (!defined($self->{'DIFF'})) {
			$logger->error("A comparison hasn't been performed");
			return 0;
		}
		# найти удаленные и добавленные интерфейсы
		foreach my $type (qw/DELETED ADDED/) {
			if (@{$self->{'DIFF'}{$type}}) {
				$string .= "--------------------------------\n";
				$string .= "${type}:\n";
				$string .= "--------------------------------\n";
				# для всех интерфейсов в списке
				foreach (@{$self->{'DIFF'}{$type}}) {
					# какую структуру смотрим?
					my $obj = $type eq 'DELETED'
						? $self->{'DIFF'}{'OLD_OBJ'}{'IMAGE'}{$_}
						: $self->{'IMAGE'}{$_};
					# сравнить с шаблоном
					if ($obj->str() =~ m/$template/) {
						$string .= $obj->str();
						$string .= "--------\n";
					}
				}
			}
		}
		# общие интерфейсы
		if (@{$self->{'DIFF'}{'BOTH'}}) {
			$string .= "--------------------------------\n";
			$string .= "CHANGED:\n";
			$string .= "--------------------------------\n";
			foreach (@{$self->{'DIFF'}{'BOTH'}}) {
				my $tmp = $self->{'IMAGE'}{$_}->get_diff();
				$string .= $tmp if $tmp =~ m/$template/;
			}
		}
		$string .= "\n";
		return $string;
	}
	
	# применить разницу конфигов
	sub apply_diff {
		my $self = shift;
		my $return_code = 1;
		if (!defined($self->{'DIFF'})) {
			$logger->error("A comparison hasn't been performed");
			return 0;
		}
		# удалить интерфейсы, которых больше не должно быть
		foreach (@{$self->{'DIFF'}{'DELETED'}}) {
			$logger->debug("delete iface $_");
			# в текущем конфиге такого интерфейса уже нет
			# значит его нужно искать в старом
			if($self->{'DIFF'}{'OLD_OBJ'}{$_}->down_iface()) {
				$logger->error("something wrong at the deleting " . $self->{'DIFF'}{'OLD_OBJ'}{$_}->get_name());
				$return_code = 0;
			}
		}
		# создать новые интерфейсы
		foreach (@{$self->{'DIFF'}{'ADDED'}}) {
			$logger->debug("up iface $_");
			if (!$self->{'IMAGE'}{$_}->up_iface()) {
				$logger->error("something wrong at the configuring " . $self->{'IMAGE'}{$_}->get_name());
				$return_code = 0;
			}
		}
		# применяем изменения в общих интерфейсах
		# сначала удаление, потом добавление
		foreach my $action (qw/DEL ADD/) {
			# для каждого интерфейса
			foreach my $iface (@{$self->{'DIFF'}{'BOTH'}}) {
				$logger->debug2("$action: $iface");
				if (!$self->{'IMAGE'}{$iface}->apply_diff($action)) {
					$logger->error("something wrong at the applying the difference for " . $self->{'IMAGE'}{$iface}->get_name());
					$return_code = 0;
				}
			}
		}
		return $return_code;
	}
	
	# вернуть конфиг строкой
	# ВХОД:
	# 	шаблон (опционально). Если он задан, то вернет только те интерфейсы, в которых произошло совпадение
	# 	иначе вернет все интерфейсы
	sub str {
		my $self = shift;
		my @templates = @_ ? @_ : '.+';
		my $template = join '|', @templates;
		$logger->debug3("template ${template}");
		my $str = '';
		# каждый интерфейс в отсортированном виде
		foreach (sort keys %{$self->{'IMAGE'}}) {
			$logger->debug3("netif $_");

			if ($self->{'IMAGE'}{$_}->str() =~ m/$template/mi) {
				$str .= "--------------------------------\n";
				$str .= $self->{'IMAGE'}{$_}->str();
			}
		}
		return $str;
	}
	
	# содержит ли конфиг какие-нибудь данные?
	sub is_empty {
		my $self = shift;
		return %{$self->{'IMAGE'}} ? 0 : 1;
	}
}

1;
