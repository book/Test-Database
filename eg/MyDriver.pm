package Test::Database::Driver::MyDriver;
use strict;
use warnings;

use Test::Database::Driver;
our @ISA = qw( Test::Database::Driver );

sub start_engine {
    my ( $class ) = @_;

    # setup the database server, and start it

    # return true is the engine was started
    # and will need to be stopped
    return;

    # the returned value will be passed to stop_engine()
    # and can contain information necessary to stop the engine
}

sub stop_engine {
    my ( $class, $info ) = @_;

    # this method will stop the database server
    # $info contains information provided by start_engine()

}

sub create_database {
    my ( $class, $dbname ) = @_;

    # return a Test::Database::Handle object
    # or false if unable to create the handle
    return;
}

'MyDriver';

__END__

=head1 NAME

Test::Database::Driver::MyDriver - A Test::Database driver for MyDriver

=head1 SYNOPSIS

    use Test::Database;
    my $dbh = Test::Database->dbh( 'MyDriver' );

=head1 DESCRIPTION

This module is the C<Test::Database> driver for C<DBD::MyDriver>.

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

