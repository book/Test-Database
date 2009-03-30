use strict;
use warnings;
use Test::More;
use Test::Database;

# hardcoded sorted list of our drivers
my @all_drivers = sort qw( CSV DBM SQLite SQLite2 mysql );

# intersection with DBI->available_drivers
my %all_drivers = map { $_ => 1 } @all_drivers;
my @available_drivers
    = sort grep { exists $all_drivers{$_} } DBI->available_drivers;

plan tests => 2;

is_deeply( [ Test::Database->all_drivers() ], \@all_drivers, 'all_drivers()' );
is_deeply( [ Test::Database->available_drivers() ],
    \@available_drivers, 'available_drivers()' );

