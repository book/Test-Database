package Test::Database::Driver::DBM;
use strict;
use warnings;

use Test::Database::Driver;
our @ISA = qw( Test::Database::Driver );

use File::Spec;
use File::Path;

sub create_database {
    my ( $class, $dbname ) = @_;

    my $dbdir = File::Spec->catdir( $class->base_dir(), $dbname );
    mkpath $dbdir if ! -e $dbdir;

    return Test::Database::Handle->new(
        dsn      => "dbi:DBM:f_dir=$dbdir",
    );
}

'DBM';

__END__

=head1 NAME

Test::Database::Driver::DBM - A Test::Database driver for CSV

=head1 SYNOPSIS

    use Test::Database;
    my $dbh = Test::Database->dbh( 'DBM' );

=head1 DESCRIPTION

This module is the C<Test::Database> driver for C<DBD::DBM>.

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

