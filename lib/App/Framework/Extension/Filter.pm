package App::Framework::Extension::Filter ;

=head1 NAME

App::Framework::Extension::Filter - Script filter application object

=head1 SYNOPSIS

use App::Framework::Extension::Filter ;


=head1 DESCRIPTION

Application that filters either a file or a directory to produce some other output


* app_start - allows hash setup
* app_end - allows file creation/tweak
* app
** return output line?
** HASH state auto- updated with:
*** all output lines (so far)
*** regexp match vars (under 'vars' ?)
** app sets HASH 'output' to tell filter what to output (allows multi-line?)
* options
** inplace - buffers up lines then overwrites (input) file
** dir - output to dir
** input file wildcards
** recurse - does recursive file find (ignore .cvs .svn)
** output - can spec filename template ($name.ext)

* Filtering feature
** All extra loading of filter submodules
** Feature options: +Filter(perl c) - specifies extra Filter::Perl, Filter::C modules
* Filter spec:

	(
		('<spec>', <flags>, <code>),
		('<spec>', <flags>, <code>),
		('<spec>', <flags>, <code>),
	)

Each entry perfomed on the line, move on to next entry if no match OR match and (flags & FILTER_CONTINUE) [default]
Calls <code> on match AND (flags & FILTER_CALL); calls app if no <code> specified
Flag bitmasks:
	FILTER_CONTINUE		- allows next entry to be processed if matches; normally stops
	FILTER_CALL			- call code on match
	
<spec> is of the form:

	[<cond>:]/<regexp>/[:<setvars>]

<cond> evaluatable condition that must be met before running the regexp. Variables can be used by name 
(names are converted to $state->{'vars'}{name})

<stevars> colon separated list of variable assignments evaluated on match. Variables used by name (as <cond>). Regexp matches
accessed by $n or \n


=cut

use strict ;
use Carp ;

our $VERSION = "1.000" ;





#============================================================================================
# USES
#============================================================================================
use File::Path ;
use File::Basename ;
use File::Spec ;
use App::Framework::Core ;


#============================================================================================
# OBJECT HIERARCHY
#============================================================================================
use App::Framework::Extension ;
our @ISA ; 

#============================================================================================
# GLOBALS
#============================================================================================

# Set of script-related default options
my @OPTIONS = (
	['skip_empty',			'Skip blanks', 		'Don not process empty lines', ],
	['trim_space',			'Trim spaces',		'Remove spaces from start/end of line', ],
	['trim_comment',		'Trim comments',	'Remove comments from line'],
	['inplace',				'In-place filter',	'Read file, process, then overwrite input file'],
	['outfile',				'Write to file',	'Write filtered output to a file (rather than STDOUT)'],
	['outdir=s',			'Output directory',	'Write files into specified directory (rather than into same directory as input file)'],
	['outfmt=s',			'Output filename',	'Specify the output filename which may include variables', '$base.txt'],
	['comment=s@',			'Comment',			'Specify the comment start (end) string', '#'],
) ;

# Arguments spec
my @ARGS = (
	['file=s@',				'Input file(s)',	'Specify one (or more) input file to be processed']
) ;

our $class_debug=0;

#============================================================================================

=head2 FIELDS

None

=over 4

=cut

my %FIELDS = (
	## Object Data
	'skip_empty'	=> 0,
	'trim_space'	=> 0,
	'trim_comment'	=> 0,
	'comment'		=> ['#'],
	'buffer'		=> 0,
	'inplace'		=> 0,
	'outfmt'		=> '$base.txt',
	'outfile'		=> 0,
	'outdir'		=> undef,
	
	## internal
	'out_fh'		=> undef,
) ;

#============================================================================================

=back

=head2 CONSTRUCTOR METHODS

=over 4

=cut

#============================================================================================

=item C<new([%args])>

Create a new App::Framework::Extension::Filter.

The %args are specified as they would be in the B<set> method, for example:

	'mmap_handler' => $mmap_handler

The full list of possible arguments are :

	'fields'	=> Either ARRAY list of valid field names, or HASH of field names with default values 

=cut

