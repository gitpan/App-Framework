package App::Framework::Modules::Script ;

=head1 NAME

App::Framework::Script - Script application object

=head1 SYNOPSIS

	use App::Framework ;
	
	# VERSION
	our $VERSION = '1.001' ;

	# Create application and run it
	App::Framework->new()->go() ;

	#----------------------------------------------------------------
	# Define run subroutine, automatically called by App:Script->go()
	sub run
	{
		my ($app) = @_ ;
		
		my %opts = $app->options() ;
		my @namelist = @{$app->arglist()}; 
	
		# DO APPLIC|ATION HERE
		
	}
	
	#----------------------------------------------------------------
	# Define main script information & all application options
	__DATA__
	
	[HISTORY]
	
	30-May-08	SDP		Re-written to use App::Framework::Script 
	28-May-08   SDP		New
	
	[SUMMARY]
	
	List (and repair) any faulty rrd database files
	
	[SYNOPSIS]
	
	$name [options] <rrd file(s)>
	
	[OPTIONS]
	
	-d|'dir'=s	temp directory	[default=/tmp]
	
	Specify the directory in which to store the xml output files (created by dumping the rrd databases)
	
	-repair 	Enable rrd repair
	
	When this option is specified, causes the script to repair any faulty rrd files
	
	
	[DESCRIPTION]
	
	Scans the specified rrd directory and lists any files which are 'faulty'. 
	
	Optionally this script can also repair the fault by setting the value to NaN.
	
	An export RRD database in XML file is of the form:
	
	  <!-- Round Robin Database Dump --><rrd>	<version> 0003 </version>
		<step> 300 </step> <!-- Seconds -->
		<lastupdate> 1211355308 </lastupdate> <!-- 2008-05-21 08:35:08 BST -->


=head1 DESCRIPTION

Derived object from App::Framework::Base. Should only be called via App::Framework import.

Adds command line script specific additions to base properties. Adds the following
additional options:

	'log|L=s'			Specify a log file
	'v|"verbose"'		Make script output more verbose
	'dryrun|"norun"'	Do not execute anything that would alter the file system, just show the commands that would have executed
	
Defines the exit() method which just calls standard exit.

Defines a usage_fn which gets called by App::Framework::Base->uage(). This function calls pod2usage to display help, man page
etc. 

=head1 DIAGNOSTICS

Setting the debug flag to level 1 prints out (to STDOUT) some debug messages, setting it to level 2 prints out more verbose messages.

=head1 AUTHOR

Steve Price C<< <sdprice at cpan.org> >>

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
use App::Framework::Base ;

use File::Temp ();
use Pod::Usage ;


 
#============================================================================================
# OBJECT HIERARCHY
#============================================================================================
our @ISA = qw(App::Framework::Base) ; 

#============================================================================================
# GLOBALS
#============================================================================================

# Set of script-related default options
my @SCRIPT_OPTIONS = (
	['log|L=s',			'Log file', 		'Specify a log file', ],
	['v|"verbose"',		'Verbose output',	'Make script output more verbose', ],
	['dryrun|"norun"',	'Dry run', 			'Do not execute anything that would alter the file system, just show the commands that would have executed'],
) ;

#============================================================================================
# CONSTRUCTOR 
#============================================================================================

=item C<App::Framework::Modules::Script-E<gt>new([%args])>

Create a new App::Framework::Modules::Script.

The %args are specified as they would be in the B<set> method, for example:

	'mmap_handler' => $mmap_handler

The full list of possible arguments are :

	'fields'	=> Either ARRAY list of valid field names, or HASH of field names with default values 

=cut

sub new
{
	my ($obj, %args) = @_ ;

	my $class = ref($obj) || $obj ;
	
	# Need to look 2 level higher than this wrapper i.e. look at this wrapper's caller
	# If this object is being used as a base for another object then use the '_caller' arg specified
	my $call_level = delete $args{'_caller'} || 2 ;

	# Create object
	my $this = $class->SUPER::new(
		%args, 
		'_caller'	=> $call_level,
	) ;
	$this->set(
		'usage_fn' 	=> sub {$this->script_usage(@_);}, 
	) ;

	return($this) ;
}



#============================================================================================

=back

=head2 CLASS METHODS

=over 4

=cut

#============================================================================================

#----------------------------------------------------------------------------

=item C<App::Framework::Modules::Script-E<gt>allowed_class_instance()>

Class instance object is not allowed
 
=cut

sub allowed_class_instance
{
	return 0 ;
}

#============================================================================================

=back

=head2 OBJECT METHODS

