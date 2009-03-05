#!/usr/bin/perl
#
use strict ;

use App::Framework ;

# VERSION
our $VERSION = '1.001' ;


	# Create application and run it
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
	
	# Get source/dest dirs
	my ($src_dir, $backup_dir) = @{$app->arglist()};
	
	
	# do something useful....
}


#=================================================================================
# LOCAL SUBROUTINES
#=================================================================================

#=================================================================================
# SETUP
#=================================================================================
__DATA__


[HISTORY]

28-May-08    SDP        New

[SUMMARY]

An example of using the application framework with named arguments

[NAMEARGS]

src_dir:id backup_dir:id

[OPTIONS]

-database=s	Database name [default=test]

Specify the database name to use

[DESCRIPTION]

B<$name> expects a source directory and destination directory to be specified. If not, then
an error message is created and the application aborted.

