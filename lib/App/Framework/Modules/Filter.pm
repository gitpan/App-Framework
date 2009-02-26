package App::Framework::Modules::Filter ;

=head1 NAME

App::Framework::Filter - Script filter application object

=head1 SYNOPSIS

use App::Framework::Filter ;


=head1 DESCRIPTION

Application that filters either a file or a directory to produce some other output

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

our $VERSION = "1.000" ;


#============================================================================================
# USES
#============================================================================================
use App::Framework::Modules::Script ;

#============================================================================================
# OBJECT HIERARCHY
#============================================================================================
our @ISA = qw(App::Framework::Modules::Script) ; 

#============================================================================================
# GLOBALS
#============================================================================================

# Set of script-related default options
my @SCRIPT_OPTIONS = (
#	['log|L=s',			'Log file', 		'Specify a log file', ],
#	['v|"verbose"',		'Verbose output',	'Make script output more verbose', ],
#	['debug=s',			'Set debug level', 	'Set the debug level value', ],
#	['h|"help"',		'Print help', 		'Show brief help message then exit'],
#	['man',				'Full documentation', 'Show full man page then exit' ],
#	['dryrun|"norun"',	'Dry run', 			'Do not execute anything that would alter the file system, just show the commands that would have executed'],
) ;

#============================================================================================
# CONSTRUCTOR 
#============================================================================================

=item C<App::Framework::Filter-E<gt>new([%args])>

Create a new App::Framework::Filter.

The %args are specified as they would be in the B<set> method, for example:

	'mmap_handler' => $mmap_handler

The full list of possible arguments are :

	'fields'	=> Either ARRAY list of valid field names, or HASH of field names with default values 

=cut

sub new
{
	my ($obj, %args) = @_ ;

	my $class = ref($obj) || $obj ;

	# Need to look 3 levels higher than this wrapper i.e. look at this wrapper's caller
	# If this object is being used as a base for another object then use the '_caller' arg specified
	my $call_level = delete $args{'_caller'} || 3 ;

	# Create object
	my $this = $class->SUPER::new(
		%args, 
		'_caller'=>$call_level,	
	) ;

	return($this) ;
}



#============================================================================================
# CLASS METHODS 
#============================================================================================


#============================================================================================
# OBJECT METHODS 
#============================================================================================

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>options([$options_aref])>

Adds some extra script-related default options.

Set options based on the ARRAY ref specification.

Each entry in the ARRAY is an ARRAY ref containing:

 [ <option spec>, <option summary>, <option description> ]

Where the <option spec> is in the format used by Getopt::Long

NOTE: The <option spec> also determines the name of the field used to store the
option value/flag. If alternatives are specified, then the first one is used. Alternatively,
if any alternative is marked with quotes, then that is the one used.

Examples:

 dir|d|directory	- Field name is 'dir'
 dir|d|'directory'	- Field name is 'directory'
 

When no arguments are specifed, returns the hash of options/values

=cut

sub options
{
	my $this = shift ;
	my ($options_aref) = @_ ;

	my $options_href = $this->_options() ;
	
	if ($options_aref)
	{
		# If we're setting options, then add our extra set
		my @combined_options = (@SCRIPT_OPTIONS, @$options_aref) ;
		$this->SUPER::options(\@combined_options) ;
	}

	return %$options_href ;
}



# ============================================================================================
# PRIVATE METHODS
# ============================================================================================




# ============================================================================================
# END OF PACKAGE
1;

__END__


