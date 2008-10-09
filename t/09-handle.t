use strict;
use warnings;
use Test::More;
use Test::Database::Handle;

my @tests = (
    [ [], undef, qr/^dsn argument required/ ],
    [   [qw( dsn dbi:SQLite:dbname=zlonk )],
        bless(
            {   dsn      => 'dbi:SQLite:dbname=zlonk',
                username => '',
                password => '',
                driver   => 'SQLite',
            }
        ),
        'Test::Database::Handle'
    ],
);

plan tests => scalar @tests;

for my $t (@tests) {
    my ( $args, $expected, $err ) = @$t;

    my $got = eval { Test::Database::Handle->new(@$args) };
    my $call = "Test::Database::Handle->new( "
        . join( ', ', map {"'$_'"} @$args ) . " )";

    if ($@) {
        like( $@, $err, "Expected error message for $call" );
    }
    else {
        is_deeply( $got, $expected, "Expected object for $call" );
    }
}

