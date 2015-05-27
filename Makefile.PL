#!/usr/bin/enc perl

use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
	AUTHOR       => 'L.Maksimov, maksimov@rmt.ru',
	NAME         => 'NetSetup',
	NO_META      => 1,
	EXE_FILES    => ['bin/netsetup'],	
	PREREQ_PM    => {
		"Log::Log4perl"	=> 0,
		"Net::Netmask"  => 0,
	}
);
