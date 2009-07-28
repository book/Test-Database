use strict;
use warnings;
use Test::More;
use Test::Database;

# hardcoded sorted list of our drivers
my @all_drivers = sort qw( CSV DBM SQLite SQLite2 );

# intersection with DBI->available_drivers
my %all_drivers = map { $_ => 1 } @all_drivers;
my @available_drivers
    = sort grep { exists $all_drivers{$_} } DBI->available_drivers;

plan tests => 3;

# existing Test::Database::Driver:: drivers
is_deeply( [ Test::Database->list_drivers('all') ],
    \@all_drivers, q{list_drivers('all')} );

# available DBI drivers
is_deeply( [ Test::Database->list_drivers('available') ],
    \@available_drivers, q{list_drivers('available')} );

# available DBI drivers we could load (assuming everything works)
is_deeply( [ Test::Database->list_drivers() ],
    \@available_drivers, 'list_drivers()' );

