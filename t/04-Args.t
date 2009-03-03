#!/usr/bin/perl
#
use strict ;
use Test::More tests => 11;

use App::Framework ;

# VERSION
our $VERSION = '1.234' ;

my $DEBUG=0;
my $VERBOSE=0;

	my $stdout="" ;
	my $stderr="" ;

	diag( "Testing args" );
	
	#	src1:f
	#	src2:d
	#	src3:e
	#	out1:of
	#	out2:od
	my @args = (
		['src1',	't/args/file'],
		['src2',	't/args/dir'],
		['src3',	't/args/exists'],
		['out1',	't/args/outfile'],
		['out2',	't/args/outdir'],
	) ;	

	foreach my $arg_aref (@args)
	{
		push @ARGV, $arg_aref->[1] ;
	}
	App::Framework->new()->go() ;



#=================================================================================
# SUBROUTINES EXECUTED BY APP
#=================================================================================

#----------------------------------------------------------------------
# Main execution
#
sub run
{
	my ($app) = @_ ;
	
	# Check args
	my $arglist_aref = $app->arglist() ;
	my $arghash_href = $app->arghash() ;

#$app->prt_data("Args: list=", $arglist_aref, "hash=", $arghash_href) ;

	## Test for correct number of args
	ok (scalar(@$arglist_aref) == scalar(@args), "Number of args") ;

	## test each
	foreach my $arg_aref (@args)
	{
		my $arg = $arg_aref->[0] ;
		my $expected = $arg_aref->[1] ;
		ok(exists($arghash_href->{$arg}), "Arg $arg exists") ;
		ok($arghash_href->{$arg} eq $expected, "Arg $arg : got \"$arghash_href->{$arg}\" expected \"$expected\" ") ;
	}
}

#=================================================================================
# SUBROUTINES
#=================================================================================



#=================================================================================
# SETUP
#=================================================================================
__DATA__

[SUMMARY]

Tests named args handling

[NAMEARGS]

src1:f
src2:d
src3:e
out1:of
out2:od


[DESCRIPTION]

B<$name> does some stuff.

