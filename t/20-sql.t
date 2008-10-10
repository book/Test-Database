use strict;
use warnings;
use Test::More;
use Test::Database;

my @drivers = Test::Database->drivers();

# som
my @sql = (
    q{CREATE TABLE users (id INTEGER, name CHAR(64))},
    q{INSERT INTO users (id, name) VALUES (1, 'book')},
    q{INSERT INTO users (id, name) VALUES (2, 'echo')},
);
my $select = "SELECT id, name FROM users";
my $drop   = 'DROP TABLE users';

plan tests => ( 3 + @sql ) * @drivers;

for my $driver (@drivers) {

    my $dbh = Test::Database->dbh( $driver => 'test' );
    isa_ok( $dbh, 'DBI::db' );

    # create some information
    ok( $dbh->do($_), "$driver: $_" ) for @sql;

    # check the data is there
    my $lines = $dbh->selectall_arrayref($select);
    is_deeply( $lines, [ [ 1, 'book' ], [ 2, 'echo' ] ], "$driver: $select" );

    # remove everything
    ok( $dbh->do($drop), "$driver: $drop" );
}

