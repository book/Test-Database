package Test::Database::Driver;
use strict;
use warnings;
use Carp;
use File::Spec;
use File::Path;
use version;

use Test::Database::Handle;

#
# global configuration
#
# the location where all drivers-related files will be stored
my $root
    = File::Spec->rel2abs(
    File::Spec->catdir( File::Spec->tmpdir(), 'Test-Database-' . getlogin() )
    );

# some information stores, indexed by driver class name
my %drh;

# generic driver class initialisation
sub __init {
    my ($class) = @_;

    # create directory if needed
    if ( $class->is_filebased() ) {
        my $dir = $class->base_dir();
        if ( !-e $dir ) {
            mkpath( [$dir] );
        }
        elsif ( !-d $dir ) {
            croak "$dir is not a directory. Initializing $class failed";
        }
    }

    # load the DBI driver (may die)
    $drh{ $class->name() } ||= DBI->install_driver( $class->name() );
}

#
# METHODS
#
sub new {
    my ( $class, %args ) = @_;

    if ( $class eq __PACKAGE__ ) {
        croak "No driver defined" if !exists $args{driver};
        eval "require Test::Database::Driver::$args{driver}"
            or croak $@;
        $class = "Test::Database::Driver::$args{driver}";
        $class->__init();    # survive a cleanup()
    }
    my $self = bless {
        username => '',
        password => '',
        map ( { $_ => '' } $class->essentials() ),
        %args,
        driver => $class->name()
        },
        $class;

    # try to connect before returning the object
    if ( !$class->is_filebased() ) {
        eval { DBI->connect_cached( $self->connection_info() ) }
            or return undef;
    }
    return $self;
}

sub cleanup {
    my ($self) = @_;
    if ( $self->is_filebased() ) {
        my $dir = $self->base_dir();
        for my $entry ( map { File::Spec->catfile( $dir, $_ ) }
            $self->_filebased_databases() )
        {
            if ( -d $entry ) {
                rmtree( [$entry] );
            }
            else {
                unlink $entry;
            }
        }
    }
}

sub available_dbname {
    my ($self) = @_;
    my $name = $self->_basename();
    my %taken = map { $_ => 1 } $self->databases();
    my $n = 0;
    $n++ while $taken{"$name$n"};
    return "$name$n";
}

sub as_string {
    return join '',
        map { "$_ = " . _quote( $_[0]{$_} || '' ) . "\n" }
        driver => $_[0]->essentials();
}

sub handles {
    my ( $self, @requests ) = @_;

    # return all available handles if no request
    my @databases = $self->databases();
    return map { $self->_handle($_) } @databases if !@requests;

    # get unique names, with higher priority on keep
    # '' will get a random name
    my %keep;
    for my $request (@requests) {
        my $dbname = exists $request->{name} ? $request->{name} : '';
        $keep{$dbname} = $request->{keep} if !$keep{$dbname};
    }

    # create all databases if needed
    return map { $self->create_database( $_, $keep{$_} ) } keys %keep;
}

my @DROP;
sub register_drop { push @DROP, [@_]; }

END {
    for my $drop (@DROP) {
        my ( $driver, $dbname ) = @$drop;
        $driver->drop_database($dbname);
    }
}

#
# ACCESSORS
#
sub name { return ( $_[0] =~ /^Test::Database::Driver::([:\w]*)/g )[0]; }

sub base_dir {
    return $_[0] eq __PACKAGE__
        ? $root
        : File::Spec->catdir( $root, $_[0]->name() );
}

sub version {
    no warnings;
    return $_[0]{version} ||= version->new( $_[0]->_version() );
}

sub drh      { return $drh{ $_[0]->name() } }
sub bare_dsn { return $_[0]{dsn} ||= $_[0]->_bare_dsn() }
sub username { return $_[0]{username} }
sub password { return $_[0]{password} }

sub connection_info {
    return ( $_[0]->bare_dsn(), $_[0]->username(), $_[0]->password() );
}

# THESE MUST BE IMPLEMENTED IN THE DERIVED CLASSES
sub drop_database { die "$_[0] doesn't have a drop_database() method\n" }
sub _version      { die "$_[0] doesn't have a _version() method\n" }
sub dsn           { die "$_[0] doesn't have a dsn() method\n" }

sub create_database {
    my ( $self, $dbname ) = @_;
    if ( $self->is_filebased() ) {
        croak "Invalid database name: $dbname"
            if $dbname && $dbname !~ /^\w+$/;
        goto &_filebased_create_database;
    }
    die "$_[0] doesn't have a create_database() method\n";
}

sub databases {
    goto &_filebased_databases if $_[0]->is_filebased();
    die "$_[0] doesn't have a databases() method\n";
}

# THESE MAY BE OVERRIDDEN IN THE DERIVED CLASSES
sub essentials   { }
sub is_filebased {0}
sub _bare_dsn    { join ':', 'dbi', $_[0]->name(), ''; }

