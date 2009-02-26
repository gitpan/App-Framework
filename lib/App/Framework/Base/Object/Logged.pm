package App::Framework::Base::Object::Logged ;

=head1 NAME

App::Framework::Base::Object::Logged - Error handling object with logging capabilities

=head1 SYNOPSIS

use App::Framework::Base::Object::Logged ;


=head1 DESCRIPTION


=head1 DIAGNOSTICS

Setting the debug flag to level 1 prints out (to STDOUT) some debug messages, setting it to level 2 prints out more verbose messages.

=head1 AUTHOR

Steve Price E<lt>linux@quartz-net.co.ukE<gt>

=head1 BUGS

None that I know of!

=head1 INTERFACE

=over 4

=cut

use strict ;
use Carp ;

our $VERSION = "1.001" ;

#============================================================================================
# USES
#============================================================================================
use App::Framework::Base::Object::ErrorHandle ;

#============================================================================================
# OBJECT HIERARCHY
#============================================================================================
our @ISA = qw(App::Framework::Base::Object::ErrorHandle) ; 

#============================================================================================
# GLOBALS
#============================================================================================

my %FIELDS = (
	'logfn'		=> undef,
	'logfile'	=> undef,
) ;

#============================================================================================
# CONSTRUCTOR 
#============================================================================================

=item C<App::Framework::Base::Object::Logged-E<gt>new([%args])>

Create a new App::Framework::Base::Object::Logged.

The %args are specified as they would be in the B<set> method, for example:

	'mmap_handler' => $mmap_handler

The full list of possible arguments are :

	'fields'	=> Either ARRAY list of valid field names, or HASH of field names with default values 

=cut

sub new
{
	my ($obj, %args) = @_ ;

	my $class = ref($obj) || $obj ;

	# Create object
	my $this = $class->SUPER::new(%args) ;
	
	
	return($this) ;
}



#============================================================================================
# CLASS METHODS 
#============================================================================================

#-----------------------------------------------------------------------------

=item C<App::Framework::Base::Object::Logged-E<gt>init_class([%args])>

Initialises the App::Framework::Base::Object::Logged object class variables. Creates a class instance so that these
methods can also be called via the class (don't need a specific instance)

=cut

sub init_class
{
	my $class = shift ;
	my (%args) = @_ ;

	if (! keys %args)
	{
		%args = () ;
	}
	
	# Add extra fields
	$class->add_fields(\%FIELDS, \%args) ;
#	foreach (keys %FIELDS)
#	{
#		$args{'fields'}{$_} = $FIELDS{$_} ;
#	}

	# init class
	$class->SUPER::init_class(%args) ;

	# Create a class instance object - allows these methods to be called via class
	$class->class_instance(%args) ;

}


#============================================================================================
# OBJECT METHODS 
#============================================================================================

#--------------------------------------------------------------------------------------------

=item C<App::Framework::Base::Object::Logged-E<gt>log(@str)>

Log the string. If field 'logfn' is defined, calls that instead. If field 'logfile' is defined, appends
string to that. Otherwise does nothing.

=cut

sub log
{
	my $this = shift ;
	my (@str) = @_ ;

	# See if this is a class call
	$this = $this->check_instance() ;
	
	# If specified, use logging output
	my $logfn = $this->logfn() ;
	if (defined($logfn))
	{
		foreach (@str)
		{
			&$logfn($_) ;
		}
	}
	else
	{
		my $logfile = $this->logfile() ;
		if (defined($logfile))
		{
			$this->_do_log($logfile, @str) ;
		}		
	}
}


#---------------------------------------------------------------------

=item C<App::Framework::Base::Object::Logged-E<gt>clear_log([%args])>

Restart the logfile.

=cut

sub clear_log
{
	my $this = shift ;
	my (%args) = @_ ;

	# See if this is a class call
	$this = $this->check_instance() ;
	
	# Set any vars
	$this->set(%args) ;
	
	my $logfile = $this->logfile() ;
	open my $fh, ">$logfile" or croak "Error: unable to initialise log file $logfile : $!" ;
	close $fh ;
}
	

# ============================================================================================
# PRIVATE METHODS
# ============================================================================================

#--------------------------------------------------------------------------------------------

=item C<App::Framework::Base::Object::Logged-E<gt>_do_log($filename, $str)>

PRIVATE

Log the string or array of strings. 

=cut

sub _do_log
{
	my $this = shift ;
	my ($logfile, @str) = @_ ;

	# See if this is a class call
	$this = $this->check_instance() ;
	
	my $fh ;
	if (!open $fh, ">>$logfile")
	{
#		dump_callstack() if $DEBUG>=6 ;
		croak "Error: unable to append to log file $logfile : $!" ;
	} 
	print $fh @str ;
	close $fh ;
}




# ============================================================================================
# END OF PACKAGE
1;

__END__


