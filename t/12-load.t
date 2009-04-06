use strict;
use warnings;
use Test::More;
use Test::Database;
use File::Spec;

my @good = (
    {   password => 's3k r3t',
        driver   => 'mysql',
        host     => 'localhost',
        username => 'root'
    },
    { driver => 'SQLite' },
    { driver => 'CSV' },
);

plan tests => 2 + @good + 2;

# unload all drivers
Test::Database->unload_drivers();
is( scalar Test::Database->drivers(), 0, 'No drivers loaded' );

# load a correct file
my $file = File::Spec->catfile(qw< t database.rc >);
my @config = Test::Database::_read_file($file);

is( scalar @config,
    scalar @good, "Got @{[scalar @good]} drivers from $file" );

for my $test (@good) {
    my $args = shift @config;
    is_deeply( $args, $test, "Read args for driver $test->{driver}" );
}

# try to load a bad file
$file    = File::Spec->catfile(qw< t database.bad >);
ok( !eval { Test::Database::_read_file($file); 1 },
    "load_drivers( $file ) failed" );
like(
    $@,
    qr/^Can't parse line at .*, line \d+:\n  <bad format> at /,
    'Expected error message'
);

