package App::Framework::Base::Object ;

=head1 NAME

Object - Basic object

=head1 SYNOPSIS

use App::Framework::Base::Object ;


=head1 DESCRIPTION


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

our $VERSION = "1.007" ;
our $AUTOLOAD ;

#============================================================================================
# USES
#============================================================================================

use App::Framework::Base::Object::DumpObj ;

#============================================================================================
# GLOBALS
#============================================================================================
my $global_debug = 0 ;
my $global_verbose = 0 ;
my $strict_fields = 0 ;

my @SPECIAL_FIELDS = qw/
	global_debug
	global_verbose
	strict_fields
/ ;

my %COMMON_FIELDS = (
	'debug'			=> undef,		# pseudo field
	'verbose'		=> undef,		# pseudo field
	'debug_level'	=> 0,
	'verbose_level'	=> 0,
	'debug_pkg'		=> '',
	'verbose_pkg'	=> '',
) ;

# Constant
#my @REQ_LIST ;
my %FIELD_LIST ;


my %CLASS_INIT;
my %CLASS_INSTANCE ;

#============================================================================================
# CONSTRUCTOR 
#============================================================================================

=item C<new([%args])>

Create a new object.

The %args are specified as they would be in the B<set> method, for example:

	'mmap_handler' => $mmap_handler

Special arguments are:

	'fields'	=> Either ARRAY list of valid field names, or HASH of field names with default values 

Example:

	new(
		'fields' => {
			'cmd'		=> undef,
			'status'	=> 0,
			'results'	=> [],
			
		)
	)

All defined fields have an accessor method created.

=cut

sub new
{
	my ($obj, %args) = @_ ;

	my $class = $obj->class() ;

	print "== Object: Creating new $class object ========\n" if $global_debug ; 
	prt_data("ARGS=", \%args, "\n") if $global_debug>=2 ;

	# Initialise class variables
	$class->init_class(%args);

	# Create object
	my $this = {} ;
	bless ($this, $class) ;

	# Initialise object
	$this->init(%args) ;

#	# Check for required settings
#	foreach (@REQ_LIST)
#	{
#		do 
#		{ 
#			croak "ERROR: $class : Must specify setting for $_" ; 
#		} unless defined($this->{$_}) ;
#	}

	prt_data("== Created object=", $this, "================================================\n") if $global_debug ;
	
	return($this) ;
}

#-----------------------------------------------------------------------------

=item C<init([%args])>

Initialises the newly created object instance.


=cut

sub init
{
	my $this = shift ;
	my (%args) = @_ ;

	prt_data("init() ARGS=", \%args, "\n") if $global_debug>=3 ;

	my $class = $this->class() ;
    $this = $this->check_instance() ;
	
	# Defaults
	my %field_list = $this->field_list() ;

	# May have default value for some or all fields
	my %field_copy ;
	foreach my $fld (keys %field_list)
	{
		my $val = $field_list{$fld} ;
				
		# If value is an ARRAY ref or a HASH ref then we want a new copy of this per instance (otherwise
		# all instances will have a ref to the same HASH/ARRAY and one instance will change all instance's values!)
		if (ref($val) eq 'ARRAY')
		{
			$val = [@$val] ;
		}
		elsif (ref($val) eq 'HASH')
		{
			$val = { (%$val) } ;
		}
					
		$field_copy{$fld} = $val ;	
	}

	$this->set(%field_copy) ;

	## Handle special fields
	foreach my $special (@SPECIAL_FIELDS)
	{
		if (exists($args{$special}))
		{
			# remove from args list
			my $special_val = delete $args{$special} ;
			
			# call variable handler
			$this->$special($special_val) ;		
		}
	}

	## Set fields from parameters
	$this->set(%args) ;

	print "init() - done\n" if $global_debug>=3 ;

}

#-----------------------------------------------------------------------------

=item C<init_class([%args])>

Initialises the object class variables.


=cut

