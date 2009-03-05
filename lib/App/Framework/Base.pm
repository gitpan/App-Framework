package App::Framework::Base ;

=head1 NAME

App::Framework::Base - Base application object

=head1 SYNOPSIS

use App::Framework::Base ;

our @ISA = qw(App::Framework::Base) ; 

sub new { ... }

sub exit { ... }

sub options { ... }


=head1 DESCRIPTION

Base class for applications. Expected to be derived from by an implementable class (like App::Framework::Modules::Script).

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

our $VERSION = "1.007" ;


#============================================================================================
# USES
#============================================================================================
use App::Framework::Base::Object::Logged ;
use App::Framework::Base::Run ;
use App::Framework::Base::Sql ;
use App::Framework::Config ;

use File::Basename ;
use File::Spec ;
use File::Path ;
use File::Copy ;
##use Date::Manip ;

use Cwd ; 
use Pod::Usage ;
use Getopt::Long qw(:config no_ignore_case) ;


#============================================================================================
# OBJECT HIERARCHY
#============================================================================================
our @ISA = qw(App::Framework::Base::Object::Logged) ; 

#============================================================================================
# GLOBALS
#============================================================================================

my $POD_HEAD =	"=head" ;
my $POD_OVER =	"=over" ;


=back

=head2 FIELDS

The following fields should be defined either in the call to 'new()' or as part of the application configuration in the __DATA__ section:

 * name = Program name (default is name of program)
 * summary = Program summary text
 * synopsis = Synopsis text (default is program name and usage)
 * description = Program description text
 * history = Release history information
 * version = Program version (default is value of 'our $VERSION')
 * options = Definition of program options (see below)
 * nameargs = Definition of the program arguments and their intended usage (see below)
 * sql = Definition of sql database connection & queries (see below)
 
 * pre_run_fn = Function called before run() function (default is application-defined 'pre_run' subroutine if available)
 * run_fn = Function called to execute program (default is application-defined 'run' subroutine if available)
 * post_run_fn = Function called after run() function (default is application-defined 'post_run' subroutine if available)
 * usage_fn = Function called to display usage information (default is application-defined 'usage' subroutine if available)

During program execution, the following values can be accessed:

 * arglist = Array of the program arguments, in the order they were specified
 * arghash = Hash of the program arguments, named by the 'nameargs' field
 * package = Name of the application package (usually main::)
 * filename = Full filename path to the application (after following any links)
 * progname = Name of the program (without path or extension)
 * progpath = Pathname to program
 * progext = Extension of program
 * runobj = L<App::Framework::Base::Run> object
 

=over 4

=cut

my %FIELDS = (
	## Object Data
	
	# User-specified
	'name'			=> '',
	'summary'		=> '',
	'synopsis'		=> '',
	'description'	=> '',
	'history'		=> '',
	'version'		=> undef,
	'options'		=> undef,
	'arglist'		=> [],
	'nameargs'		=> undef,
	'arghash'		=> {},
	'sql'			=> undef,

	'pre_run_fn'	=> undef,	
	'run_fn'		=> undef,	
	'post_run_fn'	=> undef,
	'usage_fn'		=> undef,
	
	'exit_type'		=> 'exit',
	
	# Created during init
	'package'		=> undef,
	'filename'		=> undef,
	'progname'		=> undef,
	'progpath'		=> undef,
	'progext'		=> undef,
	
	'runobj'		=> undef,
	
	'_data'				=> [],
	'_data_hash'		=> {},
	'_option_fields'	=> [],
	'_get_options'		=> [],
	'_options'			=> {},
	'_options_list'		=> [],
	'_arg_info'			=> {},
	
	# Somewhere to store the list of Sql objects. List is in order of creation, hash is keyed off database name
	'_sql_list'			=> [],
	'_sql_hash'			=> {},
		
) ;

# Set of default options
my @BASE_OPTIONS = (
	['debug=s',			'Set debug level', 	'Set the debug level value', ],
	['h|"help"',		'Print help', 		'Show brief help message then exit'],
	['man',				'Full documentation', 'Show full man page then exit' ],
	['pod',				'Output full pod', 	'Show full man page as pod then exit' ],

	['dbg-data',		'Debug option: Show __DATA__', 				'Show __DATA__ definition in script then exit' ],
	['dbg-data-array',	'Debug option: Show all __DATA__ items', 	'Show all processed __DATA__ items then exit' ],
) ;

our %LOADED_MODULES ;


#============================================================================================
# CONSTRUCTOR 
#============================================================================================

=back

=head2 CONSTRUCTOR METHODS

=over 4

=cut

=item C<App::Framework::Base-E<gt>new([%args])>

Create a new App::Framework::Base.

The %args are specified as they would be in the B<set> method, for example:

	'mmap_handler' => $mmap_handler

The full list of possible arguments are :

	'fields'	=> Either ARRAY list of valid field names, or HASH of field names with default values 

=cut

sub new
{
	my ($obj, %args) = @_ ;

	my $class = ref($obj) || $obj ;
	
	my $caller = delete $args{'_caller'} || 0 ;

	# Create object
	my $this = $class->SUPER::new(%args) ;
	
	# Set up error handler
	$this->set('catch_fn' => sub {$this->catch_error(@_);} ) ;

# TODO: fix debug setting
#$this->debug(2);

	## Get caller information
	my ($package, $filename, $line, $subr, $has_args, $wantarray) = caller($caller) ;
	$this->set(
		'package'	=> $package,
		'filename'	=> $filename,
	) ;

	## now import packages into the caller's namespace
	$this->_import() ;


	## Set program info
	$this->set_paths($filename) ;
	
	## process any __DATA__
	$this->_process_data() ;

	## set up functions
	foreach my $fn (qw/pre_run run post_run usage/)
	{
		# Only add function if it's not already been specified
		$this->register_fn($fn) ;
	}

	## Get version
	$this->register_scalar('VERSION', 'version') ;

	## Ensure name set
	if (!$this->name())
	{
		$this->name($this->progname() ) ;		
	}

	## Create some objects
	$this->runobj(App::Framework::Base::Run->new()) ;
	
	## Set up default timezone
	if (exists($LOADED_MODULES{'Date::Manip'}))
	{
		my $tz = $App::Frameowrk::Config::DATE_TZ || 'GMT' ;
		my $fmt = $App::Frameowrk::Config::DATE_FORMAT || 'non-US' ;
		eval {
		&Date_Init("TZ=$tz", "DateFormat=$fmt") ;
		} ;
	}

	return($this) ;
}



