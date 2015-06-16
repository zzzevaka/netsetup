#!/usr/bin/perl
# инициализация логгера Log::Log4perl
# Синглетрон. Объект логгера может быть только один. Если логгер уже был инициализирован,
# повторный вызов logger_init вернет первый объект.

package NetSetup::Logger;

use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use Log::Log4perl::Level;
use POSIX qw(strftime);
use File::Basename;
	
BEGIN {
	use Exporter();
	our @ISA = qw(Exporter);
	our $VERSION = 1.00;
	our @EXPORT = qw (
			&logger_init
			&get_logger_obj
	);
}

# переменная, содержащая объект логгера Log::Log4perl::Logger
my $logger_obj = undef;

# анонс еще двух уровней дебага
Log::Log4perl::Logger::create_custom_level("DEBUG2", "DEBUG");
Log::Log4perl::Logger::create_custom_level("DEBUG3", "DEBUG2");

# инициализация логгера
# принимает именованые параметры
# LEVEL - уровень вывода информации. По-умолчанию ERROR
# STDERR - истина, если нужен вывод в stderr
# LOG_DIR_BASE - переопределение $log_dir_base
# LOG_DIR_TREE - переопределение $log_dir_tree
# Выход:
#   объект логгера
#   0: ошибка
sub logger_init {
	# если Logger уже был инициализирован, вернуть его
	if (defined($logger_obj)) {
		return $logger_obj;
	}
	# ициниатор логгера
	#~ my ($package) = caller(0);
	#~ print "log_init package: $package\n";
	# имя программы
	my $program_name = basename($0);
	######################################################
	# время
	######################################################
	my $date = strftime("%F", localtime);
	my $hour = strftime("%H", localtime);
	my $mtime = time;
	######################################################
	# описание папок для хранения логов
	######################################################
	# базовая папка, в которой будут хранится логи
	# может быть переопределна аргументом log_dir_base
	my $log_dir_base = "/tmp/log/";
	# описание дерева, согласно, которому будут создаваться папки и файлы в базовой папке
	# может быть переопределена аргуметом log_dir_tree
	my $log_dir_tree = "${program_name}/${date}/${hour}/${program_name}.${mtime}.log";
	# резервный файл для логирования
	my $reserve_log_file = "/tmp/${program_name}.{mtime}.log";
	######################################################
	# начало
	######################################################
	my %arg = @_;
	# по-умолчанию, вывод только в файл
	my $destination = 'LOGFILE,';
	# уровень логгинга
	my $level = $arg{'LEVEL'} || 'INFO';
	# подуровень дебага
	# вывод в STDERR
	if (defined($arg{'STDERR'}) && $arg{'STDERR'}) {
		$destination .= 'STDERR';
	}
	# определение $log_dir_base
	$log_dir_base = $arg{'LOG_DIR_BASE'} || $log_dir_base;
	# определение log_dir_tree
	$log_dir_tree = $arg{'LOG_DIR_TREE'} || $log_dir_tree;
	# адрес файла для логирования
	my $log_file = __get_logfile($log_dir_base . "/" . $log_dir_tree);
	# если получить адрес файла не удалось, логирование будет вестись в резервный файл
	if (!$log_file) {
		warn("WARNING: Logging to ${reserve_log_file}");
		$log_file = $reserve_log_file;
	}
	# формат вывода. В дебаг режиме будет выводить время, имя функции и сообщение
	# в обычном режиме только сообщение
	my $screen_format = '%m%n';
	if ($level =~ /DEBUG/) {
		$screen_format = '%p %M - %m%n';
	}
	# конфигурация Log::Log4perl
	my $log_conf = "
		log4perl.rootlogger                 = $level,$destination

		log4perl.appender.LOGFILE           = Log::Log4perl::Appender::File
		log4perl.appender.LOGFILE.filename  = ${log_file}
		log4perl.appender.LOGFILE.mode      = append
		log4perl.appender.LOGFILE.layout    = PatternLayout
		log4perl.appender.LOGFILE.layout.ConversionPattern = %r %p %L %M - %m%n
		
		log4perl.appender.STDERR          = Log::Log4perl::Appender::Screen
		log4perl.appender.STDERR.stderr   = 1
		log4perl.appender.STDERR.layout   = PatternLayout
		log4perl.appender.STDERR.layout.ConversionPattern = $screen_format
	";
	# инициализация Log4perl
	if(!Log::Log4perl->init(\$log_conf)) {
		return 0;
	}
	# получение объекта логгера
	$logger_obj = get_logger();
	if (!defined($logger_obj) || !$logger_obj) {
		return 0;
	}
	return $logger_obj;
}

# получить объект логгера
sub get_logger_obj {
	return $logger_obj;
}

# функция создает дерево каталогов согласно переданному пути к файлу
# Вход:
#	полный путь к файлу логирования
# Выход:
#	путь к файлу
# 	0: ошибка
sub __get_logfile {
	my $file_path = shift;
	if (!defined($file_path) || !$file_path) {
		warn("WARNING: incorrect path of file: ${file_path}");
		return 0;
	}
	# удалить лишние разделители, если затесались
	$file_path =~ s/\/\//\//;
	# получить дерево папок без имени файла
	my $full_dir_path = dirname($file_path);
	# получить дерево каталогов, начиная с корня
	# создать дерево папок
	my $stdout = `mkdir -p $full_dir_path 2>&1`;
	# если дерево папок создать не удалось, вернуть ошибку
	if ($?) {
		warn("WARNING: ${stdout}");
		return 0;
	}
	# если удалось создать дерево папок, вернуть полный адрес файла
	return $file_path;
}


1;
