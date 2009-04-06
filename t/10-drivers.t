use strict;
use warnings;
use Test::More;
use Test::Database;
use Test::Database::Driver;

my @drivers = Test::Database->all_drivers();
Test::Database->cleanup();

plan tests => @drivers * ( 1 + 2 * 13 ) + 2;

my $base = 'Test::Database::Driver';

for my $name ( Test::Database->all_drivers() ) {
    my $class = "Test::Database::Driver::$name";
    use_ok($class);

    for my $t (
        [ eval { $base->new( driver => $name ) }, $base ],
        [ eval { $class->new() }, $class ],
        )
    {
        my ( $driver, $created_by ) = @$t;
    SKIP: {
            skip "Failed to create $name driver with $created_by", 13
                if !$driver;
            diag "$name driver (created by $created_by)";

            # class and name
            my $desc = "$name driver";
            isa_ok( $driver, $class, $desc );
            is( $driver->name(), $name, "$desc has the expected name()" );

            # base_dir
            my $dir = $driver->base_dir();
            ok( $dir, "$desc has a base_dir(): $dir" );
            like( $dir, qr/Test-Database-.*\Q$name\E/,
                "$desc\'s base_dir() looks like expected" );
            if ( $driver->is_filebased() ) {
                ok( -d $dir, "$desc base_dir() is a directory" );
            }
            else {
                ok( !-e $dir, "$desc base_dir() does not exist" );
            }

            # version
            my $version;
            ok( eval { $version = $driver->version() },
                "$desc has a version(): $version"
            );
            isa_ok( $version, 'version', "$desc version()" );
            diag $@ if $@;

            # drh, bare_dsn, username, password, connection_info
            isa_ok( $driver->drh(), 'DBI::dr', "$desc drh()" );
            ok( $driver->bare_dsn(),         "$desc has are_ dsn()" );
            ok( defined $driver->username(), "$desc has a username()" );
            ok( defined $driver->password(), "$desc has a password()" );
            is_deeply(
                [ $driver->connection_info() ],
                [ map { $driver->$_ } qw< bare_dsn username password > ],
                "$desc has a connection_info()"
            );

            # as_string
            my $re = join '',
                map {"$_ = .*\n"} driver => $driver->essentials();
            like( $driver->as_string(), qr/\A$re\z/, "$desc as string" );
        }
    }
}

# get all loaded drivers
@drivers = Test::Database->drivers();
cmp_ok( scalar @drivers, '>=', 1, 'At least on driver loaded' );

# unload them
Test::Database->unload_drivers();
@drivers = Test::Database->drivers();
is( scalar @drivers, 0, 'All drivers were unloaded' );

