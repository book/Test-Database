#!perl -T

use Test::More;

my @modules = qw(
	Test::Database
	Test::Database::Handle
	Test::Database::Driver
);

plan tests => scalar @modules;

use_ok( $_ ) for @modules;

diag( "Testing Test::Database $Test::Database::VERSION, Perl $], $^X" );

