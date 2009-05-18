package App::Framework::Extension ;

=head1 NAME

App::Framework::Extension - Application Extension

=head1 SYNOPSIS

use App::Framework::Extension ;


=head1 DESCRIPTION

Provides the base object from which all Extensions must be derived. Is itself derived from L<App::Framework::Core> and overrides
whichever methods are necessary to modify the application behaviour.


=cut

use strict ;
use Carp ;

our $VERSION = "1.000" ;

#============================================================================================
# USES
#============================================================================================
use App::Framework::Core ;

#============================================================================================
# OBJECT HIERARCHY
#============================================================================================
#our @ISA = qw(App::Framework::Core) ; 
our @ISA ; 

#============================================================================================
# GLOBALS
#============================================================================================

=head2 FIELDS

The following fields should be defined either in the call to 'new()', as part of a 'set()' call, or called by their accessor method
(which is the same name as the field):


=over 4


=back

=cut


my %FIELDS = (
	'extension_heap'	=> {},	# Extension-specific heap
);

#============================================================================================

=head2 CONSTRUCTOR

=over 4

=cut

#============================================================================================

=item C<< new([%args]) >>

Create a new Extension.

The %args are specified as they would be in the B<set> method.

=cut

sub new
{
	my ($obj, %args) = @_ ;

	my $class = ref($obj) || $obj ;

#print "App::Framework::Extension->new() class=$class\n" ;

	## Inherit from specified list
	my $this = App::Framework::Core->inherit($class, %args) ;

print "Extension - $class ISA=@ISA\n" if $this->debug ;

	# Create object
#	my $this = $class->SUPER::new(%args) ;

#$this->debug(1) ;
#print "App::Framework::Extension->new() - END\n" ;
	
	return($this) ;
}



#============================================================================================

=back

=head2 CLASS METHODS

=over 4

=cut

#============================================================================================

#-----------------------------------------------------------------------------

=item C<< init_class([%args]) >>

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

=item B<<heap([$level])>>

Returns HEAP space for the calling module
 
=cut


sub heap
{
	my $this = shift ;
	my ($level) = @_ ;

	## Get calling package
	$level ||= 0 ;
	my $pkg = (caller($level))[0] ;

#print "##!!## heap($pkg)\n" ;
#$this->dump_callstack() ;	

	# Get total heap space
	my $heap = $this->extension_heap() ;

	# Return this package's area
	$heap->{$pkg} ||= {} ;
#$this->prt_data("#!# this=$this pkg=$pkg Heap [$heap->{$pkg}] Total heap [$heap]=", $heap) ;	

	return $heap->{$pkg} ;
}


# TODO: Specify fn(s) as method name strings that get called on this

#----------------------------------------------------------------------------

=item B<<extend_fn(%spec)>>

Hi-jack the specified application function. %spec is a HASH of:

	key = function name
	value = CODE ref to subroutine
 
=cut


sub extend_fn
{
	my $this = shift ;
	my (%spec) = @_ ;

#$this->debug(2);
#my $pkg = (caller(0))[0] ;
#$this->prt_data("#!# extend_fn() pkg=$pkg (this=$this)", \%spec) if $this->debug ;	
	
	my $heap = $this->heap(1) ;
#$this->prt_data("#!# heap [$heap]", $heap) if $this->debug ;	
	foreach my $fn (keys %spec)
	{
		# save original
		$heap->{'extend_fn'}{$fn} = $this->$fn ;
#print "#!# + pkg=$pkg Extend $fn - saved ($heap->{'extend_fn'}{$fn}), new $fn=($spec{$fn})\n" if $this->debug ;
		
		# update function
		$this->$fn($spec{$fn}) ;
		
	}
#$this->prt_data("#!# extend_fn() - END", "HEAP=", $heap) if $this->debug ;	

}

#----------------------------------------------------------------------------

=item B<<call_extend_fn($pkg, $fn, @args)>>

Calls the function with specified args. If not extended by the extension then just calls the
default function.

NOTE: Application function is always called with:

	fn($app, \%options, @args)
 
=cut


sub call_extend_fn
{
	my $this = shift ;
	my ($fn, @args) = @_ ;

	my $heap = $this->heap(1) ;
	my $call = $heap->{'extend_fn'}{$fn} ;
#$this->debug(2);
#my $pkg = (caller(0))[0] ;
#$this->prt_data("#!# pkg=$pkg call_extend_fn($fn) call=$call HEAP [$heap]=", $heap) if $this->debug ;	

	# get default if not extended
	$call ||= $this->$fn ;
#print "#!# + pkg=$pkg call=$call\n" if $this->debug ;	
	
	# do call if specified
	if ($call)
	{
		# get options
		my %options = $this->options() ;

#print "#!# + pkg=$pkg calling $fn call=$call\n" if $this->debug ;	
	
		# do call
		&$call($this, \%options, @args) ;
		
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