sub init_class
{
	my $this = shift ;
	my (%args) = @_ ;

	my $class = $this->class() ;

	prt_data("init_class() ARGS=", \%args, "\n") if $global_debug>=3 ;
#prt_data("init_class() ARGS (LIST)=", \@_, "\n") ;

	if (!$CLASS_INIT{$class})
	{
		# Field list
		$FIELD_LIST{$class} = {};
		my $fields = delete($args{'fields'}) ;

	prt_data(" + fields=$fields", $fields, "ARGS=", \%args, "\n") if $global_debug>=4 ;
#prt_data(" init_class($class) FIELDS=", $fields, "\n") ;

		if ($fields)
		{
print " + fields=$fields ref()=", ref($fields), "\n" if $global_debug>=4 ;

			my $class_fields_href = {} ;
			
			## Do the fields
			if (ref($fields) eq 'ARRAY')
			{
				$class_fields_href = {
					(%COMMON_FIELDS),
					map {$_ => undef} @$fields
				} ;
			}
			elsif (ref($fields) eq 'HASH')
			{
				$class_fields_href = {
					(%COMMON_FIELDS),
					(%$fields)
				} ;
			}
			else
			{
				$class_fields_href = {
					(%COMMON_FIELDS),
					($fields => undef)
				} ;
			}
			
			$FIELD_LIST{$class} = $class_fields_href ;
		}


		## Create private fields
		
prt_data(" init_class: class=$class FIELD_LIST=", \%FIELD_LIST) if $global_debug>=4 ;

		# Finished
		$CLASS_INIT{$class}=1;
	}

	print "init_class() - done\n" if $global_debug>=3 ;
}

#-----------------------------------------------------------------------------

=item C<add_fields($fields_href, $args_href)>

Adds the contents of the HASH ref $fields_href to the args HASH ref ($args_href) under the key
'fields'. Used by derived objects to add their fields to the parent object's fields.


=cut

sub add_fields
{
	my $this = shift ;
	my ($fields_href, $args_href) = @_ ;

	# Add extra fields
	foreach (keys %$fields_href)
	{
		$args_href->{'fields'}{$_} = $fields_href->{$_} ;
	}

}

#-----------------------------------------------------------------------------

=item C<init_class_instance([%args])>

