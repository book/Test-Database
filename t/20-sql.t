use strict;
use warnings;
use Test::More;

my @drivers;
my %keeps;
my %drops;

END {
    diag 'Testing autodrop and cleanup';
    for my $driver (@drivers) {
        my $drname = $driver->name();
        my %databases = map { $_ => 1 } $driver->databases();

        # check the 'keep' databases are still here
        is_deeply(
            [ sort grep { $databases{$_} } keys %{ $keeps{$driver} } ],
            [ sort keys %{ $keeps{$driver} } ],
            "Kept databases are there for $drname"
        );

        # check the others have been dropped
        is_deeply( [ grep { $databases{$_} } keys %{ $drops{$driver} } ],
            [], "Drop databases have gone for $drname" );

        # cleanup
        $driver->cleanup();
        %databases = map { $_ => 1 } $driver->databases();
        is_deeply( [ grep { $databases{$_} } keys %{ $keeps{$driver} } ],
            [], "Kept databases have been cleaned up for $drname" );

        # try dropping a non-existing database: shouldn't die
        ok( eval { $driver->drop_database('Test_Database_INEXISTENT'); 1 },
            "dropping an inexistent database doesn't die for $drname"
        );
        diag $@ if $@;
    }

    Test::Database->cleanup();
}

require Test::Database;

@drivers = Test::Database->drivers();

plan skip_all => 'No drivers available for testing' if !@drivers;

# some SQL statements to try out
my @sql = (
    q{CREATE TABLE users (id INTEGER, name CHAR(64))},
    q{INSERT INTO users (id, name) VALUES (1, 'book')},
    q{INSERT INTO users (id, name) VALUES (2, 'echo')},
);
my $select = "SELECT id, name FROM users";
my $drop   = 'DROP TABLE users';

plan tests => ( 1 + ( 3 + @sql + 2 ) * 3 + 4 ) * @drivers;

for my $driver (@drivers) {
    diag "Testing driver " . $driver->name();
    isa_ok( $driver, 'Test::Database::Driver' );

    my $count = 0;
    for my $request (
        $driver->name(),
        { driver => $driver->name(), keep => 1 },
        { driver => $driver->name(), name => 'Test_Database_NAME' },
        )
    {

        my $drname = $driver->name();

        # test handles() with no request
        my $handles = $driver->handles();
        cmp_ok(
            $handles, ( $driver->is_filebased ? '==' : '>=' ),
            $count, "$drname: $handles available (minimum $count)"
        );
        $count++;

        # database handle to a new database
        # FIXME - testing on the first handle only
        my ($handle) = Test::Database->handles($request);

        my $dbname = $handle->name();
        isa_ok( $handle, 'Test::Database::Handle', "$drname $dbname" );

        my $desc = "$drname($dbname)";
        my $dbh  = $handle->dbh();
        isa_ok( $dbh, 'DBI::db' );

        if ( ref($request) && $request->{keep} ) {
            $keeps{$driver}{$dbname}++;
        }
        else {
            $drops{$driver}{$dbname}++;
        }

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
}

