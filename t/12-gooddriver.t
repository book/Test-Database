package Test::Database::Driver::Good;
use strict;
use warnings;
use Test::More;

use Test::Database::Driver;
our @ISA = qw( Test::Database::Driver );

sub create_database {
    my ( $class, $dbname ) = @_;
    return Test::Database::Handle->new( dsn => "dbi:Good:$dbname" );
}

sub start_engine {
    ok( 1, 'start_engine() called' );
    return 'WRITE';
}

sub stop_engine {
    my ( $class, $info ) = @_;
    is( $info, 'WRITE', 'stop_engine() got the correct $info' );
}

$INC{'Test/Database/Driver/Good.pm'} = 1;    # yes, we loaded it!

package main;

use strict;
use warnings;
use Test::More;
use Test::Database;

plan tests => 3;

my $handle = Test::Database->handle('Good');

isa_ok( $handle, 'Test::Database::Handle' );

