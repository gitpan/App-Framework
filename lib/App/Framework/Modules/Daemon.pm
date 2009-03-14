package App::Framework::Modules::Daemon ;

=head1 NAME

App::Framework::Daemon - Daemonize an application

=head1 SYNOPSIS

use App::Framework qw/Daemon/ ;


=head1 DESCRIPTION

App::Framework personality that provides a daemonized program (using Net::Server::Daemonize)

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


my %FIELDS = (
	## Object Data
	'app_run'	=> undef,
	'user'		=> 'nobody',
	'group'		=> 'nobody',
	'pid'		=> undef,
) ;

#============================================================================================
# CONSTRUCTOR 
#============================================================================================

=item C<App::Framework::Daemon-E<gt>new([%args])>

Create a new App::Framework::Daemon.

The %args are specified as they would be in the B<set> method, for example:

	'mmap_handler' => $mmap_handler

The full list of possible arguments are :

	'fields'	=> Either ARRAY list of valid field names, or HASH of field names with default values 

=cut

sub new
{
	my ($obj, %args) = @_ ;

	my $class = ref($obj) || $obj ;

	## Need Net::Server::Daemonize
	eval "use Net::Server::Daemonize;" ;
	if (@$)
	{
		croak "Sorry. You need to have Net::Server::Daemonize installed to be able to use $class" ;
	}

	# Create object
	my $this = $class->SUPER::new(
		%args, 
	) ;
	
	## hi-jack the run function
	$this->app_run($this->run_fn) ;
	$this->run_fn(sub {$this->daemon_run(@_);}) ;

	return($this) ;
}



#============================================================================================

=back

=head2 CLASS METHODS

=over 4

=cut

#============================================================================================

#-----------------------------------------------------------------------------

=item C<App::Server-E<gt>init_class([%args])>

Initialises the object class variables.

=cut

sub init_class
{
	my $class = shift ;
	my (%args) = @_ ;

	# Add extra fields
	$class->add_fields(\%FIELDS, \%args) ;

	# init class
	$class->SUPER::init_class(%args) ;

}


#============================================================================================

=back

=head2 OBJECT METHODS

=over 4

=cut

#============================================================================================

#----------------------------------------------------------------------------

=item C<App::Framework::Modules::Daemon-E<gt>options([$options_aref])>

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

#----------------------------------------------------------------------------

=item C<<App::Framework::Modules::Daemon->daemon_run()>>

Daemonize then run the application's run subroutine in side a loop.
 
=cut


sub daemon_run
{
	my $this = shift ;


my $use_net=1;
if ($use_net)
{	
print "Calling daemonize()...\n" ;
	## Daemonize
	Net::Server::Daemonize::daemonize(
	    $this->user,             # User
	    $this->group,            # Group
	    $this->pid,				 # Path to PID file - optional
	);
print "Calling application run...\n" ;
	
	## call application run
	my $app_run = $this->app_run() ;
	&$app_run($this) ;

}
else
{
  ##my $pid = safe_fork();
print "Calling fork()...\n" ;
  my $pid = fork;
  unless( defined $pid ){
    die "Couldn't fork: [$!]\n";
  }


  ### parent process should do the pid file and exit
  if( $pid ){

print "Killing parent..\n" ;
    $pid && exit(0);


  ### child process will continue on
  }else{

	
print "Calling application run...\n" ;
	
	## call application run
	my $app_run = $this->app_run() ;
	&$app_run($this) ;

  }
}



}



# ============================================================================================
# PRIVATE METHODS
# ============================================================================================




# ============================================================================================
# END OF PACKAGE
1;

__END__


