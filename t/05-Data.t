#!/usr/bin/perl
#
use strict ;
use Test::More tests => 6;

use App::Framework ;

# VERSION
our $VERSION = '1.234' ;

my $DEBUG=0;
my $VERBOSE=0;

	my $stdout="" ;
	my $stderr="" ;

	diag( "Testing data" );

my $NAMED1 =<<'NAMED1';
=head2 Named Arguments

The [NAMEARGS] section is used to specify the expected command line arguments used with the application. These "named arguments" provide
a mechanism for the framework to determine if all required arguments have been specified (generating an error message if not), creates
the application documentation showing these required arguments, and allows for easier access to the arguments in the application itself.

Along with specifying the name of arguments, specification of
certain properties of those arguments is provided for. 

Argument properties allow you to:
 * specify if arg is optional
 * specify if arg is a file/dir
 * specify if arg is expected to exist (autocheck existence; autocreate dir if output?)
 * specify if arg is an executable (autosearch PATH so don't need to specify full path?)
 * ?flag arg as an input or output (for filters, simple in/out scripts)?
 * ?specify arg expected to be a link?
NAMED1

my $NAMED2 =<<'NAMED2' ;
=head2 Options

The [OPTIONS] section is used to specify extra command line options for the application. The specification is used
both to create the code necessary to gather the option information (and provide it to the application), but also to
create application documentation (with the -help, -man options).

Each option specification is a multiline definition of the form:

   -option[=s]	Option summary [default=optional default]
 
   Option description
 
The -option specification can contain multiple strings separated by '|' to provide aliases to the same option. The first specified
string will be used as the option name. Alternatively, you may surround the preferred option name with '' quotes:

  -n|'number'=s
  
The option names/values are stored in a hash retrieved as $app->options():

  my %opts = $app->options();
  
Each option specification can optional append '=s' to the name to specify that the option expects a value (otherwise the option is treated
as a boolean flag), and a default value may be specified enclosed in '[]'.
NAMED2

my $NAMED3 =<<'NAMED3' ;
=head2 @INC path

App::Framework automatically pushes some extra directories at the start of the Perl include library path. This allows you to 'use' application-specific
modules without having to install them globally on a system. The path of the executing Perl application is found by following any links until
an actually Perl file is found. The @INC array has the following added:

	* $progpath
	* $progpath/lib
	
i.e. The directory that the Perl file resides in, and a sub-directory 'lib' will be searched for application-specific modules.
NAMED3

my %NAMED = (
	'named1' => $NAMED1,
	'named2' => $NAMED2,
	'named3' => $NAMED3,
) ;
	
	App::Framework->new()->go() ;


#=================================================================================
# SUBROUTINES EXECUTED BY APP
#=================================================================================

#sub ok {}
#sub diag {}

#----------------------------------------------------------------------
# Main execution
#
sub run
{
	my ($app) = @_ ;
	
	test_str($app, 'named1') ;
	test_str($app, 'named2') ;
	test_str($app, 'named3') ;
	
	test_array($app, 'named1') ;
	test_array($app, 'named2') ;
	test_array($app, 'named3') ;
}




#=================================================================================
# SUBROUTINES
#=================================================================================

#----------------------------------------------------------------------
# Get data & check
#
sub test_str
{
	my ($app, $which) = @_ ;

	my $named = $app->data($which) ;
	my $expected = $NAMED{$which} ;
	chomp $expected ; 
	is($named, $expected, "check $which text") ;
}

#----------------------------------------------------------------------
# check array version
#
sub test_array
{
	my ($app, $which) = @_ ;

	my @NAMED = split "\n", $NAMED{$which} ;
	my @named = $app->data($which) ;
	
	is_deeply(\@named, \@NAMED, "check $which array") ;
}


#=================================================================================
# SETUP
#=================================================================================
__DATA__

[SUMMARY]

Tests named data handling

[DESCRIPTION]

B<$name> does some stuff.

__#================================================================================
__DATA__ named1
=head2 Named Arguments

The [NAMEARGS] section is used to specify the expected command line arguments used with the application. These "named arguments" provide
a mechanism for the framework to determine if all required arguments have been specified (generating an error message if not), creates
the application documentation showing these required arguments, and allows for easier access to the arguments in the application itself.

Along with specifying the name of arguments, specification of
certain properties of those arguments is provided for. 

Argument properties allow you to:
 * specify if arg is optional
 * specify if arg is a file/dir
 * specify if arg is expected to exist (autocheck existence; autocreate dir if output?)
 * specify if arg is an executable (autosearch PATH so don't need to specify full path?)
 * ?flag arg as an input or output (for filters, simple in/out scripts)?
 * ?specify arg expected to be a link?
__#================================================================================
__DATA__ named2
=head2 Options

The [OPTIONS] section is used to specify extra command line options for the application. The specification is used
both to create the code necessary to gather the option information (and provide it to the application), but also to
create application documentation (with the -help, -man options).

Each option specification is a multiline definition of the form:

   -option[=s]	Option summary [default=optional default]
 
   Option description
 
The -option specification can contain multiple strings separated by '|' to provide aliases to the same option. The first specified
string will be used as the option name. Alternatively, you may surround the preferred option name with '' quotes:

  -n|'number'=s
  
The option names/values are stored in a hash retrieved as $app->options():

  my %opts = $app->options();
  
Each option specification can optional append '=s' to the name to specify that the option expects a value (otherwise the option is treated
as a boolean flag), and a default value may be specified enclosed in '[]'.
__#================================================================================
__DATA__ named3
=head2 @INC path

App::Framework automatically pushes some extra directories at the start of the Perl include library path. This allows you to 'use' application-specific
modules without having to install them globally on a system. The path of the executing Perl application is found by following any links until
an actually Perl file is found. The @INC array has the following added:

	* $progpath
	* $progpath/lib
	
i.e. The directory that the Perl file resides in, and a sub-directory 'lib' will be searched for application-specific modules.
__#================================================================================