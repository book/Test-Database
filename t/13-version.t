use strict;
use warnings;
use Test::More;
use Test::Database;

my @drivers = Test::Database->drivers();
my @some    = (
    { version     => 'x' },
    { min_version => 'x' },
    { max_version => 'y' },
    { version     => 'x', min_version => 'x' },
    { version     => 'x', max_version => 'y' },
    { min_version => 'x', max_version => 'y' },
    { version     => 'x', min_version => 'x', max_version => 'y' },
);

my @none = (
    { min_version => 'y' },
    { max_version => 'x' },
    { version     => 'y' },
    { min_version => 100, max_version => 200 },
    { min_version => 'x', max_version => 'x' },
);

plan tests => 1 + @drivers * ( @some + @none );

is_deeply( [ Test::Database->drivers( map { $_->name() } @drivers ) ],
    \@drivers, 'Fetch all drivers using string requests' );

for my $driver (@drivers) {
    my $drname  = $driver->name();
    my $version = $driver->version();
    ( my $version_next = $version ) =~ s/(\d+)$/$1+1/e;
    diag "Testing with $drname $version";

    for my $fields (@some) {
        my %fields = %$fields;
        s/x/$version/, s/y/$version_next/ for values %fields;
        my $request = { driver => $drname, %fields };
        my @got = Test::Database->drivers($request);
        is_deeply( \@got, [$driver], 'some with ' . to_string($request) );
    }

    for my $fields (@none) {
        my %fields = %$fields;
        s/x/$version/, s/y/$version_next/ for values %fields;
        my $request = { driver => $drname, %fields };
        my @got = Test::Database->drivers($request);
        is_deeply( \@got, [], 'none with ' . to_string($request) );
    }
}

sub to_string {
    my ($request) = @_;
    return
          '{ '
        . join( ', ', map {"$_ => $request->{$_}"} sort keys %$request )
        . ' }';
}

