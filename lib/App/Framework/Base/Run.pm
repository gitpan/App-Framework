package App::Framework::Base::Run ;

=head1 NAME

App::Framework::Base::Run - Execute external commands

=head1 SYNOPSIS

use App::Framework::Base::Run ;


=head1 DESCRIPTION


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

our $VERSION = "1.003" ;

# TODO: 1. Add methods to create args; specify command as ($cmd, $args)
# TODO: 2. Allow args to be specified as format string+array, or just array?
# TODO: 2. Post-process results lines (call external hooks); allow option to set list of error line regexps

#============================================================================================
# USES
#============================================================================================
use App::Framework::Base::Object::Logged ;

#============================================================================================
# OBJECT HIERARCHY
#============================================================================================
our @ISA = qw(App::Framework::Base::Object::Logged) ; 

#============================================================================================
# GLOBALS
#============================================================================================

my %FIELDS = (
	# Object Data
	'cmd'		=> undef,
	'args'		=> undef,
	'timeout'	=> undef,
	'nice'		=> undef,
	
	'check_results'	=> undef,
	'progress'		=> undef,
	
	'status'	=> 0,
	'results'	=> [],
	
	# Options/flags
	'norun'		=> 0,
) ;

#============================================================================================
# CONSTRUCTOR 
#============================================================================================

=item C<App::Framework::Base::Run-E<gt>new([%args])>

Create a new Run.

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

=item C<App::Framework::Base::Run-E<gt>init_class([%args])>

Initialises the Run object class variables.

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
# OBJECT METHODS 
#============================================================================================

#--------------------------------------------------------------------------------------------

=item C<App::Framework::Base::Run-E<gt>run([%args])>

Execute a command, return exit status (0=success)

=cut

sub run
{
	my $this = shift ;
	my (%args) = @_ ;

	# See if this is a class call
	$this = $this->check_instance() ;

$this->prt_data("run_cmd: this=", $this) if $this->debug() ;
	
	# Set any specified args
	$this->set(%args) ;

	# Get command
	my $cmd = $this->cmd() ;
	croak "command not specified" unless $cmd ;
	
	# Add niceness
	my $nice = $this->nice() ;
	if (defined($nice))
	{
		$cmd = "nice -n $nice $cmd" ;
	}
	
	
	# clear vars
	$this->status(0) ;
	$this->results([]) ;

	# Check arguments
	my $args = $this->check_args() ;

	# If specified, use logging output
	$this->log("== Run: $cmd $args ==\n") ;

	# Run command and save results
	my @results ;
	my $rc ;

	my $timeout = $this->timeout() ;
	if (defined($timeout))
	{
		# Run command with timeout
		($rc, @results) = $this->_run_timeout($cmd, $args, $timeout) ;		
	}
	else
	{
		# run command
		($rc, @results) = $this->_run_cmd($cmd, $args) ;		
	}

	# If specified, use logging output
	$this->log(@results) ;
	
	# Update vars
	$this->status($rc) ;
	chomp foreach (@results) ;
	$this->results(\@results) ;
	
	return($rc) ;
}

#--------------------------------------------------------------------------------------------

=item C<App::Framework::Base::Run-E<gt>run_results([%args])>

Execute a command, return output lines

=cut

sub run_results
{
	my $this = shift ;
	my (%args) = @_ ;

	$this->run(%args) ;
	
	return(@{$this->results()}) ;
}


#--------------------------------------------------------------------------------------------

=item C<App::Framework::Base::Run-E<gt>run_cmd($cmd, [%args])>

Execute a specified command, return exit status (0=success)

=cut

sub run_cmd
{
	my $this = shift ;
	my ($cmd, %args) = @_ ;
	
	return $this->run('cmd' => $cmd, %args) ;
}

#--------------------------------------------------------------------------------------------

=item C<App::Framework::Base::Run-E<gt>run_cmd_results($cmd, [%args])>

Execute a specified command, return output lines

=cut

sub run_cmd_results
{
	my $this = shift ;
	my ($cmd, %args) = @_ ;

	$this->run_cmd($cmd, %args) ;
	
	return(@{$this->results()}) ;
}

#--------------------------------------------------------------------------------------------

=item C<App::Framework::Base::Run-E<gt>clear_args()>

Clear out command args (ready for calls of the add_args method)

=cut

sub clear_args
{
	my $this = shift ;

	my $args = $this->args('') ;

	return $args ;
}

#--------------------------------------------------------------------------------------------

=item C<App::Framework::Base::Run-E<gt>add_args($args)>

Add arguments from parameter $args.

