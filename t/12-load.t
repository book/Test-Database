use strict;
use warnings;
use Test::More;
use Test::Database;
use File::Spec;

my @good = (
    {   dsn      => 'dbi:mysql:database=mydb;host=localhost;port=1234',
        username => 'user',
        password => 's3k r3t',
    },
    {   dsn      => 'dbi:mysql:database=mydb;host=remotehost;port=5678',
        username => 'otheruser',
    },
    { dsn => 'dbi:SQLite:db.sqlite' },
);

plan tests => 1 + @good + 3;

# load a correct file
my $file   = File::Spec->catfile(qw< t database.rc >);
my @config = Test::Database::_read_file($file);

is( scalar @config, scalar @good,
    "Got @{[scalar @good]} drivers from $file" );

for my $test (@good) {
    my $args = shift @config;
    is_deeply( $args, $test, "Read args for driver $test->{dsn}" );
}

# try to load a bad file
$file = File::Spec->catfile(qw< t database.bad >);
ok( !eval { Test::Database::_read_file($file); 1 },
    "_read_file( $file ) failed" );
like(
    $@,
    qr/^Can't parse line at .*, line \d+:\n  <bad format> at /,
    'Expected error message'
);

# load an empty file
$file = File::Spec->catfile(qw< t database.empty >);
is( scalar Test::Database::_read_file($file), 0, 'Empty file' );

