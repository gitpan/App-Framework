package App::Framework::Base::Object::DumpObj ;

=head1 NAME

App::Framework::Base::Object::DumpObj - Dump out an objects contents

=head1 SYNOPSIS

use App::Framework::Base::Object::DumpObj ;



=head1 DESCRIPTION

Given a data object (scalar, hash, array etc) prints out that objects contents


=head1 REQUIRES


=head1 DIAGNOSTICS

Setting the debug flag to level 1 prints out (to STDOUT) some debug messages, setting it to level 2 prints out more verbose messages.

=head1 AUTHOR

Steve Price C<< <sdprice at cpan.org> >>

=head1 BUGS

None that I know of!

=head1 INTERFACE

=over 4

=cut

use strict ;
use Carp ;
use Cwd ;


our $VERSION = "2.001" ;

require Exporter ;
our @ISA = qw(Exporter);
our @EXPORT =qw(
);

our @EXPORT_OK	=qw(
	prt_data
	prtstr_data

	debug 
	verbose

	$DEBUG 
	$VERBOSE
	$PRINT_OBJECTS
);


#============================================================================================
# USES
#============================================================================================


#============================================================================================
# GLOBALS
#============================================================================================

our $DEBUG = 0 ;
our $VERBOSE = 0 ;
our $PRINT_OBJECTS = 0 ;
our $QUOTE_VALS = 0 ;

my $level ;
my %already_seen ;
my $prt_str ;


#============================================================================================
# EXPORTED 
#============================================================================================

#---------------------------------------------------------------------------------------------------

=item C<App::Framework::Base::Object::DumpObj::debug($level)>

Set debug print options to B<$level>. 

 0 = No debug
 1 = standard debug information
 2 = verbose debug information

=cut

sub debug
{
	my ($flag) = @_ ;

	my $old = $DEBUG ;

	if (defined($flag)) 
	{
		# set this module debug flag & sub-modules
		$DEBUG = $flag ; 
	}
	return $old ;
}

#---------------------------------------------------------------------------------------------------

=item C<App::Framework::Base::Object::DumpObj::verbose($level)>

Set vebose print options to B<$level>. 

 0 = Non verbose
 1 = verbose print

=cut

sub verbose
{
	my ($flag) = @_ ;

	my $old = $VERBOSE ;

	if (defined($flag)) 
	{
		# set this module verbose flag & sub-modules
		$VERBOSE = $flag ; 
	}
	return $old ;
}


#---------------------------------------------------------------------------------------------------

=item C<App::Framework::Base::Object::DumpObj::print_objects_flag($flag)>

Set option for printing out objects to B<$flag>. 

 0 = Do not print contents of object [DEFAULT]
 1 = print contents of object

=cut

sub print_objects_flag
{
	my ($flag) = @_ ;

	my $old = $PRINT_OBJECTS ;

	if (defined($flag)) 
	{
		# set this module debug flag & sub-modules
		$PRINT_OBJECTS = $flag ; 
	}
	return $old ;
}


#---------------------------------------------------------------------------------------------------

=item C<App::Framework::Base::Object::DumpObj::quote_vals_flag($flag)>

Set option quoting the values to B<$flag>. 

 0 = Do not quote values [DEFAULT]
 1 = Print values inside quotes
 
This is useful for re-using the output directly to define an array/hash

=cut

sub quote_vals_flag
{
	my ($flag) = @_ ;

	my $old = $QUOTE_VALS ;

	if (defined($flag)) 
	{
		# set this module debug flag & sub-modules
		$QUOTE_VALS = $flag ; 
	}
	return $old ;
}



#---------------------------------------------------------------------

=item C<App::Framework::Base::Object::DumpObj::prtstr_data(@list)>

Create a multiline string of all items in the list. Handles scalars, hashes (as an array),
arrays, ref to scalar, ref to hash, ref to array, object.

=cut

sub prtstr_data
{
	my (@data_list) = @_ ;

	$level = -1 ;
	%already_seen = () ;
	$prt_str = '' ;

	foreach my $var (@_) 
	{
	   if (ref ($var)) 
	   {
	       _print_ref($var);
	   } 
	   else 
	   {
	       _print_scalar($var);
	   }
	}

	return $prt_str ;
}

