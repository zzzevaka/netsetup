#!?usr/bin/perl
# Тесты для пакета Looger

use lib ($ENV{'HOME'} . '/Dropbox/Autoadmin1/lib');
use strict;
use warnings;
use Test::More;
use Data::Dumper;

use Test::More qw(no_plan);

# подключение модуля
use_ok('Logger');
# инициализация логгера
mkdir('/tmp/log');

my $logger = Logger::logger_init(
                            STDERR =>1,
                            LEVEL => 'DEBUG3',
                            LOG_DIR_BASE => '/tmp/log/',
                            LOG_DIR_TREE => 'test1/test2/logfile.log',
                                    );

my $logger2 = Logger::logger_init(
                            STDERR =>1,
                            LEVEL => 'DEBUG2',
                            LOG_DIR_BASE => '/tmp/log/',
                            LOG_DIR_TREE => 'test1/test2/logfile.log',
                                    );

ok ($logger eq $logger2);

ok ($logger->info('message'));
ok ($logger->error('error'));
ok ($logger->debug('debug'));
ok ($logger->debug2('debug2'));
ok ($logger->debug3('debug3'));
