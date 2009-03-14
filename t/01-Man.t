#!/usr/bin/perl
#
use strict ;
use Test::More ;

use App::Framework ;

# VERSION
our $VERSION = '1.234' ;

my $DEBUG=0;
my $VERBOSE=0;

	my $stdout="" ;
	my $stderr="" ;

	diag( "Testing usage" );
	
	my @sections = qw/NAME SYNOPSIS OPTIONS DESCRIPTION/ ;
	my @man = (
		'Must specify input file "source"',
		'-help|h               Print help',
		'-man                  Full documentation',
		'-name|n <arg>             Test name',
		'-nomacro              Do not create test macro calls',
		'-int <integer>        An integer',
		'-float <float>        An float',
		'-array <string>       An array           \(option may be specified multiple times\)',
		'-hash <key=value>     A hash             \(option may be specified multiple times\)',
	) ;
	my @mandev = (
		'-pod                  Output full pod',
		'-dbg-data             Debug option: Show __DATA__',
		'-dbg-data-array       Debug option: Show all __DATA__ items',
		'-int=i                An integer',
		'-float=f              An float',
		'-array=s@             An array',
		'-hash=s%              A hash',
	) ;

	plan tests => 1 + scalar(@sections) + scalar(@man) + scalar(@mandev) ;
	
	## Standard error catch with usage
	my $app = App::Framework->new('exit_type'=>'die') ;
	
	# Expect output (stdout):
	#
	#Error: Must specify input file "source"
	#Usage:
	#    01-Man [options] <source (input file)>
	#
	#    Options:
	#
	#           -debug=s              Set debug level    
	#           -h|help               Print help 
	#           -man                  Full documentation 
	#           -log|L=s              Log file   
	#           -v|verbose            Verbose output     
	#           -dryrun|norun         Dry run    
	#           -n|name=s             Test name  
	#           -nomacro              Do not create test macro calls
	#           -int <integer>        An integer
	#           -float <float>        An float
	#           -array <string>       An array           (option may be specified multiple times)
	#           -hash <key=value>     A hash             (option may be specified multiple times)	
	#
	eval{
		local *STDOUT ;
		local *STDERR ;

		open(STDOUT, '>', \$stdout)  or die "Can't open STDOUT: $!" ;
		open(STDERR, '>', \$stderr) or die "Can't open STDERR: $!";
	
#		App::Framework->new('exit_type'=>'die')->go() ;
		$app->go() ;
	} ;

	foreach my $test (@man)
	{
		like  ($stdout, qr/$test/im);
	}



	## Manual pages
	
	#	NAME
	#	    01-Man (v1.000) - Tests manual page creation
	#	
	#	SYNOPSIS
	#	    01-Man [options] <source (input file)>
	#	
	#	    Options:
	#	
	#	           -debug=s              Set debug level    
	#	           -h|help               Print help 
	#	           -man                  Full documentation 
	#	           -pod                  Output full pod    
	#	           -debug-show-data      Debug option: Show __DATA__        
	#	           -debug-show-data-array Debug option: Show all __DATA__ items     
	#	           -log|L=s              Log file   
	#	           -v|verbose            Verbose output     
	#	           -dryrun|norun         Dry run    
	#	           -n|name=s             Test name  
	#	           -nomacro              Do not create test macro calls
	#	
	#	OPTIONS
	#	    -debug=s
	#	            Set the debug level value
	#	
	#	    -h|help Show brief help message then exit
	#	
	#	    -man    Show full man page then exit
	#	
	#	    -pod    Show full man page as pod then exit
	#	
	#	    -debug-show-data
	#	            Show __DATA__ definition in script then exit
	#	
	#	    -debug-show-data-array
	#	            Show all processed __DATA__ items then exit
	#	
	#	    -log|L=s
	#	            Specify a log file
	#	
	#	    -v|verbose
	#	            Make script output more verbose
	#	
	#	    -dryrun|norun
	#	            Do not execute anything that would alter the file system, just
	#	            show the commands that would have executed
	#	
	#	    -n|name=s
	#	            Specify a test name. This determines the output filenames (for
	#	            the test script .ts and menu file .db).
	#	
	#	            Default action is to use the control file name (without file
	#	            extension).
	#	
	#	    -nomacro
	#	            Normally the script automatically inserts a call to 'test_start'
	#	            at the beginning of the test, and 'test_passed' at the end of
	#	            the test. In both cases, the macros are called with the quoted
	#	            string that is the full 'path' of the test name.
	#	
	#	            The test path being the menu names, separated by '::' down to
	#	            the actual test name
	#	
	#	DESCRIPTION
	#	    01-Man reads the control file to pull together fragments of test script.
	#	    Creates a single test script file and a test menu.
	#	
	$stdout="" ;
	$stderr="" ;
	
	eval{
		local *STDOUT ;
		local *STDERR ;

		open(STDOUT, '>', \$stdout)  or die "Can't open STDOUT: $!" ;
		open(STDERR, '>', \$stderr) or die "Can't open STDERR: $!";
	
		push @ARGV, '-man-dev' ;
#		App::Framework->new('exit_type'=>'die')->go() ;
		$app->go() ;
		pop @ARGV ;
	} ;

	#           -pod                  Output full pod
	#           -dbg-data             Debug option: Show __DATA__
	#           -dbg-data-array       Debug option: Show all __DATA__ items
	#           -log|L=s              Override the log   [Default: tmp.log]
	#           -v|verbose            Verbose output
	#           -dryrun|norun         Dry run
	#           -database=s           Database name      [Default: test]
	#           -int=i                An integer
	#           -float=f              An float
	#           -array=s@             An array
	#           -hash=s%              A hash
	#
	foreach my $test (@mandev)
	{
		like  ($stdout, qr/$test/im);
	}
	

	# split into sections then check the sections
	my %man = split_man($stdout) ;
	
	foreach my $section (@sections)
	{
		ok(exists($man{$section})) ;
	}
	
	if ($man{'NAME'} =~ m/\(v$VERSION\)/)
	{
		pass("Version check") ;
	}
	else
	{
		fail("Version check - got: $man{'NAME'} expected: $VERSION") ;
	}


