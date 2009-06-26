use strict;
use warnings;
use Test::More;
use File::Spec;
use Test::Database;

my %handle = (
    mysql1 => Test::Database::Handle->new(
        dsn      => 'dbi:mysql:database=mydb;host=localhost;port=1234',
        username => 'user',
        password => 's3k r3t',
    ),
    mysql2 => Test::Database::Handle->new(
        dsn      => 'dbi:mysql:database=mydb;host=remotehost;port=5678',
        username => 'otheruser',
    ),
    sqlite => Test::Database::Handle->new( dsn => 'dbi:SQLite:db.sqlite', ),
);

my @tests = (

    # request, expected response
    [ [],        [ @handle{qw( mysql1 mysql2 sqlite )} ], '' ],
    [ ['mysql'], [ @handle{qw( mysql1 mysql2 )} ],        q{'mysql'} ],
    [ ['sqlite'], [], q{'sqlite'} ],
    [ ['SQLite'], [ $handle{sqlite} ], q{'SQLite'} ],
    [ ['Oracle'], [], q{'Oracle'} ],
    [   [ 'SQLite', 'mysql' ],
        [ @handle{qw( mysql1 mysql2 sqlite )} ],
        q{'SQLite', 'mysql'}
    ],
    [   [ 'mysql', 'SQLite', 'mysql' ],
        [ @handle{qw( mysql1 mysql2 sqlite )} ],
        q{'mysql', 'SQLite', 'mysql'}
    ],
    [   [ 'mysql', 'Oracle', 'SQLite' ],
        [ @handle{qw( mysql1 mysql2 sqlite )} ],
        q{'Oracle', 'mysql', 'SQLite'}
    ],

);

# reset the internal structures and force loading our test config
my $config = File::Spec->catfile( 't', 'database.rc' );
Test::Database->load_config( $config, 1 );

plan tests => 2 * @tests;

for my $test (@tests) {
    my ( $requests, $responses, $desc ) = @$test;

    # plural form
    my @handles = Test::Database->handles(@$requests);
    is_deeply( \@handles, $responses, "Test::Database->handles( $desc )" );

    # singular form
    my $handle = Test::Database->handle(@$requests);
    is_deeply( $handle, $responses->[0], "Test::Database->handle( $desc )" );
}
