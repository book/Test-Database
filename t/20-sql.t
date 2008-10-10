use strict;
use warnings;
use Test::More;
use Test::Database;

my @drivers = Test::Database->drivers();

# some SQL statements to try out
my @sql = (
    q{CREATE TABLE users (id INTEGER, name CHAR(64))},
    q{INSERT INTO users (id, name) VALUES (1, 'book')},
    q{INSERT INTO users (id, name) VALUES (2, 'echo')},
);
my $select = "SELECT id, name FROM users";
my $drop   = 'DROP TABLE users';

plan tests => ( 4 + @sql ) * 2 * @drivers;

Test::Database->cleanup;

for my $driver (@drivers) {

    for my $dbname ( '', 'test' ) {

        my $dbh = Test::Database->dbh( $driver => $dbname );
        isa_ok( $dbh, 'DBI::db' );

        # create some information
        ok( $dbh->do($_), "$driver($dbname): $_" ) for @sql;

        # check the data is there
        my $lines = $dbh->selectall_arrayref($select);
        is_deeply(
            $lines,
            [ [ 1, 'book' ], [ 2, 'echo' ] ],
            "$driver($dbname): $select"
        );

        # remove everything
        ok( $dbh->do($drop), "$driver($dbname): $drop" );

        # check the dbh is cached
        is( Test::Database->dbh( $driver => $dbname ),
            $dbh, "$driver($dbname): dbh cached" );
    }
}