Initialises the object class variables. Creates a class instance so that these
methods can also be called via the class (don't need a specific instance)

=cut

sub init_class_instance
{
	my $class = shift ;
	my (%args) = @_ ;

	$class->init_class(%args) ;

	# Create a class instance object - allows these methods to be called via class
	$class->class_instance(%args) ;
	
	# Set any global values
	$class->set(%args) ;
}

#----------------------------------------------------------------------------
# Return fields hash
sub _field_list
{
	my $class = shift ;

	return %FIELD_LIST ;
}

#============================================================================================
# CLASS METHODS 
#============================================================================================

#----------------------------------------------------------------------------

=item C<global_debug(level)>

Set global debug print options to I<level>. 

	0 = No debug
	1 = standard debug information
	2 = verbose debug information

=cut

sub global_debug
{
	my $this = shift ;
	my ($flag) = @_ ;

	my $class = $this->class() ;

	my $old = $global_debug ;
	$global_debug = $flag if defined($flag) ;

	return $old ;
}


#----------------------------------------------------------------------------

=item C<global_verbose(level)>

Set global verbose print level to I<level>. 

	0 = None verbose
	1 = verbose information
	2 = print commands
	3 = print command results

=cut

sub global_verbose
{
	my $this = shift ;
	my ($flag) = @_ ;

	my $class = $this->class() ;

	my $old = $global_verbose ;
	$global_verbose = $flag if defined($flag) ;

	return $old ;
}

#----------------------------------------------------------------------------

=item C<strict_fields($flag)>

Enable/disable strict field checking

=cut

sub strict_fields
{
	my $this = shift ;
	my ($flag) = @_ ;

	my $class = $this->class() ;

	my $old = $strict_fields ;
	$strict_fields = $flag if defined($flag) ;

	return $old ;
}

#----------------------------------------------------------------------------

=item C<class_instance([%args])>

Returns an object that can be used for class-based calls - object contains
all the usual fields
 
=cut

sub class_instance
{
	my $this = shift ;
	my (@args) = @_ ;

	my $class = $this->class() ;

	if ($class->allowed_class_instance() && !$class->has_class_instance())
	{
		$CLASS_INSTANCE{$class} = 1 ; # ensure we don't get here again (breaks recursive loop)

		print "-- Create class instance --\n" if $global_debug>=3 ;
		
		# Need to create one using the args
		$CLASS_INSTANCE{$class} = $class->new(@args) ;
	}


	return $CLASS_INSTANCE{$class} ;
}

#----------------------------------------------------------------------------

=item C<has_class_instance()>

Returns true if this class has a class instance object
 
=cut

sub has_class_instance
{
	my $this = shift ;
	my $class = $this->class() ;

#prt_data("has_class_instance($class) CLASS_INSTANCE=", \%CLASS_INSTANCE) if $global_debug>=5 ;

	return exists($CLASS_INSTANCE{$class}) ;
}

#----------------------------------------------------------------------------

=item C<allowed_class_instance()>

Returns true if this class can have a class instance object
 
=cut

sub allowed_class_instance
{
	return 1 ;
}

#----------------------------------------------------------------------------

=item C<field_list()>

Returns hash of object's field definitions.

=cut

sub field_list
{
	my $this = shift ;

	my $class = $this->class() ;
	
	my $href ;
	$href = $FIELD_LIST{$class} if exists($FIELD_LIST{$class}) ;

	return $href ? %$href : () ;
}


#============================================================================================
# OBJECT DATA METHODS 
#============================================================================================

#----------------------------------------------------------------------------

=item C<debug(level)>

Set debug print options to I<level>. 


=cut

sub debug
{
	my $this = shift ;
	my ($level) = @_ ;

	my $class = $this->class() ;

#print "debug($level) class=$class\n" ;

	if (defined $level)
	{
		# set level and class that it was set for
		$this->debug_level($level) ;
		$this->debug_pkg($class) ;
#print " + set debug=$level pkg=$class\n" ;
	}
	
	# get level and class set at
	my $debug_level = $this->debug_level() ;
	my $debug_pkg = $this->debug_pkg() || '' ;
#print " + get debug=$debug_level pkg=$debug_pkg\n" ;

	# if class read at is not class set at, then don't debug
	$debug_level = 0 unless $class eq $debug_pkg ;
#print " + ret debug=$debug_level (pkg=$debug_pkg class=$class)\n" ;
	
	return $debug_level ;
}


#----------------------------------------------------------------------------

=item C<verbose(level)>

Set verbose print level to I<level>. 

	0 = None verbose
	1 = verbose information
	2 = print commands
	3 = print command results

=cut

sub verbose
{
	my $this = shift ;
	my ($level) = @_ ;

	my $class = $this->class() ;

	if (defined $level)
	{
		# set level and class that it was set for
		$this->verbose_level($level) ;
		$this->verbose_pkg($class) ;
	}
	
	# get level and class set at
	my $verbose_level = $this->verbose_level() ;
	my $verbose_pkg = $this->verbose_pkg() ;

	# if class read at is not class set at, then don't verbose
	$verbose_level = 0 unless $class eq $verbose_pkg ;
	
	return $verbose_level ;
}


#----------------------------------------------------------------------------

=item C<set(%args)>

Set one or more settable parameter.

The %args are specified as a hash, for example

	set('mmap_handler' => $mmap_handler)

Sets field values. Field values are expressed as part of the HASH (i.e. normal
field => value pairs).

=cut

sub set
{
	my $this = shift ;
	my (%args) = @_ ;

	prt_data("set() ARGS=", \%args, "\n") if $global_debug>=3 ;

    $this = $this->check_instance() ;
	my $class = $this->class() ;
	
	# Args
	my %field_list = $this->field_list() ;
	foreach my $field (keys %field_list)
	{
		if (exists($args{$field})) 
		{
			print " + set $field = $args{$field}\n" if $global_debug>=3 ;


			# Need to call actual method (rather than ___set) so that it can be overridden
			if (!defined($args{$field}))
			{
				# Set to undef
				my $undef_method = "undef_$field" ;
				$this->$undef_method()  ;
			}
			else
			{
				$this->$field($args{$field})  ;
			}
		}
	}

	## See if strict checks are enabled
	if ($strict_fields)
	{
		# Check to ensure that only the valid fields are being set
		foreach my $field (keys %args)
		{
			if (!exists($field_list{$field}))
			{
				print "WARNING::Attempt to set invalid field \"$field\" \n" ;
				$this->dump_callstack() ;
			} 
		}
	}
	
	print "set() - done\n" if $global_debug>=3 ;

}

#----------------------------------------------------------------------------

=item C<vars([@names])>

Returns hash of object's fields (i.e. field name => field value pairs).

If @names array is specified, then only returns the HASH containing the named fields.

=cut

sub vars
{
	my $this = shift ;
	my (@names) = @_ ;

	my %field_list = $this->field_list() ;
	my %fields ;

#prt_data("vars() names=", \@names) ;
	
	# If no names specified then get all of them
	unless (@names)
	{
		@names = keys %field_list ;
	}
	my %names = map {$_ => 1} @names ;
#prt_data(" + names=", \%names) ;
	
	# Get the value of each field
	foreach my $field (keys %field_list)
	{
		# Store field if we've asked for it
		$fields{$field} = $this->$field() if exists($names{$field}) ;
#print " + + $field : " ;
#if (exists($fields{$field}))
#{
#	print "ok ($fields{$field})\n" ;
#}
#else
#{
#	print "not wanted\n" ;
#}
	}
	
	return %fields ;
}




#----------------------------------------------------------------------------

=item C<DESTROY()>

Destroy object

=cut

sub DESTROY
{
	my $this = shift ;

}


#============================================================================================
# OBJECT METHODS 
#============================================================================================

#----------------------------------------------------------------------------

=item C<check_instance()>

If this is not an instance (i.e. a class call), then if there is a class_instance
defined use it, otherwise error.

=cut

sub check_instance
{
	my $this = shift ;
	my (%args) = @_ ;

	my $class = $this->class() ;
	
	if (!ref($this))
	{
		if ($class->has_class_instance())
		{
			$this = $class->class_instance() ;
		}
		else
		{
			croak "$this is not a usable object" ;
		}
	}

	return $this ;	
}


#----------------------------------------------------------------------------

=item C<copy_attributes($target)>

Transfers all the supported attributes from $this object to $target object.

=cut

sub copy_attributes
{
	my $this = shift ;
	my ($target) = @_ ;

    $this = $this->check_instance() ;
    $target = $target->check_instance() ;
	
	# Get list of fields in the target
	my %target_field_list = $target->field_list() ;
	
	# Copy values from this object
	my %field_list = $this->field_list() ;
	foreach my $field (keys %target_field_list)
	{
		# see if can copy
		if (exists($field_list{$field}))
		{
			$target->set($field => $this->$field()) ;
		}
	}
	
}

#----------------------------------------------------------------------------

=item C<class()>

Returns name of object class.

=cut

sub class
{
	my $this = shift ;

	my $class = ref($this) || $this ;
	
	return $class ;
}

#----------------------------------------------------------------------------

=item C<clone()>

Create a copy of this object and return the copy.

=cut

sub clone
{
	my $this = shift ;

	my $clone ;
	
	# TODO: WRITE IT!
	
	return $clone ;
}



# ============================================================================================
# UTILITY METHODS
# ============================================================================================



#----------------------------------------------------------------------------

=item C<quote_str($str)>

Returns a quoted version of the string.
 
=cut

sub quote_str
{
	my $this = shift ;
	my ($str) = @_ ;
	
	my $class = $this->class() ;

	# skip on Windows machines
	unless ($^O eq 'MSWin32')
	{
		# first escape any existing quotes
		$str =~ s%\\'%'%g ;
		$str =~ s%'%'\\''%g ;
	
		$str = "'".$str."'" ;
	}
	
	
	return $str ;
}

#----------------------------------------------------------------------------

=item C<expand_vars($string, \%vars)>

Work through string expanding any variables, replacing them with the value stored in the %vars hash.
If variable is not stored in %vars, then that variable is left.

Returns expanded string.

=cut

sub expand_vars 
{
	my $this = shift ;
	my ($string, $vars_href) = @_ ;


	# Do replacement
	$string =~ s{
				     \$                         # find a literal dollar sign
				     \{{0,1}					# optional brace
				    (\w+)                       # find a "word" and store it in $1
				     \}{0,1}					# optional brace
				}{
				    no strict 'refs';           # for $$1 below
				    if (defined $vars_href->{$1}) {
				        $vars_href->{$1};            # expand variable
				    } else {
				        "\${$1}";  				# leave it
				    }
				}egx;

	return $string ;
}



#---------------------------------------------------------------------

=item C<prt_data(@args)>

Use App::Framework::Base::Object::DumpObj to print out variable information. Automatically enables
object print out
 
=cut

sub prt_data 
{
	my $this = shift ;
	my (@args) = @_ ;
	
	App::Framework::Base::Object::DumpObj::print_objects_flag(1) ;
	App::Framework::Base::Object::DumpObj::prt_data(@args) ;
}

#----------------------------------------------------------------------------
#
#=item C<_dbg_prt($items_aref [, $min_debug])>
#
#Print out the items in the $items_aref ARRAY ref iff the calling object's debug level is >0. 
#If $min_debug is specified, will only print out items if the calling object's debug level is >= $min_debug.
#
#=cut
#
sub _dbg_prt
{
	my $obj = shift ;
	my ($items_aref, $min_debug) = @_ ;

	$min_debug ||= 1 ;
	
	## check debug level setting
	if ($obj->debug >= $min_debug)
	{
		my $pkg = ref($obj) ;
		$pkg =~ s/App::Framework/ApFw/ ;
		
		my $prefix = App::Framework::Base::Object::DumpObj::prefix("$pkg ::  ") ;
		$obj->prt_data(@$items_aref) ;
		App::Framework::Base::Object::DumpObj::prefix($prefix) ;
	}
}



#---------------------------------------------------------------------

=item C<dump_callstack()>

Print out the call stack. Useful for debug output at a crash site. 
=cut

sub dump_callstack 
{
	my $this = shift ;
	my ($package, $filename, $line, $subr, $has_args, $wantarray) ;
	my $i=0 ;
	print "\n-----------------------------------------\n";
	do
	{
		($package, $filename, $line, $subr, $has_args, $wantarray) = caller($i++) ;
		if ($subr)
		{
			print "$filename :: $subr :: $line\n" ;	
		}
	}
	while($subr) ;
	print "-----------------------------------------\n\n";
}



# ============================================================================================
# PRIVATE METHODS
# ============================================================================================

#----------------------------------------------------------------------------
# Set field value
sub ___set
{
	my $this = shift ;
	my ($field, $new_value) = @_ ;

	my $class = $this->class() ;
	my $value ;

	# Check that field name is valid
	my %field_list = $this->field_list() ;
	if (!exists($field_list{$field}))
	{
		prt_data("$class : ___set($field) invalid field. Valid fields=", \%field_list) if $global_debug>=5 ;
		$this->dump_callstack() if $global_debug>=10 ;

		# TODO: Do something more useful!
		croak "$class: Attempting to write invalid field $field" ;
	}
	else
	{
		# get existing value
		$value = $this->{$field} ;
		
		# write
		$this->{$field} = $new_value ;
	}
	print " + ___set($field) <= $new_value (was $value)\n" if $global_debug>=5 ;

	# Return previous value
	return $value ;
}

#----------------------------------------------------------------------------
# get field value
sub ___get
{
	my $this = shift ;
	my ($field) = @_ ;

	my $value ;
	
	my $class = $this->class() ;

	# Check that field name is valid
	my %field_list = $this->field_list() ;
	if (!exists($field_list{$field}))
	{
		prt_data("$class : ___get($field) invalid field. Valid fields=", \%field_list) if $global_debug>=5 ;
prt_data("$class : ___get($field) invalid field. Valid fields=", \%field_list) ;
		$this->dump_callstack() if $global_debug>=10 ;
$this->dump_callstack() ;

		# TODO: Do something more useful!
		croak "$class: Attempting to access invalid method $field (or read using invalid data accessor)" ;
	}
	else
	{
		# get existing value
		$value = $this->{$field} ;
	}

	print " + ___get($field) = $value\n" if $global_debug>=5 ;

	# Return previous value
	return $value ;
}


# ============================================================================================

# Autoload handle only field value set/undefine
# Set method = <name>
# Undefine method = undef_<name>
#
sub AUTOLOAD 
{
	print "AUTOLOAD ($AUTOLOAD)\n" if $global_debug>=5 ;

    my $this = shift;
#	prt_data("AUTOLOAD ($AUTOLOAD) this=", $this) if $global_debug>=5 ;

#print "$this=",ref($this),"\n";
	if (!ref($this)||ref($this)eq'ARRAY')
	{
		croak "AUTOLOAD ($AUTOLOAD) (@_): $this is not a valid object" ;
	}

    $this = $this->check_instance() ;
#	prt_data(" + this=", $this) if $global_debug>=5 ;

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion
    my $class = $AUTOLOAD;
    $class =~ s/::[^:]+$//;  # get class

    my $type = ref($this) ;
    
#    if (!$type)
#    {
#    	# see if there is a class instance object defined
#    	if ($class->has_class_instance())
#    	{
#	    	$this = $class->class_instance() ;
#	    	$type = ref($this) ;
#    	}
#		else
#		{
#			croak "$this is not an object";
#		}
#    }

	# possibly going to set a new value
	my $set=0;
	my $new_value = shift;
	$set = 1 if defined($new_value) ;
	
	# 1st see if this is of the form undef_<name>
	if ($name =~ m/^undef_(\w+)$/)
	{
		$set = 1 ;
		$name = $1 ;
		$new_value = undef ;
	}

	my $value = $this->___get($name);

	if ($set)
	{
		$this->___set($name, $new_value) ;
	}

	# Return previous value
	return $value ;
}



# ============================================================================================
# END OF PACKAGE
1;

__END__