If $args is scalar, append to existing arguments with a preceding space
If $args is an array, append each to args
If $args is a hash, append the args as an 'option' / 'value' pair. If 'value' is not defined, then just set the option.

=cut

sub add_args
{
	my $this = shift ;
	my ($arg_ref) = @_ ;

	my $args = $this->args() ;
	
	if (ref($arg_ref) eq 'SCALAR')
	{
		
	}
	
die "Method not implemented" ;

	return $args ;
}



#--------------------------------------------------------------------------------------------

=item C<App::Framework::Base::Run-E<gt>check_args()>

Ensure arguments are correct

=cut

sub check_args
{
	my $this = shift ;

	my $args = $this->args() ;
	
	# If there is no redirection, just add redirect 2>1
	if ($args !~ /\>/)
	{
		$args .= " 2>&1" ;
	}
	
	return $args ;
}

#--------------------------------------------------------------------------------------------

=item C<App::Framework::Base::Run-E<gt>print_run([%args])>

Display the full command line as if it was going to be run

=cut

sub print_run
{
	my $this = shift ;
	my (%args) = @_ ;

	# See if this is a class call
	$this = $this->check_instance() ;

	# Set any specified args
	$this->set(%args) ;

	# Get command
	my $cmd = $this->cmd() ;
	croak "command not specified" unless $cmd ;
	
	# Check arguments
	my $args = $this->check_args() ;

	print "$cmd $args\n" ;
}


# ============================================================================================
# PRIVATE METHODS
# ============================================================================================

#----------------------------------------------------------------------
# Run command with no timeout
#
sub _run_cmd
{
	my $this = shift ;
	my ($cmd, $args) = @_ ;
	
	my @results ;
#	@results = `$cmd $args` unless $this->option('norun') ;
	@results = `$cmd $args` unless $this->norun() ;
	my $rc = $? ;

	# if it's defined, call the progress checker for each line
	my $progress = $this->progress() ;
	if (defined($progress))
	{
		my $state_href = {} ;
		foreach (@results)
		{
			&$progress($_, $state_href) ;
		}
	}

	
	# if it's defined, call the results checker for each line
	$rc ||= $this->_check_results(\@results) ;

	return ($rc, @results) ;
}

#----------------------------------------------------------------------
#Execute a command in the background, gather output, return status.
#If timeout is specified (in seconds), process is killed after the timeout period.
#
#TODO: Need to handle errors better, rather than just die-ing
#
sub _run_timeout
{
	my $this = shift ;
	my ($cmd, $args, $timeout) = @_ ;

	# Run command and save results
	my @results ;

	# Run command but time it and kill it when timed out
	my $old_sig_alrm = $SIG{ALRM} ;
	if ($timeout)
	{
		$SIG{ALRM} = sub { 
			# normal execution
			die "timeout" ;
		};
	}

	# if it's defined, call the progress checker for each line
	my $progress = $this->progress() ;
	my $state_href = {} ;
	my $linenum = 0 ;

	# Run inside eval to catch timeout		
	my $pid ;
	my $rc = 0 ;
	my $endtime = (time + $timeout) ;
	eval 
	{
		alarm($timeout) if $timeout;
		$pid = open my $proc, "$cmd $args |" or die "Error: Unable to fork $cmd : $!" ;

		while(<$proc>)
		{
			push @results, $_ ;

			++$linenum ;

			# if it's defined, call the progress checker for each line
			if (defined($progress))
			{
				&$progress($_, $linenum, $state_href) ;
			}

			# if it's defined, check timeout
			if ($timeout && (time > $endtime))
			{
				$endtime=0;
				last ;
			}
		}
		alarm(0) if $timeout ;
		$rc = $? ;
	};
	if ($@)
	{
		$rc ||= 1 ;
		if ($@ =~ /timeout/)
		{
			# timed out  - stop command
			kill('INT', $pid) ;
		}
		else
		{
			# Failed
			alarm(0) if $timeout ;
			die $@ ;
		}
	}
	$SIG{ALRM} = $old_sig_alrm ;

	# if it's defined, call the results checker for each line
	$rc ||= $this->_check_results(\@results) ;

	return($rc, @results) ;
}

#----------------------------------------------------------------------
# Check the results calling the check_results() hook if defined
#
sub _check_results
{
	my $this = shift ;
	my ($results_aref) = @_ ;

	my $rc = 0 ;
	
	# If it's defined, run the check results hook
	my $check_results = $this->check_results() ;
	if (defined($check_results))
	{
		$rc = &$check_results($results_aref) ;
	}

	return $rc ;
}

# ============================================================================================
# END OF PACKAGE
1;

__END__


