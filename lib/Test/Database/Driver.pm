package Test::Database::Driver;
use strict;
use warnings;
use Carp;
use File::Spec;
use File::Path;
use version;

#
# global configuration
#
# the location where all drivers-related files will be stored
my $root = File::Spec->rel2abs(
    File::Spec->catdir(
        File::Spec->tmpdir(), 'Test-Database-' . getlogin()
    )
);

# some information stores, indexed by driver class name
my %drh;

# generic driver class initialisation
sub __init {
    my ($class) = @_;

    # create directory if needed
    my $dir = $class->base_dir();
    if ( !-e $dir ) {
        mkpath $dir;
    }
    elsif ( !-d $dir ) {
        croak "$dir is not a directory. Initializing $class failed";
    }

    # load the DBI driver
    $drh{$class} = DBI->install_driver( $class->name() );
}

sub new {
    my ( $class, %args ) = @_;
    bless {%args}, $class;
}

sub name { return ( $_[0] =~ /^Test::Database::Driver::(.*)/g )[0]; }

sub drh { return $drh{ $_[0]->name() } }

sub base_dir {
    return $_[0] eq __PACKAGE__
        ? $root
        : File::Spec->catdir( $root, $_[0]->name() );
}

sub version {
    my ($self) = @_;
    return $self->{version} ||= version->new( $self->_version() );
}

# THESE MUST BE IMPLEMENTED IN THE DERIVED CLASSES
sub create_database { die "$_[0] doesn't have a create_database() method\n" }
sub drop_database   { die "$_[0] doesn't have a drop_database() method\n" }
sub databases       { die "$_[0] doesn't have a databases() method\n" }
sub _version        { die "$_[0] doesn't have a _version() method\n" }

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

    __PACKAGE__->__init();
    
    sub create_database {
        my ( $class, $name ) = @_;
        ...
        return $handle;
    }

    sub drop_database {
        my ( $class, $name ) = @_;
        ...
    }

    sub databases {
        my ( $class ) = @_;
        ...
        return @databases;
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

The directory where the driver should store all the files for its databases,
if needed. Typically used by file-based database drivers.

=back

The class also provides a few helpful commands that may be useful for driver
authors:

=over 4

=item __init()

The method does the general configuration needed for a database driver.
All drivers should start by calling C<< __PACKAGE__->__init() >> to ensure
they have been correctly initialized.

=back

=head1 WRITING A DRIVER FOR YOUR DATABASE OF CHOICE

Creating a driver requires writing the following methods:

=over 4

=item create_database( $name )

Create the database for the corresponding DBD driver.

Return a C<Test::Database::Handle> in case of success, and nothing in
case of failure to create the database.

=item drop_database( $name )

Drop the database named C<$name>.

=item databases()

Return the names of all existing databases for this driver as a list.

=back

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book@cpan.org> >>

=head1 COPYRIGHT

Copyright 2008-2009 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

