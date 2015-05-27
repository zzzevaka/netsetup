#!/usr/bin/env perl
# компилятор конфигурационных файлов

package NetSetup::ConfigFile::Compiler; {

	use strict;
	use warnings;
	use Data::Dumper;
	use NetSetup::Logger;

	my $logger = get_logger_obj() || logger_init();

	# конструктор класса
	# ВХОД:
	# - LINE_TEMPLATES (опционально) - ссылка на хэш
	# - VALUE_TEMPLATES (опционально) - ссылка на хэш
	# ВЫХОД:
	# - объект класса
	# 0: ошибка
	sub new {
		my $class = shift;
		my $self = {};
		my %arg = @_;
		# шаблоны строк по-умолчанию
		$self->{'LINE_TEMPLATES'} = {
			SWITCH		=> "SW dev DEVICE_NAME parent PARENT base BASE_VLAN inet CONNECTED count PORT_COUNT( ignore IGNORE)?",
			AP_LINK		=> "AP_LINK ap AP_NAME dev DEVICE_NAME port PORT",
			RESOURCES	=> "RES ap AP_NAME( group GROUP)?( inet CONNECTED)?( lan LAN)?",
		};
		# шаблоны значений по-умолчанию
		$self->{'VALUE_TEMPLATES'} = {
				DEVICE_NAME	=> '[\w\-]+',
				PARENT		=> '[\da-z]{1,6}',
				BASE_VLAN	=> '\d{1,4}',
				CONNECTED	=> '[\d\.\/,]+',
				PORT_COUNT	=> '\d{1,2}',
				IGNORE		=> '(\d{1,2},?)+',
				GROUP		=> '[\w,]+',
				LAN		=> '[\d\.\/\-,]+',
				AP_NAME		=> '[\w\-]+',
				PORT		=> '\d{1,2}',
		};
		$self->{'SPEC'} = '\?\(\)';
		# разделить данных в конфиге. По-умолачнию пробел
		# получаем данные из аргументов
		# для всех аргументов
		while (my ($k,$v) = each %arg) {
			# если значением аргумента является ссылка на хэш
			if (ref($v) eq 'HASH') {
				# записать его как атрибуты класса
				while (my ($kd,$vd) = each %$v) {
					$self->{$k}{$kd} = $vd;
				}
			}
		}
		# для всех шаблонов
		while (my ($kl,$vl) = each %{$self->{'LINE_TEMPLATES'}}) {
			# для всех значений в шаблонах
			$self->{'REGEXP'}{$kl} = $vl;
			foreach (split / /, $vl) {
				# удалить специальные символы
				s/[$self->{'SPEC'}]//g;
				# заменить значения в шаблонах регулярными выражениями
				if (defined($self->{'VALUE_TEMPLATES'}{$_})) {
					$self->{'REGEXP'}{$kl} =~ s/$_/(?<$_>$self->{'VALUE_TEMPLATES'}{$_})/g;
				}
			}
		}
		bless $self,$class;
		$logger->debug3(Dumper $self);
		return $self;
	}
	
	# компиляция переданной строки
	# ВХОД:
	# - строка
	# - ожидаемый тип (опционально).
	# ВЫХОД:
	# - ссылка на хэшБ в котором ключ - тип строки, данные - скомпилированные данные
	# - 0: ошибка
	#
	# Если передан ожидаемый тип, строка сравнивается только с шаблоном этого типа.
	# Иначе сравнивается со всеми шаблонами
	sub compile_line {
		my $self = shift;
		my $line = shift;
		my $expected_type = shift;
		my %match = ();
		# если строка пуста или является комментарием - вернуть undef
		if (!defined ($line) || !$line || $line =~ m/^#.*/) {
			$logger->debug3("empty or a comment");
			return 0;
		}
		# удалить лишние разделители
		$line =~ s/ +/ /g;
		while (my ($type, $template) = each %{$self->{'REGEXP'}}) {
			# если был определен ожидаемый тип
			if (defined($expected_type) && $expected_type ne $type) {
				$logger->debug3("skpip ${type}");
				next;
			}
			my $template_without_modif = $self->{'LINE_TEMPLATES'}{$type};
			$template_without_modif =~ s/[$self->{'SPEC'}]//g;
			# если совпало в шаблоном
			if ($line =~ m/$template/i) {
				$logger->debug2("${line} is a ${type} (${template})");
				$match{$type} = {};
				foreach (split / /, $template_without_modif) {
					if (defined($+{$_}) && $+{$_}) {
						$logger->debug3($_ . ' == ' . $+{$_});
						$match{$type}->{$_} = $+{$_};
					}
				}
			}
			else {
				$logger->debug3("${line} isn't a ${type}");
			}
		}
		$logger->debug3(Dumper(\%match));
		%match ? return \%match : return 0;
	}

}

1;
