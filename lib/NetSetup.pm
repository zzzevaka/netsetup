#!/usr/bin/env perl
# Библиотека, предоставляющая интерфейс управления конфигурационными файлами

package NetSetup; {

	use strict;
	use warnings;
	use Data::Dumper;
	use File::Path qw(make_path remove_tree);
	use File::Copy;
	use File::stat;
	use Digest::MD5;
	use File::Basename;
	use NetSetup::Logger;
	use NetSetup::ConfigFile;
	
	my $logger = get_logger_obj() || logger_init();
	
	# конструктор класса
	# Вход:
	#	или адрес файла с конфигурацией
	#	или ссылка на хэш с конфигурацией
	#	возможные опции и параметры по-умолчанию смотри в инициализации $self конструктора
	# Выход:
	#	объект класса
	#	0: ошибка
	sub new {
		my $class = shift;
		# источник конфига. может быть хэш или адрес файла
		my $config_source = shift;
		# переменная, куда будет записано содержимое конфиг файла
		my %config = ();
		# если источник конфига был объявлен
		if (defined($config_source)) {
			# если источник конфига является сслыкой на хэш - просто записать его
			if (ref($config_source) eq 'HASH') {
				%config = %$config_source;
			}
			# если не хэш, значит файл. попробовать его открыть
			elsif (open(my $FH, "<", $config_source)) {
				# записать все строки в виде хэша
				while (<$FH>) {
					if (m/^(.*)=(.*)$/) {
						$config{$1} = $2;
					}
				}
				close $FH;
			}
			else {
				$logger->warn("config_source is invalid");
				return 0;
			}
		}
		# описание переменных для работы программы
		my $self = {
			# где ищем конфиг
			CONFIG_DIR	=> $config{'CONFIG_DIR'} || '/etc/NetSetup',
			# куда сохраняем последний примененный конфиг
			TMP_DIR		=> $config{'TMP_DIR'} || '/tmp/NetSetup',
			# файлы, составляющие сэт
			FILES		=> $config{'FILES'} || 'SWITCHES.conf,AP_LINK.conf,RESOURCES.conf',
			# имя файла, в который сохраняются хэш суммы файлов
			MD5_F		=> $config{'MD5_F'} || 'checksum.md5',
			# максимальное количество vlan'ов в конфиге
			VLAN_COUNT	=> $config{'VLAN_COUNT'} || 4096,
			# максимальное количество портов в одном коммутаторе
			MAX_PORTS	=> $config{'MAX_PORTS'} || 30,
			# группы, в которые добавляются MGMT vlan'ы
			SW_GROUP	=> $config{'SW_GROUP'} || 'CoNet',
		};
		# массив файлов
		$self->{'FILES'} = [split /,/, $self->{'FILES'}];
		# массив групп
		$self->{'SW_GROUP'} = [split /,/, $self->{'SW_GROUP'}];
		# адрес папки мог быть написан как со слэшом в конце, так и без него.
		# убираем слэш, если он есть в конце
		$self->{$_} =~ s/\/$// for qw/CONFIG_DIR TMP_DIR/;
		# TMP_DIR обязательно должна находиться в /tmp, иначе он не будет удаляться при перезагрузке
		# маршрутизатора.
		if ($self->{'TMP_DIR'} !~ m/^\/tmp/) {
			$logger->fatal('TMP_DIR must be inside /tmp');
			return 0;
		}
		bless $self,$class;
		$logger->debug3(Dumper $self);
		return $self;
	}

	# поиск самого нового файла по шаблону в заданных папках
	# ВХОД:
	# 	шаблон файла. Например, "switches*" или "SWITCHES.conf"
	#	cсылка на массив с адресами директорий, в оторых нужно искать
	#		по-умолчниаю [$self->{'CONFIG_DIR'}, $self->{'TMP_DIR'}]
	# ВЫХОД:
	#	адрес файла
	#	undef: такого файла не найдено
	#	0: ошибка
	sub find_newest_file_by_name {
		my $self = shift;
		my $file_template = shift;
		my $paths = shift || [$self->{'CONFIG_DIR'}, $self->{'TMP_DIR'}];
		my $newest_file;
		# проверка аргументов
		if (!defined ($file_template) || !$file_template) {
			$logger->error("template of file is empty (first arg)");
			return 0;
		}
		if (ref($paths) ne 'ARRAY') {
			$logger->error("paths (second arg) isn't a reference to an array");
			return 0;
		}
		$logger->debug2("searching file by tempalte '${file_template}'");
		# для каждой папки
		foreach my $dir (@$paths) {
			# для всех найденных файлов
			while (<$dir/$file_template*>) {
				$logger->debug2("File found: $_");
				# если это первый найденный файл с начала запуска функции,
				# назначить его новейшим
				if (!defined($newest_file)) {
					$newest_file = $_;
					next;
				}
				# если это не первый, сравнить его с новейшим
				# если найденный новее - значит он новейший (пока)
				if (stat($_)->mtime > stat($newest_file)->mtime) {
					$newest_file = $_;
				}
			}
		}
		if (defined($newest_file)) {
			$logger->debug2("the newest file: ${newest_file}");
			return $newest_file;
		}
		else {
			$logger->warn("the newest file by template ${file_template} hasn't been found");
			return undef;
		}
	}

	# поиск новейшего конфигурационного сэта
	# ВХОД: нет
	# ВЫХОД: массив адресов файлов
	sub find_newest_set {
		my $self = shift;
		my @newest_set = ();
		foreach (@{$self->{'FILES'}}) {
			my $file = $self->find_newest_file_by_name($_);
			if (defined($file)) {
				push @newest_set, $file
			}
		}
		$logger->debug("the newest set: @newest_set");
		return @newest_set;
	}

	# копирование файлов в TMP_DIR
	# после копирования файла создается его хэш сумма и помещается в MD5_F
	# ВХОД:
	#	адреса файлов
	# ВЫХОД:
	#	1: норма
	#	0: ошибка
	sub copy_to_tmp {
		my $self = shift;
		# список файлов
		my @files = @_;
		# если не былы переданы адреса файлов, выйти с ошибкой
		if (!@files) {
			$logger->error("Incorrect arguments");
			return 0;
		}
		$logger->debug("files for a copying to " . $self->{'TMP_DIR'} . ":");
		$logger->debug($_) for @files;
		# проверка прав на чтение файлов
		# без прав на чтение невозможно создать хэш-сумму
		foreach my $filename (@files) {
			if (!-r ($filename)) {
				$logger->error("${filename} isn't readble");
				return 0;
			}
		}
		# Т.к. нужные нам файлы могут быть уже в папке $TMP_DIR, при выполнении программы
		# сначала создаем директорию $TMP_DIR-tmp и сохраняем файлы туда
		# Затем эта папка будет переименована в $TMP_DIR
		#
		# это нужно, т.к. возможна ситуация копирования $TMP_DIR -> $TMP_DIR
		my $tmp_tmp_dir = $self->{'TMP_DIR'} . '-tmp';
		remove_tree($tmp_tmp_dir);
		$logger->debug3("tmp_tmp_dir: ${tmp_tmp_dir}");
		# создать временную папку
		if (!make_path($tmp_tmp_dir)) {
			$logger->error("can't mkdir ${tmp_tmp_dir}");
			return 0;
		}
		$logger->debug3("${tmp_tmp_dir} has been created");
		# файловый дескриптор
		my $fh;
		# файл с хэш-суммами
		my $md5_file = $tmp_tmp_dir . '/' . $self->{'MD5_F'};
		$logger->debug3("md5_file: ${md5_file}");
		# открытие файла на запись
		if (!open($fh, '>', $md5_file)) {
			$logger->error("can't open ${md5_file} for writing ($!)");
			return 0;
		}
		# копируем файлы и записываем хэш-суммы
		foreach my $file_full_path (@files) {
			my $filename = basename($file_full_path);
			$logger->debug3("filename: ${filename} ($file_full_path)");
			if (!copy($file_full_path, $tmp_tmp_dir . '/' . $filename)) {
				$logger->error("can't copy ${file_full_path}");
				return 0;
			}
			$logger->debug3("${file_full_path} has been copied to ${tmp_tmp_dir}}");
			my $md5_sum = get_md5_file($tmp_tmp_dir . '/' . $filename);
			if (!$md5_sum) {
				return 0;
			}
			print $fh $filename . " " . $md5_sum . "\n";
		}
		close $fh;
		# удаление TMP_DIR
		if (-d $self->{'TMP_DIR'}) {
			if (!remove_tree($self->{'TMP_DIR'} . '/')) {
				$logger->error("can't remove " . $self->{'TMP_DIR'} . "($!)");
				return 0;
			}
			$logger->debug2($self->{'TMP_DIR'} . " has been removed");
		}
		# переименование tmp_tmp_dir в TMP_DIR
		if (!(rename $tmp_tmp_dir, $self->{'TMP_DIR'})) {
			$logger->error("can't rename ${tmp_tmp_dir} to " . $self->{'TMP_DIR'});
			return 0;
		}
		$logger->debug2("done");
		return 1;
	}

	# Поиск сохраненного ранее конфига в TMP_DIR
	# В процессе поиска проверяются хэш-суммы. Если они не совпадают,
	# возвращается ошибка.
	# ВЫХОД:
	#	ссылка на хэш с набором файлов
	#	() - конфиг не найден
	#	0 - ошибка
	sub find_in_tmp {
		my $self = shift;
		my @return = ();
		my %md5_check_hash = ();
		my ($filename, $md5sum) = '';
		my $FH_MD5;
		my $tmp_config_hash = {};
		# Существует ли папка $self->{'TMP_DIR'}? Если ее нет, значит и примененного
		# конфига нет. Это нормально, если программа запускается первый раз.
		# Например, при старте маршрутизатора
		if (!-d $self->{'TMP_DIR'} . '/') {
			$logger->debug("$self->{'TMP_DIR'} doesn't exist");
			return ();
		}
		# открытие $MD5_F для чтения
		if (!(open $FH_MD5, "<", $self->{'TMP_DIR'} . '/' . $self->{'MD5_F'})) {
			$logger->error("can't open $self->{'MD5_F'} for reading");
			return 0;
		}
		# изъятие из файла хэш-сумм для файлов и сверка с реальными файлами
		while (<$FH_MD5>) {
			($filename, $md5sum) = split;
			$logger->debug2("$filename => $md5sum");
			my $file_path = $self->{'TMP_DIR'} . '/' . $filename;
			if (get_md5_file($file_path) ne $md5sum) {
				$logger->error("${file_path} has been compromised");
				return 0;
			}
			$logger->debug3("${file_path} has been checked");
			push @return, $file_path;
		}
		close $FH_MD5;
		my $string = "CONFIG FILES BEEN FOUND IN TMP_DIR:\n";
		$string .= "$_\n" for @return;
		$logger->debug2($string);
		return @return;
	}
	
	# получить объекта конфига
	sub get_config_obj {
		my $self = shift;
		return NetSetup::ConfigFile->new(@_);
	}
	
	# Получение md5 хэш-суммы для файла, переданного аргументов
	# ВХОД:
	#   адрес файла
	# ВЫХОД:
	#   md5: норма
	#   0: ошибка
	# ЗАВИСИМОСТИ:
	#   Digest::MD5
	sub get_md5_file {
		my $file = shift;
		my $FH_MD5;
		my $md5;
		$logger->debug3("an argument has been obtained: $file");
		# проверка аргументов
		if (!defined ($file) || !(-r $file) ) {
			$logger->error("$file isn't readble");
			return 0;
		}
		# открытие файла для чтения
		if (!(open $FH_MD5, "<", $file)) {
			$logger->error("can't open file for reading ($!)");
			return 0;
		}
		# получение хэш-суммы
		binmode ($FH_MD5);
		$md5 = Digest::MD5->new->addfile($FH_MD5)->hexdigest;
		$logger->debug2("$file => " . (defined ($md5) ? $md5 : "undef"));
		close $FH_MD5;
		return $md5 || 0;
	}
}

1;
