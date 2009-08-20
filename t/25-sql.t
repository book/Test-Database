use strict;
use warnings;
use Test::More;
use File::Spec;

use Test::Database;

my @drivers = Test::Database->drivers();

plan skip_all => 'No drivers available for testing' if !@drivers;

# some SQL statements to try out
my @sql = (
    q{CREATE TABLE users (id INTEGER, name VARCHAR(64))},
    q{INSERT INTO users (id, name) VALUES (1, 'book')},
    q{INSERT INTO users (id, name) VALUES (2, 'echo')},
);
my $select = "SELECT id, name FROM users";
my $drop   = 'DROP TABLE users';

plan tests => ( 1 + ( 3 + @sql + 1 ) * 2 + 1 + 2) * @drivers;

for my $driver (@drivers) {
    my $drname = $driver->name();
    diag "Testing driver $drname " . $driver->version();
    isa_ok( $driver, 'Test::Database::Driver' );

    my $count = 0;
    my $old;
    for my $request (
        $drname,
        { dbd => $drname },
        )
    {

        # database handle to a database (created by the driver)
        my ($handle) = Test::Database->handles($request);
        my $dbname = $handle->{name};
        isa_ok( $handle, 'Test::Database::Handle', "$drname $dbname" );

        # check we always get the same database, when it's created
        is( $dbname, $old, "Got db $old again" ) if $old;
        $old ||= $dbname;

        # do some tests on the dbh
        my $desc = "$drname($dbname)";
        my $dbh  = $handle->dbh();
        isa_ok( $dbh, 'DBI::db' );

        # create some information
        ok( $dbh->do($_), "$desc: $_" ) for @sql;

        # check the data is there
        my $lines = $dbh->selectall_arrayref($select);
        is_deeply(
            $lines,
            [ [ 1, 'book' ], [ 2, 'echo' ] ],
            "$desc: $select"
        );

        # remove everything
        ok( $dbh->do($drop), "$desc: $drop" );
    }

    ok( grep ( { $_ eq $old } $driver->databases() ),
        "Database $old still there" );
    $driver->drop_database($old);
    ok( !grep ( { $_ eq $old } $driver->databases() ),
        "Database $old was dropped" );
}

