use strict;
use warnings;
use Test::More;
use Test::Database;
use File::Spec;
use List::Util qw( sum );

my @good = (
    {   password => 's3k r3t',
        driver   => 'mysql',
        host     => 'localhost',
        username => 'root'
    },
    { driver => 'SQLite' },
    { driver => 'CSV' },
);

plan tests => 2 + sum( map { 1 + keys %$_ } @good ) + 2;

# unload all drivers
Test::Database->unload_drivers();
is( scalar Test::Database->drivers(), 0, 'No drivers loaded' );

# load a correct file
my $file = File::Spec->catfile(qw< t database.rc >);
Test::Database->load_drivers($file);

my @drivers = Test::Database->drivers();
is( scalar @drivers,
    scalar @good, "Got @{[scalar @good]} drivers from $file" );

for my $test (@good) {
    my $driver = shift @drivers;
    isa_ok( $driver, "Test::Database::Driver::$test->{driver}" );

    for my $k ( sort keys %$test ) {
        is( $driver->{$k}, $test->{$k}, "$test->{driver} $k" );
    }
}

# try to load a bad file
@drivers = Test::Database->drivers();
$file    = File::Spec->catfile(qw< t database.bad >);

ok( !eval { Test::Database->load_drivers($file); 1 },
    "load_drivers( $file ) failed" );
like(
    $@,
    qr/^Can't parse line at .*, line \d+:\n  <bad format> at /,
    'Expected error message'
);

