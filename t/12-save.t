use strict;
use warnings;
use Test::More;
use Test::Database;
use File::Spec;

my @drivers = Test::Database->drivers();

plan tests => 1;

my $file = 'test-database.tmp';

Test::Database->save_drivers($file);
Test::Database->unload_drivers();

Test::Database->load_drivers($file);
is_deeply( [ Test::Database->drivers() ],
    \@drivers, "reloaded saved configuration" );

unlink $file;

