use strict;
use warnings;
use Test::More;
use Test::Database::Driver;
use version;

# test version_matches() on a dummy driver

my @requests;

my @ok = (
    {},
    { version     => '1.2.3' },
    { min_version => '1.2.2' },
    { min_version => '1.2.3' },
    { max_version => '1.3.0' },
    { version     => '1.2.3', min_version => '1.2.0' },
    { version     => '1.2.3', max_version => '1.4.3' },
    { min_version => '1.2.0', max_version => '2.0' },
    { version     => '1.2.3', min_version => '1.2.0', max_version => '2.0' },
);

my @not_ok = (
    { min_version => '1.3.0' },
    { max_version => '1.002' },
    { max_version => '1.2.3' },
    { version     => '1.3.4' },
    { min_version => '1.3.0', max_version => '2.1' },
    { min_version => '0.1.3', max_version => '1.002' },
);

@Test::Database::Driver::Dummy::ISA = qw( Test::Database::Driver );
my $driver = bless { version => version->new('1.2.3') },
    'Test::Database::Driver::Dummy';

plan tests => @ok + @not_ok;

for my $request (@ok) {
    ok( $driver->version_matches($request), to_string($request) );
}

for my $request (@not_ok) {
    ok( !$driver->version_matches($request), to_string($request) );
}

sub to_string {
    my ($request) = @_;
    return
          '{ '
        . join( ', ', map {"$_ => $request->{$_}"} sort keys %$request )
        . ' }';
}

