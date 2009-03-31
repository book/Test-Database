use strict;
use warnings;
use Test::More;
use Test::Database;

my @drivers = Test::Database->drivers();
my @some
    = ( ['min_version'], ['max_version'], [qw( min_version max_version )], );
my @none = (
    { min_version => 100 },
    { max_version => 0 },
    { min_version => 100, max_version => 200 },
);

plan tests => 1 + @drivers * ( @some + @none );

is_deeply( [ Test::Database->drivers( map { $_->name() } @drivers ) ],
    \@drivers, 'Fetch all drivers using string requests' );

for my $driver (@drivers) {
    my $drname  = $driver->name();
    my $version = $driver->version();

    for my $fields (@some) {
        my $request = { driver => $drname, map { $_ => $version } @$fields };
        my @got = Test::Database->drivers($request);
        is_deeply( \@got, [$driver], 'some with ' . to_string($request) );
    }

    for my $fields (@none) {
        my $request = { driver => $drname, %$fields };
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

