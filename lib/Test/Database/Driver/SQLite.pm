package Test::Database::Driver::SQLite;
use strict;
use warnings;

use Test::Database::Driver;
our @ISA = qw( Test::Database::Driver );

use File::Spec;

__PACKAGE__->init();

sub create_database {
    my ( $class, $config, $dbname ) = @_;
    my $dbfile = File::Spec->catfile( $class->base_dir(), $dbname );

    return Test::Database::Handle->new( dsn => "dbi:SQLite:dbname=$dbfile", );
}

'SQLite';

__END__

=head1 NAME

Test::Database::Driver::SQLite - A Test::Database driver for SQLite

=head1 SYNOPSIS

    use Test::Database;
    my $dbh = Test::Database->dbh( 'SQLite' );

=head1 DESCRIPTION

This module is the C<Test::Database> driver for C<DBD::SQLite>.

=head1 SEE ALSO

L<Test::Database::Driver>

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book@cpan.org> >>

=head1 COPYRIGHT

Copyright 2008 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

