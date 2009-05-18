#!/usr/bin/perl
#
use strict ;

use App::Framework '+Config' ;

# VERSION
our $VERSION = '1.000' ;


	# Create application and run it
	App::Framework->new(
		'feature_config' => {
			'options'	=> {
				'debug'		=> 2,
			},
			'config'	=> {
				'debug'		=> 2,
			},
		}
	)->go() ;

#=================================================================================
# SUBROUTINES EXECUTED BY APP
#=================================================================================

#----------------------------------------------------------------------
# Main execution
#
sub app
{
	my ($app, $opts_href, $args_aref) = @_ ;
	
	# do something useful....
	print "I'm in the app...\n" ;
	
	my @inst = $app->feature('Config')->get_array('instance') ;
	$app->prt_data("Inst",\@inst) ;
	
	
	$app->usage() ;
}


#=================================================================================
# LOCAL SUBROUTINES
#=================================================================================

#=================================================================================
# SETUP
#=================================================================================
__DATA__


[SUMMARY]

An example of using the application framework with config file


[OPTIONS]

-int=i		An integer

Example of integer option

-float=f	An float

Example of float option

-string=s	A string [default=hello world]

Example of string option

-array=s@	An array

Example of an array option

-hash=s%	A hash

Example of a hash option


[DESCRIPTION]

B<$name> test out config file use.

