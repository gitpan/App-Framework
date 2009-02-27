package App::Framework;

=head1 NAME

App::Framework - A framework for creating applications

=head1 SYNOPSIS

  use App::Framework ;
  use App::Framework qw/Script/ ;

  App::Framework->new()->go() ;
  
  sub run
  {
	my ($app) = @_ ;
	
	# options
	my %opts = $app->options() ;

	# aplication code here....  	
  }

=head1 DESCRIPTION

This class actually uses one of the framework sub-modules to provide it's "personality". By default that
will be Script, but others will be available later (or if anyone adds their own). The personality is loaded
into the framework at import time as part of the 'use':

  use App::Framework qw/Script/ ;

(As stated above, if no personality is specified then 'Script' will be assumed).

The framework is intended to do most of the common tasks required to set up an application, being driven 
predominantly by the applications "documentation" (see section L</DATA>).

=head2 COMMAND LINE OPTIONS

The basic framework provides (and handles) the following pre-defined options:

	debug			Set the debug level value
	h|"help"		Show brief help message then exit
	man				Show full man page then exit
	pod				Show full man page as pod then exit

Application-specific options are specified in the __DATA__ section under the heading [OPTIONS]. An example of which is:

	[OPTIONS]
	
	-d|'dir'=s	temp directory	[default=/tmp]
	
	Specify the directory in which to store the xml output files (created by dumping the rrd databases)
	
	-repair 	Enable rrd repair
	
	When this option is specified, causes the script to repair any faulty rrd files

Here two options -d (or -dir) and -repair are defined. In this case -d is used to specify a directory name and a default
has been declared so that, if the user does not specify the option, the default value will be used. In the application itself,
all options are accessed via the options HASH (accessed using $app->options())

=head2 APPLICATION FUNCTIONS

Once the object has been created it can then be run by calling the 'go()' method. go() calls in turn:

	* pre_run()		Gets & processes the options, then calls the pre_run_fn if set
	* run()			Handles any special options (-man etc), then calls the run_fn if set
	* post_run()	Calls post_run_fn if set
	* exit()		Called with exit value 0 if execution reaches this far

The pre_run_fn, run_fn, and post_run_fn fields of the object can either be set directly as part of the new() call,
or the prefered approach is to define pre_run, run, and post_run subroutines in the calling namespace. These subroutines
are detected by App::Framework::Base and automatically set on the object.

=head2 DATA

Similarly, the __DATA__ area of the calling namespace is the prefered area to use for object set up of common
fields (rather than as part of the new() call). Example __DATA__ contents:

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
	
 
This example sets the fields: history, summary, synopsis, options, and description. This information is also used to 
automatically create the application pod, man, and usage pages.

Similarly, the $VERSION variable in the calling namespace is detected and used to set the application version number.

In addition to specifying teh application settings, additional named __DATA__ sections can be created. These named sections are then accessed
via $app->data($name) to recover the text string (or an array of the text lines). Named data sections are specified as:

    __DATA__ name

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
 

=head2 Configuration

App::Framework loads some settings from L<App::Framework::Config>. This may be modified on a site basis as required 
(in a similar fashion to CPAN Config.pm). 


=head2 Loaded modules

App::Framework pre-loads the user namespace with some common modules. See L<App::Framework::Config> for the complete list. 

	
=head2 MySql support

The 'sql' field may be specified as either a HASH ref or an ARRAY ref (where each ARRAY entry is a HASH ref). The HASH ref must
contain sufficient information to create a L<App::Framework::Base::Sql> object. 

Calling to the sql() method with no parameter will return the first created L<App::Framework::Base::Sql> object. Calling the sql() method with a string will
return the L<App::Framework::Base::Sql> object created for the named database (i.e. sql objects are named by their database). The sql object can then be
used as defined in L<App::Framework::Base::Sql>

=head2 Further details

The actual functionality (and hence most of the methods) of the class is provided by L<App::Framework::Base> which should be referred to
for complete documentation.

The personalities are described in:

=over 4

=item * Script

L<App::Framework::Modules::Script>

=back

=cut

use strict ;
use Carp ;

our $VERSION = "0.02" ;


#============================================================================================
# OBJECT HIERARCHY
#============================================================================================
our @ISA ; 

#============================================================================================
# GLOBALS
#============================================================================================

# Keep track of import info
my %imports ;


#============================================================================================

=head2 CONSTRUCTOR

=over 4

=cut


#============================================================================================

# Set up module import
sub import 
{
    my $pkg     = shift;
    my $callpkg = caller(0);
    my $pattern = ( $callpkg eq 'main' ) ? '^:::' : "^$callpkg\$";
    
    
    my $verbose = 0;
    my $item;
    my $file;

    for $item (@_) 
    {
    	print " + item: $item\n" ;
    	$imports{$callpkg} = $item ;
    }
    
}

#----------------------------------------------------------------------------------------------

=item C<< new([%args]) >>

Create a new object.

The %args are specified as they would be in the B<set> method, for example:

	'adapter_num' => 0

The full list of possible arguments are as described in the L</FIELDS> section

=cut

sub new
{
	my ($obj, %args) = @_ ;

	my $class = ref($obj) || $obj ;
    my $callpkg = caller(0);
	
	# Get name of requested personality
	my $personality = ($imports{$callpkg} || 'Script' ) ;
	my $module =  "App::Framework::Modules::$personality" ; 
	eval "require $module;" ;
	croak "Sorry, App:Framework does not support personality \"$personality\"" if $@ ;

	## Create ourself as if we're an object of the required type	
	@ISA = ( $module ) ;

	# Create object
	my $this = $class->SUPER::new(
		%args, 
	) ;
	$this->set(
		'usage_fn' 	=> sub {$this->script_usage(@_);}, 
	) ;

	return($this) ;
}


=back

=head1 AUTHOR

Steve Price, C<< <sdprice at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-app-framework at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-Framework>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::Framework


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Framework>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-Framework>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-Framework>

=item * Search CPAN

L<http://search.cpan.org/dist/App-Framework/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Steve Price, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

# ============================================================================================
# END OF PACKAGE
1;

__END__


