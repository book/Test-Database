use strict;
use warnings;
use Test::More;
use Test::Database;
use Test::Database::Driver;

my @drivers = Test::Database->all_drivers();

plan tests => 1 + @drivers * ( 1 + 2 * 13 );

my $base = 'Test::Database::Driver';
$base->cleanup();
ok( !-d $base->base_dir(), "no base_dir() " . $base->base_dir() );

for my $name ( Test::Database->all_drivers() ) {
    my $class = "Test::Database::Driver::$name";
    use_ok($class);

    for my $t (
        [ $base->new( driver => $name ), $base ],
        [ $class->new(), $class ],
        )
    {
        my ( $driver, $created_by ) = @$t;
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
        ok( -d $dir, "$desc base_dir() is a directory" );

        # version
        my $version;
        ok( eval { $version = $driver->version() },
            "$desc has a version(): $version"
        );
        isa_ok( $version, 'version', "$desc version()" );
        diag $@ if $@;

        # drh, dsn, username, password, connection_info
        isa_ok( $driver->drh(), 'DBI::dr', "$desc drh()" );
        ok( $driver->dsn(), "$desc has a dsn()" );
        ok( defined $driver->username(), "$desc has a username()" );
        ok( defined $driver->password(), "$desc has a password()" );
        is_deeply(
            [ $driver->connection_info() ],
            [ map { $driver->$_ } qw< dsn username password > ],
            "$desc has aconnection_info()"
        );

        # as_string
        my $re = join '', map { "$_ = .*\n" } qw< dsn username password >;
        like( $driver->as_string(), qr/\A$re\n\z/, "$desc as string" );
    }
}

