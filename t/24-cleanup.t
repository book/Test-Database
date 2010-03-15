use Test::More;
use Test::Database;

my @handles = Test::Database->handles();

plan tests => scalar @handles;

# setup a clean state for t/25-sql.t
ok( eval { $_->driver->drop_database( $_->name ); 1 },
    "Dropped database " . $_->name . " from " . $_->dbd
) for @handles;

diag $_->name for Test::Database->handles();
