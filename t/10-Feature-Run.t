#!/usr/bin/perl
#
use strict ;
use Test::More ;

use App::Framework ':Script +Run' ;

# VERSION
our $VERSION = '1.000' ;

my @data = (
	'Some output',
	'Some more output',
	'',
	'RESULTS: 10 / 10 passed!',
) ;

# 2 lots of tests with data, 2 test per
# 2 lots of tests with single line
# 2 object tests
plan tests => scalar(@data) * 2 * 2 + 2 + 2 ;

	my $expected ;
	my $delay ;

	App::Framework->new()->go() ;

#sub diag
#{
#	print "$_[0]\n" ;
#}	
#sub fail
#{
#	print "FAIL: $_[0]\n" ;
#}	
#sub pass
#{
#	print "PASS: $_[0]\n" ;
#}	
#sub like
#{
#	print "LIKE: $_[0]\n" ;
#}	
#sub ok
#{
#	my ($test, $comment) ;
#	$comment ||= "" ;
#	
#	print "OK: ".$test ? "Passed":"FAILED"."  $comment\n" ;
#}	
#

#=================================================================================
# SUBROUTINES EXECUTED BY APP
#=================================================================================

#----------------------------------------------------------------------
# Main execution
#
sub app
{
	my ($app) = @_ ;


	my $run1 = $app->feature("run") ;
	my $class1 = ref($run1) ;
	
	is($class1, 'App::Framework::Feature::Run', 'Run feature class check') ;
	
	my $run = $app->run ;
	my $class = ref($run) ;
	is($run, $run1, 'Run object check') ;
		
	$expected = "Hello world" ;
	$delay =0 ;
	$run->run_cmd("perl t/test/runtest.pl", 
		'progress'	=> \&progress,
	) ;
	
	$expected = "Hello world" ;
	$delay =0 ;
	$app->run(
		'cmd' 		=> "perl t/test/runtest.pl", 
		'progress'	=> \&progress,
	) ;
	
	my $sleep = 1 ;
	$expected = \@data ;
	$delay = $sleep ;
	$run->run_cmd("perl t/test/runtest.pl", 
		'progress'	=> \&progress,
		'args'		=> "ping $sleep",
		'timeout'	=> $sleep*5,
	) ;

	$sleep = 5 ;
	$expected = \@data ;
	$delay = $sleep ;
	$run->run_cmd("perl t/test/runtest.pl", 
		'progress'	=> \&progress,
		'args'		=> "ping $sleep",
		'timeout'	=> $sleep*5,
	) ;
	
}

#=================================================================================
# SUBROUTINES
#=================================================================================

#---------------------------------------------------------------------------------
sub progress
{
	my ($line, $linenum, $state_href) = @_ ;
	print "progress: $line\n" ;
	
	if (ref($expected) eq 'ARRAY')
	{
		is($line, $expected->[$linenum-1], "Progress line compare: $line") ;
		if ($linenum==1)
		{
			ok(1) ; #dummy
			$state_href->{then} = time ;
		}
		else
		{
			my $now = time ;
			my $dly = $now - $state_href->{then} ; 
			my $tol = $delay / 2 ;
			$tol ||= 1 ;
			ok( ($dly > $delay-$tol) && ($dly < $delay+$tol), "Output timing check") ; 
			$state_href->{then} = $now ;
		}
	}
	else
	{
		is($line, $expected, "Progress line compare: $line") ;
	}
}


#=================================================================================
# SETUP
#=================================================================================
__DATA__

[SUMMARY]

Tests run feature