=over 4

=cut

#============================================================================================

#----------------------------------------------------------------------------

=item C<App::Framework::Modules::Script-E<gt>options([$options_aref])>

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
#$this->prt_data("==Script->options($options_href) opts=", $options_aref) if $this->debug()>=5 ;

		# If we're setting options, then add our extra set
		my @combined_options = (@SCRIPT_OPTIONS, @$options_aref) ;
		$this->SUPER::options(\@combined_options) ;

#print "==Script->options($options_href) - DONE\n" if $this->debug()>=5 ;
	}

	return %$options_href ;
}


#----------------------------------------------------------------------------

=item C<App::Framework::Modules::Script-E<gt>exit()>

Exit the application.
 
=cut


sub exit
{
	my $this = shift ;
	my ($exit_code) = @_ ;

	exit $exit_code ;
}

#----------------------------------------------------------------------------

=item C<App::Framework::Modules::Script-E<gt>catch_error($error)>

Function that gets called on errors. $error is as defined in L<App::Framework::Base::Object::ErrorHandle>

=cut

sub catch_error
{
	my $this = shift ;
	my ($error) = @_ ;

#TODO: This is just the App::Framework::Base::Object::ErrorHandle default_error_handler() code - could just use that (return handled=0)
	my $handled = 0 ;

	# If it's an error, stop
	if ($this->is_error($error))
	{
		my ($msg, $exitcode) = $this->error_split($error) ;
		die "Error: $msg\n" ;
		$handled = 1 ;
	}
	if ($this->is_warning($error))
	{
		my ($msg, $exitcode) = $this->error_split($error) ;
		warn "Warning: $msg\n" ;
		$handled = 1 ;
	}
	if ($this->is_note($error))
	{
		my ($msg, $exitcode) = $this->error_split($error) ;
		print "Note: $msg\n" ;
		$handled = 1 ;
	}

	return $handled ;
}

#--------------------------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>run_cmd($cmd, [$cmd_args, [$exit_on_fail]])>

Execute a specified command, return either the exit status [0=success] (in scalar context) or the 
array of lines output by the command (in array context)

If $exit_on_fail is set, then this routine reports the run results and exits if the return status is not 0

NOTE: This interface is DIFFERENT to that employed by the underlying Run object. This form is meant to 
be easier to use for Applications.


=cut

sub run_cmd
{
	my $this = shift ;
	my ($cmd, $cmd_args, $exit_on_fail) = @_ ;
	
	my $rc = $this->runobj()->run('cmd' => $cmd, 'args' => $cmd_args) ;
	
	# Abort if run failed & we're asked to
	if ($exit_on_fail && $rc)
	{
		my $message = "Error: run command \"$cmd $cmd_args\" returned with exit code $rc. Aborting.\n" ;
		$message .= join "\n", $this->run_results() ;
		$this->throw_fatal($message, 999) ;
	}
	
	return wantarray ? $this->run_results() : $rc ;
}


# ============================================================================================
# NEW METHODS
# ============================================================================================

#----------------------------------------------------------------------------

=item C<App::Framework::Modules::Script-E<gt>script_usage($level)>

Show usage.

$level is a string containg the level of usage to display

	'opt' is equivalent to pod2usage(2)

	'help' is equivalent to pod2usage(1)

	'man' is equivalent to pod2usage(-verbose => 2)

=cut

sub script_usage
{
	my $this = shift ;
	my ($app, $level) = @_ ;
	
	# TODO: Work out a better way to convert pod without the use of external file!
	
	# get temp file
	my $fh = new File::Temp();
	my $fname = $fh->filename;
	
	# write pod
	print $fh $this->pod() ;
	close $fh ;

	# pod2usage 
	my ($exitval, $verbose) = (0, 0) ;
	($exitval, $verbose) = (2, 0) if ($level eq 'opt') ;
	($exitval, $verbose) = (1, 0) if ($level eq 'help') ;
	($exitval, $verbose) = (0, 2) if ($level eq 'man') ;

#print "level=$level, exit=$exitval, verbose=$verbose\n";

	# make file readable by all - in case we're running as root
	chmod 0644, $fname ;

#	system("perldoc",  $fname) ;
	pod2usage(
		-verbose	=> $verbose,
		-exitval	=> $exitval,
		-input		=> $fname,
		
		-title => $this->name(),
		-section => 1,
	) ;
	
	# remove temp file
	unlink $fname ;
}


# ============================================================================================
# PRIVATE METHODS
# ============================================================================================




# ============================================================================================
# END OF PACKAGE
1;

__END__