#---------------------------------------------------------------------

=item C<App::Framework::Base::Object::DumpObj::prt_data(@list)>

Print out each item in the list. Handles scalars, hashes (as an array),
arrays, ref to scalar, ref to hash, ref to array, object.

=cut

sub prt_data
{
	my (@data_list) = @_ ;
	
	prtstr_data(@data_list) ;
	print $prt_str ;
	
}



# ============================================================================================
# UNEXPORTED BY DEFAULT
# ============================================================================================

#---------------------------------------------------------------------------------------------------
sub _print_scalar 
{
    ++$level;
    _print_indented ($_[0]);
    --$level;
}

#---------------------------------------------------------------------------------------------------
sub _print_ref 
{
    my $r = $_[0];

    if (exists ($already_seen{$r})) 
	 {
        _print_indented ("# $r (Seen earlier)");
        return;
    } 
	 else 
	 {
        $already_seen{$r}=1;
    }

    my $ref_type = ref($r);

    if ($ref_type eq "ARRAY") 
	 {
        _print_array($r);
    } 
	 elsif ($ref_type eq "SCALAR") 
	 {
        print "# Ref -> $r";
        _print_scalar($$r);
    } 
	 elsif ($ref_type eq "HASH") 
	 {
        _print_hash($r);
    } 
	 elsif ($ref_type eq "REF") 
	 {
        ++$level;
        _print_indented("# Ref -> ($r)");
        _print_ref($$r);
        --$level;
    } 
	 else 
	 {
       _print_indented ("# OBJECT $ref_type");

		# If required (and we can) print out the object
		if ($PRINT_OBJECTS) 
		{
			my $obj_ref_str = "$r" ;
			if ($obj_ref_str =~ /ARRAY/) 
			{
			   _print_array($r);
			} 
			elsif ($obj_ref_str =~ m/HASH/) 
			{
			   _print_hash($r);
			} 
		}
    }
}

#---------------------------------------------------------------------------------------------------
sub _print_array 
{
    my ($r_array) = @_;

    ++$level;
    _print_indented ("[ # $r_array");
    foreach my $var (@$r_array) 
	 {
        if (ref ($var)) 
		 {
            _print_ref($var);
        } 
		 else 
		 {
            _print_scalar($var);
        }
    }
    _print_indented ("],");
    --$level;
}

#---------------------------------------------------------------------------------------------------
sub _print_hash 
{
    my($r_hash) = @_;

    my($key, $val);
    ++$level; 

    _print_indented ("{ # $r_hash");

#    while (($key, $val) = each %$r_hash) 
	 foreach my $key (sort keys %$r_hash)
	 {
#print "<< key <$key> r_hash <$r_hash> >>\n" ;
	 	my $val = $r_hash->{$key} ;
	 	 if (defined($val)) 
		 {
	        $val = ($val ? $val : '0');
		 }
		 else 
		 {
	        $val = 'undef' ;
		 }

        ++$level;

        if (ref ($val)) 
		 {
            _print_indented ("$key => ");
            _print_ref($val);
        } 
		 else 
		 {
            _print_indented ("$key => $val,");
        }
        --$level;
    }
    _print_indented ("},");
    --$level;
}

#---------------------------------------------------------------------------------------------------
sub _print_indented 
{
    my $spaces = "  " x $level;
    $prt_str .= "${spaces}" ;
	 _print_val($_[0]) ;
    $prt_str .= "\n" ;
}


#---------------------------------------------------------------------------------------------------
sub _print_val 
{
	if (defined($_[0])) 
	{
		$prt_str .= "$_[0]" ;

		# Print positive numerical value in hex too
		if ($_[0] =~ m/(^|\s+)(\d+)$/) 
		{
		   $prt_str .= sprintf "  # [0x%0x]", $2 if ($2 > 0) ;
		}
	}
	else 
	{
		$prt_str .= "undef" ;
	}

}



# ============================================================================================
# END OF PACKAGE
1;

__END__