sub new
{
	my ($obj, %args) = @_ ;

	my $class = ref($obj) || $obj ;

print "App::Framework::Extension::Filter->new() class=$class\n" if $class_debug ;

#	# Create object
#	my $this = $class->SUPER::new(
#		%args, 
#	) ;

	## create object dynamically
	my $this = App::Framework::Core->inherit($class, %args) ;


print "Filter - $class ISA=@ISA\n" if $class_debug ;

	## Set options
	$this->feature('Options')->append_options(\@OPTIONS) ;
	
	## Update option defaults
	$this->feature('Options')->defaults_from_obj($this, [keys %FIELDS]) ;

	## Set args
	$this->feature('Args')->append_args(\@ARGS) ;
	

#my $filter_sub = sub {$this->filter_run(@_);} ;
#print "Filter - extending fn = $filter_sub\n" ;

	## hi-jack the app function
	$this->extend_fn(
		'app_fn'		=> sub {$this->filter_run(@_);},
	) ;

$this->prt_data("new filter args=", \%args) if $class_debug ;
print "App::Framework::Extension::Filter->new() - END\n" if $class_debug ;
#$this->debug(2) ;

	return($this) ;
}



#============================================================================================

=back

=head2 CLASS METHODS

=over 4

=cut

#============================================================================================

#-----------------------------------------------------------------------------

=item B<init_class([%args])>

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

=item B<<filter_run($app, $opts_href, $args_href)>>

Filter the specified file(s) one at a time.
 
=cut


sub filter_run
{
	my $this = shift ;
	my ($app, $opts_href, $args_href) = @_ ;

	# Get command line arguments
#	my @args = $this->args() ;
	my @args = @{ $args_href->{'file'} || [] } ;

	$this->_dispatch_entry_features(@_) ;

#$this->debug(2) ;

print "#!# Hello, Ive started filter_run()...\n" if $this->debug ;

	## Update from options
	$this->feature('Options')->obj_vars($this, [keys %FIELDS]) ;

#$app->prt_data("Filter=", $this) if $this->debug ;

	## Set up filter state
	my $state_href = {} ;
	$state_href->{num_files} = scalar(@args) ;
	$state_href->{file_number} = 1 ;
	$state_href->{file_list} = \@args ;
	$state_href->{vars} = {} ;

	## do each file
	foreach my $file (@args)
	{

		$state_href->{outfile} = '' ;
		$state_href->{line_num} = 1 ;
		$state_href->{output_lines} = [] ;
		$state_href->{file} = $file ;

		$this->_dispatch_label_entry_features('file', $app, $opts_href, $state_href) ;
		
		$this->_start_output($state_href, $opts_href) ;
		
		## call application start
		$this->call_extend_fn('app_start_fn', $state_href) ;

		## Process file
		open my $fh, "<$file" or $this->throw_fatal("Unable to read file \"$file\": $!") ;
		my $line ;
		while(defined($line = <$fh>))
		{
			chomp $line ;
			$state_href->{line} = $line ;
			$state_href->{output} = undef ;

			$this->_dispatch_label_entry_features('line', $app, $opts_href, $state_href) ;

			## call application
			$this->call_extend_fn('app_fn', $state_href, $line) ;
			
			$this->_handle_output($state_href, $opts_href) ;

			$state_href->{line_num}++ ;

			$this->_dispatch_label_exit_features('line', $app, $opts_href, $state_href) ;
		}
		close $fh ;

		## call application end
		$this->call_extend_fn('app_end_fn', $state_href) ;

		$this->_end_output($state_href, $opts_href) ;

		$state_href->{file_number}++ ;

		$this->_dispatch_label_exit_features('file', $app, $opts_href, $state_href) ;
	}	

	$this->_dispatch_exit_features(@_) ;

}



# ============================================================================================
# PRIVATE METHODS
# ============================================================================================

#----------------------------------------------------------------------------

=item B<<_start_output($state_href, $opts_href)>>

Start of output file
 
=cut


sub _start_output
{
	my $this = shift ;
	my ($state_href, $opts_href) = @_ ;

	$this->set('out_fh' => undef) ;

print "_start_output\n" if $this->debug ;
	
	## do nothing if buffering or in-place editing
	return if ($this->buffer || $this->inplace) ;

print " + not buffering\n" if $this->debug ;

	# open output file (and set up output dir)
	$this->_open_output($state_href, $opts_href) ;
	
}

#----------------------------------------------------------------------------

