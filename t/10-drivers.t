use strict;
use warnings;
use Test::More;
use Test::Database;
use DBI;

plan tests => 2;

# hardcoded list of our drivers
my @available_drivers = qw( SQLite );

# intersection with DBI->available_drivers
my %available_drivers = map { $_ => 1 } @available_drivers;
my @drivers
    = sort grep { exists $available_drivers{$_} } DBI->available_drivers;

is_deeply( [ Test::Database->available_drivers() ],
    \@available_drivers, 'available_drivers()' );
is_deeply( [ Test::Database->drivers() ], \@drivers, 'drivers()' );

