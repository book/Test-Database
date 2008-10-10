use strict;
use warnings;
use Test::More;
use Test::Database qw( :all );

my @methods = qw( handle dbh );

plan tests => 4 * @methods;

for my $method (@methods) {

    # direct class call
    ok( !eval { Test::Database->$method( Zapeth => 'test' ); 1 },
        "$method: 'Zapeth' driver unknown" );
    like(
        $@,
        qr{^Can't locate Test/Database/Driver/Zapeth.pm in \@INC },
        'Expected error message'
    );

    # exported method call
    ok( !eval "test_db_$method( Zapeth => 'test' ); 1",
        "test_db_$method: 'Zapeth' driver unknown"
    );
    like(
        $@,
        qr{^Can't locate Test/Database/Driver/Zapeth.pm in \@INC },
        'Expected error message'
    );

}