#============================================================================================

=back

=head2 CLASS METHODS

=over 4

=cut

#============================================================================================

#-----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>init_class([%args])>

Initialises the App::Framework::Base object class variables.

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

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>allowed_class_instance()>

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

=item C<App::Framework::Base-E<gt>set_paths($filename)>

Get the full path to this application (follows links where required)

=cut

sub set_paths
{
	my $this = shift ;
	my ($filename) = @_ ;

	# Follow links
	$filename = File::Spec->rel2abs($filename) ;
	while ( -l $filename)
	{
		$filename = readlink $filename ;
	}
	
	# Get info
	my ($progname, $progpath, $progext) = fileparse($filename, '\.[^\.]+') ;
	if (ref($this))
	{
		# set if not class call
		$this->set(
			'progname'	=> $progname,
			'progpath'	=> $progpath,
			'progext'	=> $progext,
		) ;
	}

	# Set up include path to add script home + script home /lib subdir
	my %inc = map {$_=>1} @INC ;
	foreach my $path ($progpath, "$progpath/lib")
	{
		# add new paths
     	unshift(@INC,$path) unless exists $inc{$path} ;
     	$inc{$path} = 1 ;
		push @INC, $path unless exists $inc{$path} ;
	}
}

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>catch_error($error)>

Function that gets called on errors. $error is as defined in L<App::Framework::Base::Object::ErrorHandle>

=cut

sub catch_error
{
	my $this = shift ;
	my ($error) = @_ ;

# Does nothing!

}


#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>sql([$name | $sql_spec])>

Create or return L<App::Framework::Base::Sql> object(s)

=cut

sub sql
{
	my $this = shift ;
	my ($spec) = @_ ;
	
	my $sql ;
		
	my $sql_aref = $this->_sql_list() ;
	my $sql_href = $this->_sql_hash() ;

	## If a ref, then create
	if (ref($spec))
	{
		# Create a list of specifications to work through
		my @specs ;
		if (ref($spec) eq 'HASH')
		{
			push @specs, $spec ;
		}
		elsif (ref($spec) eq 'ARRAY')
		{
			push @specs, @$spec ;
		}
		
		# Work through each specification
		foreach my $sql_spec (@specs)
		{
			if (ref($spec) ne 'HASH')
			{
				# Bugger - stop here
				$this->throw_fatal("Sql specification is not a HASH") ;	
			}
			
			# Need a database name
			if (!exists($sql_spec->{'database'}))
			{
				$this->throw_fatal("Sql specification must contain database name") ;	
			}
			
			my $name = $sql_spec->{'database'} ;
			
			# Create new Sql object & check for errors
			my $sql = App::Framework::Base::Sql->new(%$sql_spec) ;
			if (!$sql)
			{
				$this->throw_fatal("Unable to create Sql object") ;
			}
			elsif ($sql->error())
			{
				$this->rethrow_error($sql->error()) ;
			}

			# Set up error handler
			$sql->set('catch_fn' => sub {$this->catch_error(@_);} ) ;
			
			# Add to list
			push @$sql_aref, $sql ;
			$sql_href->{$name} = $sql ;
			
		}	

		# Just grab first from list
		$sql = $sql_aref->[0] ;
		
	}
	
	## Otherwise return created sql
	else
	{
		if ($spec)
		{
			$this->throw_warning("Sql $spec is not created") if (!exists($sql_href->{$spec})) ;
			
			$sql = $sql_href->{$spec} ;
		}
		else
		{
			# Just grab first from list
			$sql = $sql_aref->[0] ;
		}
	}

	return $sql ;
}


#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>sql_query($query_name [, @args])>

Run an SQL query

=cut

sub sql_query
{
	my $this = shift ;
	my ($query_name, @args) = @_ ;
	
	my $sql = $this->sql() ;

	return $sql->sth_query($query_name, @args) ;	
}

#----------------------------------------------------------------------------

=item C<App::Base-E<gt>sql_next($query_name)>

Returns hash ref to next row (as a result of query). Uses prepared STH name $query_name
(as created by sth_create method), or default name (as created by query method)

=cut

sub sql_next
{
	my $this = shift ;
	my ($query_name) = @_ ;
	
	my $sql = $this->sql() ;
	
#	## Ensure query has been called first
#	$sql->sth_query($query_name) ;
	
	## return hash
	return $sql->next($query_name) ;	
}



#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>sql_query_all($query_name [, @args])>

Run an SQL query and return all the results in an array

=cut

sub sql_query_all
{
	my $this = shift ;
	my ($query_name, @args) = @_ ;
	
	my $sql = $this->sql() ;

	return $sql->sth_query_all($query_name, @args) ;	
}

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>sql_from_data($name)>

Execute the (possible sequence of) command(s) stored in a named __DATA__ area

=cut

sub sql_from_data
{
	my $this = shift ;
	my ($name) = @_ ;
	
	my $sql = $this->sql() ;
	
	# Get named data
	my $sql_text = $this->data($name) ;
	
	if ($sql_text)
	{
		## process the data
		$sql->do_sql_text($sql_text) ;
	}
	else
	{
		$this->throw_error("Data section $name contains no SQL") ;	
	}

	return $sql ;	
}



#= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

=back

=head3 Run command methods

=over 4

=cut



#--------------------------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>run_results()>

Return output lines from running a command

NOTE: This interface is DIFFERENT to that employed by the underlying Run object. This form is meant to be easier
to use for Applications.

=cut

sub run_results
{
	my $this = shift ;
	
	return(@{$this->runobj()->results()}) ;
}


#--------------------------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>run_cmd($cmd, [$cmd_args])>

Execute a specified command, return either the exit status [0=success] (in scalar context) or the 
array of lines output by the command (in array context)

NOTE: This interface is DIFFERENT to that employed by the underlying Run object. This form is meant to 
be easier to use for Applications.


=cut

sub run_cmd
{
	my $this = shift ;
	my ($cmd, $cmd_args) = @_ ;
	
	my $rc = $this->runobj()->run('cmd' => $cmd, 'args' => $cmd_args) ;
	
	return wantarray ? $this->run_results() : $rc ;
}

#= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

=back

=head3 POD methods

=over 4

=cut



#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>pod()>

Return full pod of application

=cut

sub pod
{
	my $this = shift ;

	my $pod = 
		$this->pod_head() .
		$this->pod_options() .
		$this->pod_description() .
		"\n=cut\n" ;
	return $pod ;
}	
	
#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>pod_head()>

Return pod heading of application

=cut

sub pod_head
{
	my $this = shift ;

	my $name = $this->name() ;
	my $summary = $this->summary() ;
	my $synopsis = $this->synopsis() ;
	my $version = $this->version() ;

	my $pod =<<"POD_HEAD" ;

${POD_HEAD}1 NAME

$name (v$version) - $summary

${POD_HEAD}1 SYNOPSIS

$synopsis

Options:

POD_HEAD

	# Cycle through
	my $options_fields_aref = $this->_option_fields() ;
	foreach my $option_entry_href (@$options_fields_aref)
	{
		my $default = "" ;
		if ($option_entry_href->{'default'})
		{
			$default = "[Default: $option_entry_href->{'default'}]" ;
		}
		$pod .= sprintf "       -%-20s $option_entry_href->{summary}\t$default\n", $option_entry_href->{'pod_spec'} ;
	}
	
	unless (@$options_fields_aref)
	{
		$pod .= "       NONE\n" ;
	}

	return $pod ;
}

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>pod_options()>

Return pod of options of application

=cut

sub pod_options
{
	my $this = shift ;

	my $pod =<<"POD_OPTIONS" ;

${POD_HEAD}1 OPTIONS

${POD_OVER} 8

POD_OPTIONS

	# Cycle through
	my $options_fields_aref = $this->_option_fields() ;
	foreach my $option_entry_href (@$options_fields_aref)
	{
		my $default = "" ;
		if ($option_entry_href->{'default'})
		{
			$default = "[Default: $option_entry_href->{'default'}]" ;
		}

##		$pod .= "=item B<-$option_entry_href->{pod_spec}> $default\n" ;
		$pod .= "=item -$option_entry_href->{pod_spec} $default\n" ;
		$pod .= "\n$option_entry_href->{description}\n\n" ;
	}

	unless (@$options_fields_aref)
	{
		$pod .= "       NONE\n" ;
	}

	$pod .= "\n=back\n\n" ;

	return $pod ;
}

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>pod_description()>

Return pod of description of application

=cut

sub pod_description
{
	my $this = shift ;

	my $description = $this->description() ;

	my $pod =<<"POD_DESC" ;

${POD_HEAD}1 DESCRIPTION

$description
  
POD_DESC
	
	return $pod ;
}


#= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

=back

=head3 Options methods

=over 4

=cut



#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>getopts()>

Convert the (already processed) options list into settings. 

Returns result of calling GetOptions

=cut

sub getopts
{
	my $this = shift ;

	my $get_options_aref = $this->_get_options() ;

	# Parse options using GetOpts
	my $ok = GetOptions(@$get_options_aref) ;

	# If ok, get any specified filenames
	if ($ok)
	{
		# Get args
		my $arglist = $this->arglist() ;
		push @$arglist, @ARGV ;

		$this->prt_data("getopts() : arglist=", $arglist) if $this->debug >= 2 ;
	}
	

	return $ok ;
}

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>options([$options_aref])>

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

Called with an ARRAY ref either when an ARRAY ref is specified in the new() call or when the
__DATA__ specification is being processed. 

=cut

