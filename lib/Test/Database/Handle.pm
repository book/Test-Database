package Test::Database::Handle;
use strict;
use warnings;
use Carp;
use DBI;

# basic accessors
for my $attr (qw( dbd dsn username password )) {
    no strict 'refs';
    *{$attr} = sub { return $_[0]{$attr} };
}

sub new {
    my ( $class, %args ) = @_;

    exists $args{$_} or croak "$_ argument required"
       for qw( dsn );

    my ( $scheme, $driver, $attr_string, $attr_hash, $driver_dsn )
        = DBI->parse_dsn( $args{dsn} );

    return bless {
        username => '',
        password => '',
        %args,
        dbd => $driver,
    }, $class;
}

sub connection_info { return @{ $_[0] }{qw( dsn username password )} }

sub dbh {
    my ( $self, $attr ) = @_;
    return $self->{dbh} ||= DBI->connect( $self->connection_info(), $attr );
}

'IDENTITY';

__END__

=head1 NAME

Test::Database::Handle - A class for Test::Database handles

=head1 SYNOPSIS

    use Test::Database;

    my $handle = Test::Database->handle(@requests);
    my $dbh    = $handle->dbh();

=head1 DESCRIPTION

C<Test::Database::Handle> is a very simple class for encapsulating the
information about a test database handle.

C<Test::Database::Handle> objects are used within a test script to
obtain the necessary information about a test database handle.
Handles are obtained through the C<< Test::Database->handles() >>
or C<< Test::Database->handle() >> methods.

=head1 METHODS

C<Test::Database::Handle> provides the following methods:

=over 4

=item new( %args )

Return a new C<Test::Database::Handle> with the given parameters
(C<dsn>, C<username>, C<password>).

The only mandatory argument is C<dsn>.

=back

The following accessors are available.

=over 4

=item dsn()

Return the Data Source Name.

=item username()

Return the connection username.

=item password()

Return the connection password.

=item connection_info()

Return the connection information triplet (C<dsn>, C<username>, C<password>).

=item dbh( [ $attr ] )

Return the DBI database handle obtained when connecting with the
connection triplet returned by C<connection_info()>.

The optional parameter C<$attr> is a reference to a hash of connection
attributes, passed directly to DBI's C<connect()> method.

=item dbd()

Return the DBI driver name, as computed from the C<dsn>.

=back

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book@cpan.org> >>

=head1 COPYRIGHT

Copyright 2008-2009 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

