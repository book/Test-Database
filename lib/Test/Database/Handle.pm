package Test::Database::Handle;
use strict;
use warnings;
use Carp;

# basic accessors
for my $attr (qw( driver dsn username password name )) {
    no strict 'refs';
    *{$attr} = sub { return $_[0]{$attr} };
}

sub new {
    my ( $class, %args ) = @_;

    exists $args{$_} or croak "$_ argument required"
       for qw< driver dsn name >;

    return bless {
        username => '',
        password => '',
        %args,
    }, $class;
}

sub connection_info { return @{ $_[0] }{qw< dsn username password >} }

sub dbh {
    my ($self) = @_;
    return $self->{dbh} ||= DBI->connect( $self->connection_info() );
}

'IDENTITY';

__END__

=head1 NAME

Test::Database::Handle - A class for Test::Database handles

=head1 SYNOPSIS

    use Test::Database;

    my $handle = Test::Database->handle( SQLite => 'test' );

=head1 DESCRIPTION

C<Test::Database::Handle> is a very simple class for encapsulating the
information about a test database handle.

=head1 METHODS

C<Test::Database::Handle> provides the following methods:

=over 4

=item new( %args )

Return a new C<Test::Database::Handle> with the given arguments
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

Return the connection information tripler (C<dsn>, C<username>, C<password>).

=item dbh()

Return the DBI database handle obtained when connecting with the
connection triplet returned by C<connection_info()>.

=item driver()

Return the DBI driver name, as computed from the C<dsn>.

=item name()

Name of the database in the corresponding driver.

=back

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book@cpan.org> >>

=head1 COPYRIGHT

Copyright 2008-2009 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

