use strict;
use warnings;
use Test::More;
use Test::Database;

plan tests => 2;

ok( !eval { Test::Database->handle( Zapeth => 'test' ); 1 },
    'Zapeth driver unknown' );

like(
    $@,
    qr{^Can't locate Test/Database/Driver/Zapeth.pm in \@INC },
    'Expected error message'
);