sub options
{
	my $this = shift ;
	my ($options_aref) = @_ ;

print "options($options_aref)\n" if $this->debug()>=2 ;

if ( $this->debug()>=3 )
{
$this->dump_callstack() ;
}

	my $options_href = $this->_options() ;
	
	if ($options_aref)
	{
		my $get_options_aref = $this->_get_options() ;
		my $options_fields_aref = $this->_option_fields() ;

$this->prt_data("options() set: options spec=", $options_aref) if $this->debug()>=2 ;

		# If we're setting options, then add our extra set
		my $combined_options = [@BASE_OPTIONS, @$options_aref] ;
		$options_aref = $combined_options ;
		
		# Save
		$this->_options_list($options_aref) ;
		
		# Cycle through
		foreach my $option_entry_aref (@$options_aref)
		{
			my ($option_spec, $summary, $description, $default_val) = @$option_entry_aref ;
			
			# If option starts with - then remove it
			$option_spec =~ s/^-// ;
			
			# Get field name
			my $field = $option_spec ;
			if ($option_spec =~ /[\'\"](\w+)[\'\"]/)
			{
				$field = $1 ;
				$option_spec =~ s/[\'\"]//g ;
			}
			$field =~ s/\|.*$// ;
			$field =~ s/\=.*$// ;
			
			# Set default if required
			$options_href->{$field} = $default_val if (defined($default_val)) ;
			
			# re-create spec with field name highlighted
			my $spec = $option_spec ;
			my $arg = "";
			if ($spec =~ s/\=(.*)$//)
			{
				$arg = $1 ;
			}
print "options() set: pod spec=$spec arg=$arg\n" if $this->debug()>=2 ;

			my @fields = split /\|/, $spec ;
			if (@fields > 1)
			{
				# put field name first
				$spec = "'$field'" ;
				foreach my $fld (@fields)
				{
					next if $fld eq $field ;
					
	print " + $fld\n" if $this->debug()>=2 ;
					$spec .= '|' if $spec;
					$spec .= $fld ;
				}	
			}
			$spec .= " <arg>" if $arg ;
print "options() set: final pod spec=$spec arg=$arg\n" if $this->debug()>=2 ;
				
			# Add to Getopt list
			push @$get_options_aref, $option_spec => \$options_href->{$field} ;
			push @{$options_fields_aref}, {
					'field'=>$field, 
					'spec'=>$option_spec, 
					'summary'=>$summary, 
					'description'=>$description,
					'default'=>$default_val,
					'pod_spec'=>$spec,
			} ;
		}
$this->prt_data("options() set: Getopts spec=", $get_options_aref) if $this->debug()>=2 ;
$this->prt_data("_option_fields() set: ", $options_fields_aref) if $this->debug()>=2 ;
		
	}
print "options() - END\n" if $this->debug()>=2 ;

	return %$options_href ;
}

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>option($option_name)>

Returns the value of the named option

=cut

sub option
{
	my $this = shift ;
	my ($option_name) = @_ ;

	my $options_href = $this->_options() ;
	return exists($options_href->{$option_name}) ? $options_href->{$option_name} : undef ;
}

#= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

=back

=head3 Application execution methods

=over 4

=cut




#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>go()>

Execute the application.
 
=cut


sub go
{
	my $this = shift ;

	$this->pre_run() ;
	$this->run() ;
	$this->post_run() ;

	$this->exit(0) ;
}

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>pre_run()>

Set up before running the application.
 
=cut


sub pre_run
{
	my $this = shift ;

	## First ensure that options() method has been called with something. This
	#  ensures that the default options are set
	my %opts = $this->options() ;
	if (! scalar keys %opts)
	{
		$this->options([]) ;
	}

	## Get options
	# NOTE: Need to do this here so that derived objects work properly
	my $ret = $this->getopts() ;
	
	## Expand any variables in the data
	$this->_expand_vars() ;

	## Process other settings
	$this->_process_nameargs() ;
	$this->_check_synopsis() ;


	# Handle options errors here after expanding variables
	unless ($ret)
	{
		$this->usage('opt') ;
		$this->exit(1) ;
	} 

	## function
	$this->_exec_fn('pre_run', $this) ;
}

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>run()>

Execute the application.
 
=cut


sub run
{
	my $this = shift ;

	## Handle special options
	my %opts = $this->options() ;
	if ($opts{'man'} || $opts{'help'})
	{
		my $type = $opts{'man'} ? 'man' : 'help' ;
		$this->usage($type) ;
		$this->exit(0) ;
	}
	if ($opts{'pod'})
	{
		print $this->pod() ;
		$this->exit(0) ;
	}
	
	## Debug
	if ($opts{'debug-show-data'})
	{
		$this->_show_data() ;
		$this->exit(0) ;
	}
	if ($opts{'debug-show-data-array'})
	{
		$this->_show_data_array() ;
		$this->exit(0) ;
	}

	## Check args
	$this->_check_args() ;

	## Execute function
	$this->_exec_fn('run', $this) ;
}

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>post_run()>

Tidy up after the application.
 
=cut


sub post_run
{
	my $this = shift ;

	## Execute function
	$this->_exec_fn('post_run', $this) ;
}



#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>exit()>

Exit the application.
 
=cut


sub exit
{
	my $this = shift ;
	my ($exit_code) = @_ ;

die "Expected generic exit to be overridden: exit code=$exit_code" ;
}

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>usage()>

Show usage

=cut

sub usage
{
	my $this = shift ;
	my ($level) = @_ ;

	$this->_exec_fn('usage', $this, $level) ;

}

#= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

=back

=head3 __DATA_ access methods

=over 4

=cut

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>data([$name])>

Returns the lines for the named __DATA__ section. If no name is specified
returns the first section. If an ARRAY is required, returns the array; otherwise
concatenates the lines with "\n".

Sections are named by adding the name after __DATA__:

	__DATA__ template1
	
creates a data section called 'template1'

Returns undef if no data found, or no section with specified name

=cut

sub data
{
	my $this = shift ;
	my ($name) = @_ ;
	my $data_ref ;
	
	
	if ($name)
	{
		my $data_href = $this->_data_hash() ;
		if (exists($data_href->{$name}))
		{
			$data_ref = $data_href->{$name} ;
		}		
	}
	else
	{
		my $data_aref = $this->_data() ;
		if (@$data_aref)
		{
			$data_ref = $data_aref->[0] ;
		}
		
	}
	return undef unless $data_ref ;
	
	return wantarray ? @$data_ref : join "\n", @$data_ref ;	
}



#= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

=back

=head3 Utility methods

=over 4

=cut





#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>file_split($fname)>

Utility method

Parses the filename and returns the full path, basename, and extension.

Effectively does:

	$fname = File::Spec->rel2abs($fname) ;
	($path, $base, $ext) = fileparse($fname, '\.[^\.]+') ;
	return ($path, $base, $ext) ;

=cut

sub file_split
{
	my $this = shift ;
	my ($fname) = @_ ;

	$fname = File::Spec->rel2abs($fname) ;
	my ($path, $base, $ext) = fileparse($fname, '\.[^\.]+') ;
	return ($path, $base, $ext) ;
}


# ============================================================================================

=back

=head2 PRIVATE METHODS

=over 4

=cut

# ============================================================================================


#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>_exec_fn($function, @args)>

Execute the registered function (if one is registered). Passes @args to the function.
 
=cut


sub _exec_fn
{
	my $this = shift ;
	my ($fn, @args) = @_ ;

	# Append _fn to function name, get the function, and call it if it's defined
	my $fn_name = "${fn}_fn" ;
	my $sub = $this->$fn_name() ;

print "_exec_fn($fn) this=$this fn=$fn_name sub=$sub\n" if $this->debug()>=2 ;

	&$sub(@args) if $sub ;
}

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>_import()>

Load modules into caller package namespace.
 
=cut

sub _import 
{
	my $this = shift ;

	my $package = $this->package() ;
	
	# Debug
	if ($this->debug())
	{
		unless ($package eq 'main')
		{
			print "\n $package symbols:\n"; dumpvar($package) ;
		}
	}

	## Load useful modules into caller package	
	my $code ;
	
	# Set of useful modules
	foreach my $mod (@App::Framework::Config::MODULES)
	{
		$code .= "use $mod;" ;
	}
	
	# Get modules into this namespace
	foreach my $mod (@App::Framework::Config::MODULES)
	{
		eval "use $mod;" ;
		if ($@)
		{
			warn "Unable to load module $mod\n" ;
		}	
		else
		{
			++$LOADED_MODULES{$mod} ;
		}
	}

	# Get modules into caller package namespace
	eval "package $package;\n$code\n" ;
#	if ($@)
#	{
#		warn "Unable to load modules : $@\n" ;
#	}	
}


#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>register_fn()>

Register a function provided as a subroutine in the caller package as a run method
in this object.

Will only set the field value if it's not already set.

=cut

sub register_fn 
{
	my $this = shift ;
	my ($function) = @_ ;
	
	my $field ="${function}_fn" ; 

	$this->register_var('CODE', $function, $field) unless $this->$field() ;
}

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>register_scalar($external_name, $field_name)>

Read the value of a variable in the caller package and copy that value as a data field
in this object.

Will only set the field value if it's not already set.

=cut

sub register_scalar 
{
	my $this = shift ;
	my ($external_name, $field_name) = @_ ;
	
	$this->register_var('SCALAR', $external_name, $field_name) unless $this->$field_name() ;
}

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>register_var($type, $external_name, $field_name)>

Read the value of a variable in the caller package and copy that value as a data field
in this object. $type specifies the variable type: 'SCALAR', 'ARRAY', 'HASH', 'CODE'
 
NOTE: This method overwrites the field value irrespective of whether it's already set.

=cut

sub register_var 
{
	my $this = shift ;
	my ($type, $external_name, $field_name) = @_ ;

	my $package = $this->package() ;

    local (*alias);             # a local typeglob

print "register_var($type, $external_name, $field_name)\n" if $this->debug()>=2 ;

    # We want to get access to the stash corresponding to the package
    # name
no strict "vars" ;
no strict "refs" ;
    *stash = *{"${package}::"};  # Now %stash is the symbol table

	if (exists($stash{$external_name}))
	{
		*alias = $stash{$external_name} ;

print " + found $external_name in $package\n" if $this->debug()>=2 ;

		if ($type eq 'SCALAR')
		{
			if (defined($alias))
			{
				$this->set($field_name => $alias) ;
			}
		}
		if ($type eq 'ARRAY')
		{
			if (defined(@alias))
			{
				$this->set($field_name => \@alias) ;
			}
		}
		if ($type eq 'HASH')
		{
			if (defined(%alias))
			{
				$this->set($field_name => \%alias) ;
			}
		}
		elsif ($type eq 'CODE')
		{
			if (defined(&alias))
			{
print " + + Set $type - $external_name as $field_name\n" if $this->debug()>=2 ;
				$this->set($field_name => \&alias) ;
			}
		}

	}
}


#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>_show_data()>

Show the __DATA__ defined in the main script. Run when option --debug-show-data is used
 
=cut

sub _show_data 
{
	my $this = shift ;
	my ($package) = @_ ;
	

    local (*alias);             # a local typeglob

    # We want to get access to the stash corresponding to the package
    # name
no strict "vars" ;
no strict "refs" ;
    *stash = *{"${package}::"};  # Now %stash is the symbol table

	if (exists($stash{'DATA'}))
	{
		*alias = $stash{'DATA'} ;

		print "## DATA ##\n" ;
		my $line ;
		while (defined($line=<alias>))
		{
			print "$line" ;
		}
		print "## DATA END ##\n" ;

	}
}


#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>_show_data_array()>

Show data array (after processing the __DATA__ defined in the main script). 

Run when option --debug-show-data-arry is used
 
=cut

sub _show_data_array
{
	my $this = shift ;

	my $data_aref = $this->_data() ;
	my $data_href = $this->_data_hash() ;
	
	# Get addresses from hash
	my %lookup = map { $data_href->{$_} => $_ } keys %$data_href ;
	
	# Show each data
	foreach my $data_ref (@$data_aref)
	{
		my $name = '' ;
		if (exists($lookup{$data_ref}))
		{
			$name = $lookup{$data_ref} ;
		}
		print "\n__DATA__ $name\n" ;
		
		foreach my $data (@$data_ref)
		{
			print "$data\n" ;
		}
		print "--------------------------------------\n" ;
	}

}



#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>_process_data()>

If caller package namespace has __DATA__ defined then use that information to set
up object parameters.

Recognised entries are:

 [SUMMARY]
 Application summary text
 
 [SYNOPSIS]
 Application description text
 
 [DESCRIPTION]
 Application description text
 
 [OPTIONS]
 Definition of program options. Specified in the form:
 
 -<opt>[=s]		Summary of option
 Description of option

Any subsequent text of the form __DATA__ will split the data into a new section...  
 

=cut

sub _process_data 
{
	my $this = shift ;

	my $package = $this->package() ;

print "Process data from package $package" if $this->debug() ;

    local (*alias, *stash);             # a local typeglob

    # We want to get access to the stash corresponding to the package
    # name
no strict "vars" ;
no strict "refs" ;
    *stash = *{"${package}::"};  # Now %stash is the symbol table

	if (exists($stash{'DATA'}))
	{
		my @data ;
		my %data ;
		my $data_aref = [] ;
		
		push @data, $data_aref ;
		
		*alias = $stash{'DATA'} ;

print "Reading __DATA__\n" if $this->debug() ;

		## Read data in - first split into sections
		my $line ;
		while (defined($line=<alias>))
		{
			chomp $line ;
print "DATA: $line\n" if $this->debug()>=2 ;
			
			if ($line =~ m/^\s*__DATA__/)
			{
print "+ New __DATA__\n" if $this->debug()>=2 ;
				# Start a new list
				$data_aref = [] ;
				push @data, $data_aref ;

print "+ Data list size=",scalar(@data),"\n" if $this->debug()>=2 ;
				
				# Check for name
#				if ($line =~ m/__DATA__\s*([\w\:]+)/)
				if ($line =~ m/__DATA__\s*(\S+)/)
				{
					my $name = $1 ;
					$data{$name} = $data_aref ;
print "+ + named __DATA__ : $name\n" if $this->debug()>=2 ;
				}
				
			}
			elsif ($line =~ m/^\s*__END__/ )
			{
print "+ __END__\n" if $this->debug()>=2 ;
				last ;
			}
			elsif ($line =~ m/^\s*__#/ )
			{
print "+ __# comment\n" if $this->debug()>=2 ;
				# skip
			}
			else
			{
				push @$data_aref, $line ;
			}
		}
$this->prt_data("Gathered data=", \@data) if $this->debug()>=2 ;

		# Store
		$this->_data(\@data) ;
		$this->_data_hash(\%data) ;

print "Processing __DATA__\n" if $this->debug() ;
		
		## Look at first section
		my $obj_settings=0;
		$data_aref = $data[0] ;
		my $field ;
		my @field_data ;
		foreach $line (@$data_aref)
		{
#print "field=$field : $line\n" ;

			if ($line =~ m/^\s*\[(\w+)\]/)
			{
				my ($new_field) = lc $1 ;
				
				# This is object settings, so need to remove from list
				$obj_settings=1;

#$this->prt_data(" + Handling field $field - data=", \@field_data) ;
				
				# Use the data found so far for this field
				$this->_handle_field($field, \@field_data) if $field ;
				
				# next field
				$field = $new_field ;
				@field_data = () ;

#print " + NEW field=$field\n" ;
				
			}
			elsif ($field)
			{
#print " + storing line\n" ;
				push @field_data, $line ;
			}
		}

		if ($field)
		{
			# Use the data found so far for this field
			$this->_handle_field($field, \@field_data) ;
		}

	}

}


#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>_handle_field($field_data_aref)>

Set the field based on the accumlated data

=cut

sub _handle_field 
{
	my $this = shift ;
	my ($field, $field_data_aref) = @_ ;

print "_handle_field($field, $field_data_aref)\n" if $this->debug()>=2 ;

	# Handle any existing field values
	if ($field eq 'options')
	{
		# Parse the data into options
		my @options = $this->_parse_options($field_data_aref) ;
		$this->options(\@options) ;
	}
	else
	{
		# Glue the lines together and set the field
		my $data = join "\n", @$field_data_aref ;

		# Remove leading/trailing space
		$data =~ s/^\s+// ;
		$data =~ s/\s+$// ;
			
		$this->set($field => $data) ;
	}
}


#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>_parse_options($data_aref)>

Parses option definition lines(s) of the form:
 
 -<opt>[=s]		Summary of option [default=<value>]
 Description of option

Optional [default] specification that sets the option to the default if not otherwised specified.

And returns an ARRAY in the format useable by the 'options' method. 

=cut

sub _parse_options 
{
	my $this = shift ;
	my ($data_aref) = @_ ;

print "_parse_options($data_aref)\n" if $this->debug()>=2 ;

	my @options ;
	
	# Scan through the options specification to create a number of options entries
	my ($spec, $summary, $description, $default_val) ;
	foreach my $line (@$data_aref)
	{
		if ($line =~ m/^\s*-([\'\"\w\|\=\%\@\+\{\:\,\}]+)\s+(.*?)\s*(\[default=([^\]]+)\]){0,1}\s*$/)
		{
			# New option
			my ($new_spec, $new_summary, $new_default, $new_default_val) = ($1, $2, $3, $4) ;
			print " + spec: $new_spec,  summary: $new_summary,  default: $new_default, defval=$new_default_val\n" if $this->debug()>=2 ;

			# Allow default value to be specified with "" or ''
			$new_default_val ||= "" ;
			$new_default_val =~ s/^['"](.*)['"]$/$1/ ;

			# Save previous option			
			if ($spec)
			{
				# Remove leading/trailing space
				$description ||= '' ;
				$description =~ s/^\s+// ;
				$description =~ s/\s+$// ;

				push @options, [$spec, $summary, $description, $default_val] ;
			}
			
			# update current
			($spec, $summary, $default_val, $description) = ($new_spec, $new_summary, $new_default_val, '') ;
		}
		elsif ($spec)
		{
			# Add to description
			$description .= "$line\n" ;
		}
	}

	# Save option
	if ($spec)
	{
		# Remove leading/trailing space
		$description ||= '' ;
		$description =~ s/^\s+// ;
		$description =~ s/\s+$// ;

		push @options, [$spec, $summary, $description, $default_val] ;
	}
	
	return @options ;
}

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>_expand_vars()>

Run through some of the application variables/fields and expand any instances of variables embedded
within the values.

Example:

	__DATA_  

	[SYNOPSIS]
	
	$name [options] <rrd file(s)>

Here the 'synopsis' field contains the $name field variable. This needs to be expanded to the value of $name.

NOTE: Currently this will NOT cope with cross references (so, if in the above example $name also contains a variable
then that variable may or may not be expanded before the synopsis field is processed)


=cut

sub _expand_vars 
{
	my $this = shift ;

print "_expand_vars() - START\n" if $this->debug()>=2 ;

	# Get hash of fields
	my %fields = $this->vars() ;

#$this->prt_data(" + fields=", \%fields) if $this->debug()>=2 ;
	
	# work through each field, create a list of those that have changed
	my %changed ;
	foreach my $field (sort keys %fields)
	{
		# Skip non-scalars
		next if ref($fields{$field}) ;
		
		# First see if this contains a '$'
		$fields{$field} ||= "" ;
		my $ix = index $fields{$field}, '$' ; 
		if ($ix >= 0)
		{
print " + + $field = $fields{$field} : index=$ix\n" if $this->debug()>=3 ;

			# Do replacement
			$fields{$field} =~ s{
								     \$                         # find a literal dollar sign
								     \{{0,1}					# optional brace
								    (\w+)                       # find a "word" and store it in $1
								     \}{0,1}					# optional brace
								}{
								    no strict 'refs';           # for $$1 below
								    if (defined $fields{$1}) {
								        $fields{$1};            # expand global variables only
								    } else {
								        "\${$1}";  				# leave it
								    }
								}egx;


print " + + + new = $fields{$field}\n" if $this->debug()>=3 ;
			
			# Add to list
			$changed{$field} = $fields{$field} ;
		}
	}

$this->prt_data(" + changed=", \%changed) if $this->debug()>=2 ;
	
	# If some have changed then set them
	if (keys %changed)
	{
print " + + set changed\n" if $this->debug()>=2 ;
		$this->set(%changed) ;
	}

print "_expand_vars() - END\n" if $this->debug()>=2 ;
}


#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>_process_nameargs($nameargs)>

The 'nameargs' options allows specification of args as names and also specification of
certain properties of those arguments. Once the args have been named, they can be accessed
via the arghash() method to provide a hash of name/value pairs (rather than using the arglist method)

Argument properties:
 * able to name each arg + return this hash as argshash() (?)
 * specify if arg is optional
 * specify if arg is a file/dir
 * specify if arg is expected to exist (autocheck existence; autocreate dir if output?)
 * specify if arg is an executable (autosearch PATH so don't need to specify full path?)
 * ?flag arg as an input or output (for filters, simple in/out scripts)?
 * ?specify arg expected to be a link?
 
Specification is the format:
   name:flags[, ]

i.e. a space and/or comma separated list of names with optional flags (indicated by a leading :)

Valid flags: 
  ? arg is optional
  f file
  d dir
  x executable
  e exists
  i input
  o output
  - dummy flag (see below)

If names not required, can just specify flags e.g.:

  :- :- :- :?

Examples:
  in:if out:of	- Arg named 'in' is an input file; arg named 'out' is an output file
  dir:d temp:?d cmd:?x - Arg named 'dir' is a directory; arg named 'temp' is optional and a directory; arg named 'cmd' is an optional executable

By default, any arg with the f,d,x,e flag is assumed to be an input and doesn't need the 'i' flag.


=cut

sub _process_nameargs 
{
	my $this = shift ;

	my $nameargs = $this->nameargs() || "" ;
	my $arginfo_href = $this->_arg_info() ;

	print "_process_nameargs($nameargs)\n" if $this->debug ;
	
	my @namespecs = split /[\s,]+/, $nameargs ;
	
	my $ix=0 ;
	foreach my $spec (@namespecs)
	{
		# get name
		my ($name, $flags) = ($spec, '');
		if ($spec =~ /\s*([^:]+):([^:]+)\s*/)
		{
			($name, $flags) = ($1, $2);
		}
		$name ||= $ix ;

		print "  name: $name\n" if $this->debug ;
		
		# get flags
		#  ? arg is optional
		#  f file
		#  d dir
		#  x executable
		#  e exists
		#  i input
		#  o output
		#  - dummy flag (see below)
		my $flags_href = {
			'optional'	=> 0,
			'file'		=> 0,
			'dir'		=> 0,
			'input'		=> 1,
			'output'	=> 0,
			'exec'		=> 0,
			'exists'	=> 0, 
		} ;
		$flags_href->{'optional'} = 1 if ($flags =~ /\?/) ;
		if ($flags =~ /f/)
		{
			$flags_href->{'file'} = 1 ;
			$flags_href->{'dir'} = 0 ;
		}
		if ($flags =~ /d/)
		{
			$flags_href->{'file'} = 0 ;
			$flags_href->{'dir'} = 1 ;
		}
		if ($flags =~ /i/)
		{
			$flags_href->{'input'} = 1 ;
			$flags_href->{'output'} = 0 ;
		}
		if ($flags =~ /o/)
		{
			$flags_href->{'input'} = 0 ;
			$flags_href->{'output'} = 1 ;
		}
		if ($flags =~ /x/)
		{
			$flags_href->{'file'} = 1 ;
			$flags_href->{'dir'} = 0 ;
			$flags_href->{'exec'} = 1 ;
		}
		if ($flags =~ /e/)
		{
			$flags_href->{'exists'} = 1 ;
		}

		if ($flags_href->{'input'})
		{
			# Ensure existence check is performed for inputs
			$flags_href->{'exists'} = 1 ;
		}

		
		# set up
		$arginfo_href->{$name} = {
			'name' => $name,
			'index' => $ix,
			'flags' => $flags_href,
		} ;
			
		++$ix ;
	}

}

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>_check_synopsis()>

Check to ensure synopsis is set. If not, set based on application name and any 'nameargs'
settings

=cut

sub _check_synopsis 
{
	my $this = shift ;

	my $synopsis = $this->synopsis() ;
	if (!$synopsis)
	{
		my %opts = $this->options() ;
		
		# start with basics
		my $app = $this->name() ;
		$synopsis = "$app [options] " ;
		
		# If nameargs set, use them
		my $arginfo_href = $this->_arg_info() ;
		foreach my $name (sort {$arginfo_href->{$a}{'index'} <=> $arginfo_href->{$b}{'index'}} keys %$arginfo_href)
		{
	$this->prt_data("item $name=",$arginfo_href->{$name}) if $this->debug()>=2 ;
	
			my $flags_href = $arginfo_href->{$name}{'flags'} ;

			my $type = "" ;
			if ($flags_href->{'file'})
			{
				$type = " file" ;
			}
			if ($flags_href->{'dir'})
			{
				$type = " directory" ;
			}

			my $direction = "input" ;
			if ($flags_href->{'output'})
			{
				$direction = "output " ;
			}
				
			if ($flags_href->{'optional'})
			{
				$synopsis .= 'I<[' ;
			}
			else
			{
				$synopsis .= 'B<' ;
			}
			$synopsis .= "<$name ($direction$type)>" ;
			$synopsis .= ']' if $flags_href->{'optional'} ;
			$synopsis .= '> ' ;
		}		
		
		# set our best guess
		$this->synopsis($synopsis) ;
	}	
}

#----------------------------------------------------------------------------

=item C<App::Framework::Base-E<gt>_check_args()>

Check arguments based on 'nameargs' settings

=cut

sub _check_args 
{
	my $this = shift ;

#$this->debug(2);

	my $args_aref = $this->arglist() ;
	my $arginfo_href = $this->_arg_info() ;
	my $arghash = $this->arghash() ;

	foreach my $name (sort {$arginfo_href->{$a}{'index'} <=> $arginfo_href->{$b}{'index'}} keys %$arginfo_href)
	{
$this->prt_data("item $name=",$arginfo_href->{$name}) if $this->debug()>=2 ;

		my $flags_href = $arginfo_href->{$name}{'flags'} ;

		# arg value
		my $idx = $arginfo_href->{$name}{'index'} ;
		my $value = $idx < scalar(@$args_aref) ? $args_aref->[$idx] : undef ;

		## Build arghash
		$arghash->{$name} = $value ;

		# skip if optional
		next if $flags_href->{'optional'} ;

		my $type = "" ;
		if ($flags_href->{'file'})
		{
			$type = "file " ;
		}
		if ($flags_href->{'dir'})
		{
			$type = "directory " ;
		}

print " + checking value=$value, type=$type ..\n" if $this->debug()>=2 ;
		
		# First check that an arg has been specified
		if ($arginfo_href->{$name}{'index'} >= scalar(@$args_aref))
		{
			print "Error: Must specify input $type\"$name\"\n" ;

$this->prt_data("flags=",$flags_href) if $this->debug()>=2 ;

			$this->usage() ;
			$this->exit(1) ;
		}
		
		# check for existence
		if ($flags_href->{'exists'})
		{
print " + Check $value for existence\n" if $this->debug()>=2 ;
			
			# File check
			if ($flags_href->{'file'} && (! -f $value) )
			{
				print "Error: must specify a valid input filename for \"$name\"\n" ;
				$this->usage() ;
				$this->exit(1) ;
			}
			if ($flags_href->{'dir'} && (! -d $value) )
			{
				print "Error: must specify a valid input directory for \"$name\"\n" ;
				$this->usage() ;
				$this->exit(1) ;
			}
		}
		
	}
# TODO: Replace the above with some better error handling

# TODO: Could create required file based on a __DATA__ name=filename template

}

# ============================================================================================
# PRIVATE FUNCTIONS
# ============================================================================================

#----------------------------------------------------------------------------

=item C<App::Framework::Base::dumpvar(package)>

Dump out all of the symbols in package I<package>

=cut

sub dumpvar 
{
no strict "vars" ;
no strict "refs" ;

    my ($packageName) = @_;
    local (*alias);             # a local typeglob
    # We want to get access to the stash corresponding to the package
    # name
    *stash = *{"${packageName}::"};  # Now %stash is the symbol table
    $, = " ";                        # Output separator for print
    # Iterate through the symbol table, which contains glob values
    # indexed by symbol names.
    while (($varName, $globValue) = each %stash) {
        print "$varName ============================= \n";
        *alias = $globValue;
        if (defined ($alias)) {
            print "\t \$$varName $alias \n";
        } 
        if (defined (@alias)) {
            print "\t \@$varName @alias \n";
        } 
        if (defined (%alias)) {
            print "\t \%$varName ",%alias," \n";
        }
        if (defined (&alias)) {
            print "\t \&$varName \n";
        } 
     }
}

##============================================================================================
## BEGIN 
##============================================================================================
#
## set up @INC for subsequent 'use' modules
#BEGIN
#{
#	## Set program info
#	App::Framework::Base->set_paths($ARGV[0]) ;
#}


# ============================================================================================
# END OF PACKAGE
1;

__END__


