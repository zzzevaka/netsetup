#!/usr/bin/env perl

package NetSetup::NetIf::CMD::Base;

use strict;
use warnings;
use Data::Dumper;
use NetSetup::Logger;
my $logger = get_logger_obj() || logger_init();

BEGIN {
	use Exporter();
	our @ISA = qw(Exporter);
	our $VERSION = 1.00;
	our @EXPORT = qw (
		&exec_cmd
		&exec_template
	);
}
# Выполнение команды
# Вход:
#   строка - команда
# Выход:
#   STDOUT + STDERR || 1 : если код завершения команды == 0
#   0 : если код заврешения команды != 0
sub exec_cmd {
	my $cmd = shift;
	$logger->debug3($cmd);
	my $return_code = 1;
	if (!defined($cmd) || !$cmd) {
		$logger->error("an incorrect argument");
		return 0;
	}
	$cmd .= " 2>&1";
	$logger->debug3($cmd);
	my $stdout = `$cmd`;
	if ($?) {
		$logger->debug("can't execute ${cmd} (" . $? /256 . ")\n${stdout}" );
		$return_code = 0;
	}
	else {
		$logger->debug("successful execute ${cmd}:\nSTDOUT + STDERR:\n${stdout}");
	}
	my @stdout = ($return_code, $stdout);
	return wantarray ? @stdout : $return_code;
}

# Выполнение шаблона команды
# Вход:
# 	exec_template {"ifconfig $_"} "eth1", "eth2"
#	exec_template {"arp -ni $_ -a"} @netif_array
#	exec_template {"arp -ni $_ -a"} "eth1", ["eth2", "eth3"], "eth4"
#	...
# Выход:
#	если ожидается массив - вернется массив:
#		[0] - код завершения (см. если ожидается скаляр)
#		остальное - STDOUT + STDERR
#	если ожидается скаляр:
#		1 : норма
#		0 : не выполнилась одна или более комманд
sub exec_template (&@) {
	my $code = shift;
	my @stdout = ();
	my @exec_cmd_ret = ();
	my $return_code = 1;
	# обработка аргументов
	foreach (@_) {
		# если аргумент является ссылкой на массив - рекурсивный вызов самого себя
		if (ref($_) && ref($_) eq 'ARRAY') {
			my @deep_stdout = &exec_template($code, @{$_});
			if (!shift @deep_stdout) {
				$return_code = 0;
			}
			push @stdout, @deep_stdout;
			next;
		}
		# если аргумент является ссылкой, но не на массив, игнорировать его
		elsif (ref($_)) {
			$logger->error("$_ - what is it?");
			next;
		}
		# выполнение команды
		@exec_cmd_ret = exec_cmd(&$code());
		$return_code = 0 if (!shift @exec_cmd_ret);
		push @stdout, @exec_cmd_ret;
	}
	unshift @stdout, $return_code;
	wantarray ? @stdout : $return_code;
}

1;
