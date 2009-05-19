package App::Framework::Feature::Mail ;

=head1 NAME

App::Framework::Feature::Mail - Send mail

=head1 SYNOPSIS

  use App::Framework '+Mail' ;


=head1 DESCRIPTION

Provides a simplified mail interface, and application error auto-mailing.

B<DOCUMENTATION TO BE COMPLETED>

B<BETA CODE ONLY - NOT TO BE USED IN PRODUCTION SCRIPTS>

=cut

use strict ;
use Carp ;

our $VERSION = "1.000" ;


#============================================================================================
# USES
#============================================================================================
use App::Framework::Feature ;

#============================================================================================
# OBJECT HIERARCHY
#============================================================================================
our @ISA = qw(App::Framework::Feature) ; 

#============================================================================================
# GLOBALS
#============================================================================================


=head2 FIELDS

The following fields should be defined either in the call to 'new()', as part of a 'set()' call, or called by their accessor method
(which is the same name as the field):


=over 4


=item B<from> - Mail sender (required)

Email sender

=item B<to> - Mail recipient(s) (required)

Email recipient. Where there are multiple recipients, they should be set as a comma seperated list of email addresses

=item B<error_to> - Error mail recipient(s)

Email recipient for errors. If set, program errors are sent to this email.

=item B<mail_level> - Error level for mails

Set the minium error level that trigger an email. Level can be: note, warning, error

=item B<subject> - Mail subject

Optional mail subject line

=item B<host> - Mail host 

Mailing host. If not specified uses 'localhost'


=back

=cut

my %FIELDS = (
	'from'			=> '',
	'to'			=> '',
	'error_to'		=> '',
	'error_level'	=> 'error',
	'subject'		=> '',
	'host'			=> 'localhost',
) ;

#============================================================================================

=head2 CONSTRUCTOR

=over 4

=cut

#============================================================================================


=item B< new([%args]) >

Create a new Mail.

The %args are specified as they would be in the B<set> method (see L</Fields>).

=cut

sub new
{
	my ($obj, %args) = @_ ;

	my $class = ref($obj) || $obj ;

	# Create object
	my $this = $class->SUPER::new(%args,
		'requires' 		=> [qw/Net::SMTP/],
		'registered'	=> [qw/catch_error_entry/],
	) ;
	
	
	return($this) ;
}



#============================================================================================

=back

=head2 CLASS METHODS

=over 4

=cut

#============================================================================================


#-----------------------------------------------------------------------------

=item B< init_class([%args]) >

Initialises the Mail object class variables.

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


#--------------------------------------------------------------------------------------------

=item B< send_mail($content [, %args]) >

Send some mail stored in $content. $content may either be a string (containing newlines), or an
ARRAY ref.

Optionally %args may be specified (to set 'subject' etc)

=cut

sub send_mail
{
	my $this = shift ;
	my ($content, %args) = @_ ;
	
	$this->set(%args) ;
	
	my $from = $this->from ;
	my $mail_to = $this->to ;
	my $subject = $this->subject ;
	my $host = $this->host ;
	
	$this->throw_fatal("Mail: not specified 'from' field") unless $from ;
	$this->throw_fatal("Mail: not specified 'to' field") unless $mail_to ;
	$this->throw_fatal("Mail: not specified 'host' field") unless $host ;

	my @content ;
	if (ref($content) eq 'ARRAY')
	{
		@content = @$content ;
	}
	elsif (!ref($content))
	{
		@content = split /\n/, $content ;
	}

	## For each recipient, need to send a separate mail
	my @to = split /,/, $mail_to ;
	foreach my $to (@to)
	{
		my $smtp = Net::SMTP->new($host); # connect to an SMTP server
		$this->throw_fatal("Mail: unable to connect to '$host'") unless $smtp ;
		
		$smtp->mail($from);     # use the sender's address here
		$smtp->to($to);	# recipient's address
		$smtp->data();      # Start the mail
		
		# Send the header.
		$smtp->datasend("To: $mail_to\n");
		$smtp->datasend("From: $from\n");
		$smtp->datasend("Subject: $subject\n") if $subject ;
		
		# Send the body.
		$smtp->datasend("$_\n") foreach (@content) ;
		
		$smtp->dataend();   # Finish sending the mail
		$smtp->quit;        # Close the SMTP connection
	}
}

#--------------------------------------------------------------------------------------------

=item B< catch_error_entry($error) >

Send some mail stored in $content. $content may either be a string (containing newlines), or an
ARRAY ref.

Optionally %args may be specified (to set 'subject' etc)

=cut

sub catch_error_entry
{
	my $this = shift ;
	my ($error) = @_ ;

	my $from = $this->from ;
	my $error_to = $this->error_to ;
	my $app = $this->app ;
	
	# skip if required fields not set
	return unless $from && $error_to && $app ;

	my $appname = $app->name ;
	my $level = $this->mail_level ;
	
	# If it's an error, mail it
	if ($this->is_error($error))
	{
		my ($msg, $exitcode) = $this->error_split($error) ;
		$this->send_mail(
			$msg,
			'subject'	=> "$appname fatal error",
		) ;
	}
	if ($this->is_warning($error) && (($level eq 'warning') || ($level eq 'note')))
	{
		my ($msg, $exitcode) = $this->error_split($error) ;
	}
	if ( $this->is_note($error) && ($level eq 'note') )
	{
		my ($msg, $exitcode) = $this->error_split($error) ;
	}

}

# ============================================================================================
# PRIVATE METHODS
# ============================================================================================


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


