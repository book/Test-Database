use strict;
use warnings;
use Test::More;
use Test::Database;
use Test::Database::Driver;

my @drivers = Test::Database->all_drivers();

plan tests => @drivers * ( 1 + 2 * 8 ) + 1;

my $base = 'Test::Database::Driver';

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

        my $desc = "$name driver";
        isa_ok( $driver, $class, $desc );
        is( $driver->name(), $name, "$desc has the expected name()" );
        my $dir = $driver->base_dir();
        ok( $dir,    "$desc has a base_dir(): $dir" );
        ok( -d $dir, "$desc base_dir() is a directory" );
        my $version;
        ok( eval { $version = $driver->version() },
            "$desc has a version(): $version"
        );
        isa_ok( $version, 'version', "$desc version()" );
        diag $@ if $@;
        isa_ok( $driver->drh(), 'DBI::dr', "$desc drh()" );
        ok( $driver->dsn(), "$desc has a dsn()" );
    }
}

$base->cleanup();
ok( ! -d $base->base_dir(), "removed " . $base->base_dir() );

