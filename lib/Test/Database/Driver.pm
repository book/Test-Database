package Test::Database::Driver;
use strict;
use warnings;
use Carp;
use File::Spec;
use File::Path;

use Test::Database::Handle;

#
# global configuration
#
my $root
    = File::Spec->rel2abs(
    File::Spec->catdir( File::Spec->tmpdir(), 'Test-Database-' . getlogin() )
    );

#
# base implementations
#

# MAY be implemented in the derived class
sub start_engine { }
sub stop_engine  { }

# MUST be implemented in the derived class
sub create_database {
    my ( $class, $name ) = @_;

    croak "$class doesn't define a create_database() method."
        . " Can't create database '$name'";
}

#
# common methods
#
sub name { return ( $_[0] =~ /^Test::Database::Driver::(.*)/g )[0]; }

sub base_dir {
    return $_[0] eq __PACKAGE__
        ? $root
        : File::Spec->catdir( $root, $_[0]->name() );
}

my %started;
my %handle;

sub handle {
    my ( $class, $name ) = @_;

    $name ||= 'default';

    # make sure the database server has been started
    $started{$class} ||= $class->start_engine();

    # return the handle
    return $handle{$class}{$name} ||= $class->create_database($name);
}

sub cleanup { rmtree $_[0]->base_dir() }

'CONNECTION';

__END__

=head1 NAME

Test::Database::Driver - Base class for Test::Database drivers

=head1 SYNOPSIS

    package Test::Database::Driver::MyDatabase;
    use strict;
    use warnings;
    
    use Test::Database::Driver;
    our @ISA = qw( Test::Database::Driver );
    
    sub start_server { ... }
    sub stop_server  { ... }

    sub create_database {
        my ( $class, $name ) = @_;
        ...
        return $handle;
    }

=head1 DESCRIPTION

C<Test::Database::Driver> is a base class for creating C<Test::Database>
drivers.

=head1 METHODS

The class provides the following methods:

=over 4

=item name()

The driver's short name (everything after C<Test::Database::Driver::>).

=item base_dir()

The directory where the driver should store all the files for its databases.
Typically used to configure the DSN or the database engine.

=item handle( [ $name ] )

Return a C<Test::Database::Handle> object for a database named C<$name>.
If C<$name> is not given, the name C<default> is used.

=item cleanup()

Delete the C<base_dir()> directory and its content.

When called on C<Test::Database> directly, it will delete the main
directory that contains all the individual directories used by
C<Test::Database> drivers.

=back

=head1 WRITING A DRIVER FOR YOUR DATABASE OF CHOICE

Creating a driver requires writing the following methods:

=over 4

=item start_server()

Start a server for the corresponding database engine, and return a

=item stop_server()

=back

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book@cpan.org> >>

=head1 COPYRIGHT

Copyright 2008 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

