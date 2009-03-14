#!/usr/bin/perl
#
use strict ;

use App::Framework qw/Daemon/;

# VERSION
our $VERSION = '1.000' ;


	# Create application and run it
	App::Framework->new(
		'user' => 'sdprice1',
		'group' => 'users',
	)->go() ;

#=================================================================================
# SUBROUTINES EXECUTED BY APP
#=================================================================================

#----------------------------------------------------------------------
# Main execution
#
sub run
{
	my ($app) = @_ ;
	
	my %opts = $app->options ;
	my $log = $opts{'log'} || '/tmp/tmp.log' ;

#$REAL_USER_ID
#$UID
#$<

#$EFFECTIVE_USER_ID
#$EUID
#$>

#$REAL_GROUP_ID
#$GID
#$(

#$EFFECTIVE_GROUP_ID
#$EGID
#$)

print "Real uid=$< gid=$(   Effective: uid=$> gid=$)\n\n" ;
	
	while(1)
	{
	open my $fh, ">>$log" or die "Unable to open log file $log : $!" ;
	print $fh "Hello world\n" ;
	close $fh;

	sleep(5) ;
	}
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

[OPTIONS]

-database=s	Database name [default=test]

Specify the database name to use

[DESCRIPTION]

B<$name> expects a source directory and destination directory to be specified. If not, then
an error message is created and the application aborted.

