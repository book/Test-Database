use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Test::Database',
    license             => 'perl',
    dist_author         => 'Philippe Bruhat (BooK) <book@cpan.org>',
    dist_version_from   => 'lib/Test/Database.pm',
    build_requires => {
        'Test::More' => 0,
        'DBI'        => 1,
        'File::HomeDir' => 0.50,
        'version'    => 0,
        'YAML::Tiny' => 0,
    },
    add_to_cleanup      => [ 'Test-Database-*' ],
);

$builder->create_build_script();
