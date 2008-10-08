#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Test::Database' );
}

diag( "Testing Test::Database $Test::Database::VERSION, Perl $], $^X" );
