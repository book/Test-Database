use strict;
use warnings;
use Test::More;
use Test::Database;

my %drivers = map { $_ => '' } my @drivers = Test::Database->drivers();

plan tests => 1 + 2 * ( my $drivers = keys %drivers );

is( scalar Test::Database->handles(),
    $drivers, "Got $drivers handles (@drivers) " );

for my $handle ( Test::Database->handles() ) {
    my $driver = $handle->driver();
    ok( exists $drivers{$driver}, "Handle for $driver" );
    isa_ok( $handle, 'Test::Database::Handle' );
}