#=================================================================================
# SUBROUTINES EXECUTED BY APP
#=================================================================================

#----------------------------------------------------------------------
# Main execution
#
sub run
{
	my ($app) = @_ ;
	
}

#=================================================================================
# SUBROUTINES
#=================================================================================


#----------------------------------------------------------------------
sub split_man
{
	my ($man) = @_ ;
	
	my %man ;
	
	my $section ;
	foreach my $line (split "\n", $man)
	{
		if ($line =~ m/^(\S+)/)
		{
			$section = $1 ;
			$man{$section} ||= '' ;
		}
		else
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			next unless $line ;
			
			$man{$section} .= "$line\n" ;
		}
	}
	return %man ;
}

#=================================================================================
# SETUP
#=================================================================================
__DATA__

[SUMMARY]

Tests manual page creation

[NAMEARGS]

source:f

[OPTIONS]

-n|'name'=s		Test name

Specify a test name. This determines the output filenames (for the test script .ts and menu file .db).

Default action is to use the control file name (without file extension).

-nomacro	Do not create test macro calls

Normally the script automatically inserts a call to 'test_start' at the beginning of the test, and 'test_passed' at the end
of the test. In both cases, the macros are called with the quoted string that is the full 'path' of the test name. 

The test path being the menu names, separated by '::' down to the actual test name

-int=i		An integer

Example of integer option

-float=f	An float

Example of float option

-array=s@	An array

Example of an array option

-hash=s%	A hash

Example of a hash option


[DESCRIPTION]

B<$name> reads the control file to pull together fragments of test script. Creates a single test script file and a test menu.