#
# PRIVATE METHODS
#
sub _basename { return lc 'Test_Database_' . $_[0]->name() . '_' }

sub _filebased_databases {
    my ($self) = @_;
    my $dir = $self->base_dir();

    opendir my $dh, $dir or croak "Can't open directory $dir for reading: $!";
    my @databases = File::Spec->no_upwards( readdir($dh) );
    closedir $dh;

    return @databases;
}

sub _filebased_create_database {
    my ( $self, $dbname, $keep ) = @_;
    $dbname = $self->available_dbname() if !$dbname;
    $self->register_drop($dbname) if !$keep;

    return Test::Database::Handle->new(
        dsn    => $self->dsn($dbname),
        name   => $dbname,
        driver => $self,
    );
}

sub _handle {
    my ( $self, $name ) = @_;
    return Test::Database::Handle->new(
        dsn    => $self->dsn($name),
        name   => $name,
        driver => $self,
    );
}

#
# PRIVATE FUNCTIONS
#
sub _quote {
    my ($string) = @_;
    return $string if $string =~ /^\w+$/;

    $string =~ s/\\/\\\\/g;
    $string =~ s/"/\\"/g;
    $string =~ s/\n/\\n/g;
    return qq<"$string">;
}

sub _unquote {
    my ($string) = @_;
    return $string if $string !~ /\A(["']).*\1\z/s;

    my $quote = chop $string;
    $string = substr( $string, 1 );
    $string =~ s/\\(.)/$1 eq 'n' ? "\n" : $1/eg;
    return $string;
}

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

    sub _version {
        my ($class) = @_;
        ...;
        return $version;
    }

    sub create_database {
        my ( $self, $dbname, $keep ) = @_;
        ...;
        return $handle;
    }

    sub drop_database {
        my ( $self, $name ) = @_;
        ...;
    }

    sub databases {
        my ($self) = @_;
        ...;
        return @databases;
    }

=head1 DESCRIPTION

C<Test::Database::Driver> is a base class for creating C<Test::Database>
drivers.

=head1 METHODS

The class provides the following methods:

=over 4

=item new( %args )

Create a new C<Test::Database::Driver> object.

If called as C<< Test::Database::Driver->new() >>, requires a C<driver>
parameter to define the actual object class.

=item name()

The driver's short name (everything after C<Test::Database::Driver::>).

=item base_dir()

The directory where the driver should store all the files for its databases,
if needed. Typically used by file-based database drivers.

=item version()

C<version> object representing the version of the underlying database enginge.
This object is build with the return value of C<_version()>.

=item drh()

The DBI driver for this driver.

=item bare_dsn()

Return a bare Data Source Name, sufficient to connect to the database
engine without specifying an actual database.

=item username()

Return the connection username.

=item password()

Return the connection password.

=item connection_info()

Return the connection information triplet (C<bare_dsn>, C<username>,
C<password>).

=item as_string()

Return a string representation of the C<Test::Database::Driver>,
suitable to be saved in a configuration file.

=item handles( @requests )

Return C<Test::Database::Handler> objects matching the given requests.

If no request is given, return a handler for each of the existing databases.

=item cleanup()

Remove the directory used by C<Test::Database> drivers.

=back

The class also provides a few helpful commands that may be useful for driver
authors:

=over 4

=item available_dbname()

Return an unused database name that can be used to create a new database
for the driver.

=item dsn( $dbname )

Return a bare Data Source Name, for the database with the given C<$dbname>.

=item register_drop( $dbname )

Register the database with the given C<$dbname> to be dropped automatically
when the current program ends.

=back

=head1 WRITING A DRIVER FOR YOUR DATABASE OF CHOICE

The L<SYNOPSIS> contains a good template for writing a
C<Test::Database::Driver> class.

Creating a driver requires writing the following methods:

=over 4

=item _version()

Return the version of the underlying database engine.

=item create_database( $name )

Create the database for the corresponding DBD driver.

Return a C<Test::Database::Handle> in case of success, and nothing in
case of failure to create the database.

=item drop_database( $name )

Drop the database named C<$name>.

=back

Some methods have defaults implementations in C<Test::Database::Driver>,
but those can be overridden in the derived class:

=over 4

=item is_filebased()

Return a boolean value indicating if the database engine is file-based
or not, i.e. if all the database information is stored in a file or a
directory, and no external database server is needed.

=item essentials()

Return the I<essential> fields needed to serialize the driver.

=item databases()

Return the names of all existing databases for this driver as a list
(the default implementation is only valid for file-based drivers).

=item cleanup()

Clean all databases created with names generated with C<available_dbname()>.

For file-based databases, the directory used by the C<Test::Database::Driver>
subclass will be deleted.

=back

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book@cpan.org> >>

=head1 COPYRIGHT

Copyright 2008-2009 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