=item B<<_handle_output($state_href, $opts_href)>>

Write out line (if required)
 
=cut


sub _handle_output
{
	my $this = shift ;
	my ($state_href, $opts_href) = @_ ;

	## buffer line(s)
	push @{$state_href->{output_lines}}, $state_href->{output} if defined($state_href->{output}) ;

	## do nothing if buffering or in-place editing
	return if ($this->buffer || $this->inplace) ;

	## ok to write
	$this->_wr_output($state_href, $opts_href, $state_href->{output}) ;
}


#----------------------------------------------------------------------------

=item B<<_end_output($state_href, $opts_href)>>

End of output file
 
=cut


sub _end_output
{
	my $this = shift ;
	my ($state_href, $opts_href) = @_ ;

	## if buffering or in-place editing, now need to write file
	if ($this->buffer || $this->inplace)
	{
		# open output file (and set up output dir)
		$this->_open_output($state_href, $opts_href) ;

		foreach my $line (@{$state_href->{output_lines}})
		{
			$this->_wr_output($state_href, $opts_href, $line) ;
		}	
	}
	
	# close output file
	$this->_close_output($state_href, $opts_href) ;
}



#----------------------------------------------------------------------------

=item B<<_open_output($state_href, $opts_href)>>

Open the file (or STDOUT) depending on settings
 
=cut


sub _open_output
{
	my $this = shift ;
	my ($state_href, $opts_href) = @_ ;

	$this->set('out_fh' => undef) ;

print "_open_output\n" if $this->debug ;
	
	my $outfile ;
	if ($this->outfile)
	{
		## See if writing to dir
		my $dir = $this->outdir ;
		if ($dir)
		{
			## create path
			mkpath([$dir], $this->debug, 0755) ;
		}
		$dir ||= '.' ;
		my $fmt = $this->outfmt ;
		
		my $file = $state_href->{file} ;
		my $number = $state_href->{file_number} ;
		my ($base, $path, $ext) = fileparse($file, '\..*') ;
		my $name = $base ;
		
		eval "\$outfile = \"$fmt\"" ;
print " + eval=$@\n" if $this->debug ;
print " + outfile=$outfile: dir=$dir fmt=$fmt file=$file num=$number base=$base path=$path\n" if $this->debug ;
		
		$outfile = File::Spec->catfile($dir, $outfile) ;
		$outfile = File::Spec->rel2abs($outfile) ;
	}
	
	if ($outfile)
	{
		my $file = $state_href->{file} ;
		$file = File::Spec->rel2abs($file) ;

		if ($outfile eq $file)
		{
			# In place editing
			$this->inplace(1) ;
		}
		else
		{
			## Open output
			open my $outfh, ">$outfile" or $this->throw_fatal("Unable to write \"$outfile\" : $!") ;
			$this->out_fh($outfh) ;
			
			$state_href->{outfile} = $outfile ;
		}
		
	}
	else
	{
		## STDOUT
		$this->out_fh(\*STDOUT) ;
	}
}

#----------------------------------------------------------------------------

=item B<<_close_output($state_href, $opts_href)>>

Close the file if open
 
=cut


sub _close_output
{
	my $this = shift ;
	my ($state_href, $opts_href) = @_ ;

	my $fh = $this->out_fh ;
	$this->set('out_fh' => undef) ;
	
	if ($this->outfile)
	{
		close $fh ;
	}
	else
	{
		## STDOUT - so ignore
	}
}

#----------------------------------------------------------------------------

=item B<<_wr_output($state_href, $opts_href, $line)>>

End of output file
 
=cut


sub _wr_output
{
	my $this = shift ;
	my ($state_href, $opts_href, $line) = @_ ;

	my $fh = $this->out_fh ;

print "_wr_output($line) fh=$fh\n" if $this->debug ;
	if ($fh)
	{
		print $fh "$line\n" ;
	}
}


# ============================================================================================
# END OF PACKAGE

=back

=head1 DIAGNOSTICS

Setting the debug flag to level 1 prints out (to STDOUT) some debug messages, setting it to level 2 prints out more verbose messages.

=head1 AUTHOR

Steve Price C<< <sdprice at cpan.org> >>

=head1 BUGS

None that I know of!

=cut

1;

__END__


