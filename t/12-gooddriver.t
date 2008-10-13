package Test::Database::Driver::Good;
use strict;
use warnings;
use Test::More;

use Test::Database::Driver;
our @ISA = qw( Test::Database::Driver );

__PACKAGE__->init();

sub setup_engine {
    ok( 1, 'setup_engine() called' );
    return 'INITIALLY';
}

sub start_engine {
    my ( $class, $config ) = @_;
    is( $config, 'INITIALLY',
        'start_engine() got the configuration information' );
    return 'WRITE';
}

sub stop_engine {
    my ( $class, $info ) = @_;
    is( $info, 'WRITE', 'stop_engine() got the startup information' );
}

sub create_database {
    my ( $class, $config, $dbname ) = @_;

    is( $config, 'INITIALLY',
        'create_database() got the configuration information' );
    is( $dbname, 'dbname', 'create_database() got the database name' );

    return Test::Database::Handle->new( dsn => "dbi:Good:$dbname" );
}

$INC{'Test/Database/Driver/Good.pm'} = 1;    # yes, we loaded it!

package main;

use strict;
use warnings;
use Test::More;
use Test::Database;

plan tests => 7;

ok( -d Test::Database::Driver::Good->base_dir(), 'base_dir() created' );

my $handle = Test::Database->handle( Good => 'dbname' );
isa_ok( $handle, 'Test::Database::Handle' );

