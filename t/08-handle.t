use strict;
use warnings;
use Test::More;
use Test::Database::Handle;
use List::Util qw( sum );

my $driver = bless {}, 'Test::Database::Driver::Zlonk';

my @tests = (

    # args, expected result, error regex
    [ [], undef, qr/^driver argument required/ ],
    [ [ driver => $driver ], undef, qr/^dsn argument required/ ],
    [   [ driver => $driver, dsn => 'dbi:SQLite:dbname=zlonk' ],
        undef, qr/^name argument required/
    ],
    [   [   driver => $driver,
            dsn    => 'dbi:SQLite:dbname=zlonk',
            name   => 'zlonk'
        ],
        {   dsn      => 'dbi:SQLite:dbname=zlonk',
            username => '',
            password => '',
            driver   => $driver,
            name     => 'zlonk',
        }
    ],
);
my @attr = qw( dsn username password driver );

plan tests => sum map { $_->[2] ? 1 : 1 + @attr } @tests;

for my $t (@tests) {
    my ( $args, $expected, $err ) = @$t;

    my $got = eval { Test::Database::Handle->new(@$args) };
    my $call = "Test::Database::Handle->new( "
        . join( ', ', map {"'$_'"} @$args ) . " )";

    if ($@) {
        like( $@, $err, "Expected error message for $call" );
    }
    else {
        isa_ok( $got, 'Test::Database::Handle' );
        is( $got->$_, $expected->{$_}, "$_ for $call" ) for @attr;
    }
}

