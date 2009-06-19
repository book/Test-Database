use strict;
use warnings;
use Test::More;
use File::Find;

my @modules;
find( sub { push @modules, $File::Find::name if /\.pm$/ }, 'blib/lib' );

plan tests => scalar @modules;

use_ok($_)
    for sort map { s!/!::!g; s/\.pm$//; s/^blib::lib:://; $_ } @modules;

diag("Tested Test::Database $Test::Database::VERSION, Perl $], $^X");

