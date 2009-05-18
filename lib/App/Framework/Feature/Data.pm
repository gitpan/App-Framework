package App::Framework::Feature::Data ;

=head1 NAME

App::Framework::Feature::Data - Handle application setup data

=head1 SYNOPSIS

  # Data feature is loaded by default as if the script contained:
  use App::Framework '+Data' ;


=head1 DESCRIPTION

System feature that provides the application core with access to the setup information stored
in the __DATA__ section.

The __DATA__ section at the end of the script is used by the application framework to allow the script developer to define
various settings for his/her script. This setup is split into "headed" sections of the form:

  [ <section name> ]
  
  <settings>

In general, the <section name> is the name of a field value in the application, and <settings> is some text that the field will be set to. Sections
of this type are:

=over 4

=item B<[SUMMARY]> - Application summary text

A single line summary of the application. Used for man pages and usage summary. 

(Stored in the application's I<summary> field).

=item B<[DESCRIPTION]> - Application description text

Multiple line description of the application. Used for man pages. 

(Stored in the application's I<description> field).

=item B<[SYNOPSIS]> - Application synopsis [I<optional>]

Multiple line synopsis of the application usage. By default the application framework creates this if it is not specified. 

(Stored in the application's I<synopsis> field).

=item B<[NAME]> - Application name [I<optional>]

Name of the application usage. By default the application framework creates this if it is not specified. 

(Stored in the application's I<name> field).

=back

__DATA__ sections that have special meaning are:

=over 4

=item B<[OPTIONS]> - Application command line options

These are fully described in L<App::Framework::Features::Options>.

If no options are specified, then only those created by the application framework will be defined. 

=item B<[ARGS]> - Application command line arguments [I<optional>]

These are fully described in L<App::Framework::Features::Args>.

=back


=head2 Named Data

After the settings (described above), one or more extra data areas can be created by starting that area with a new __DATA__ line.

Each defined data area is named 'data1', 'data2' and so on. These data areas are user-defined multi line text that can be accessed 
by the object's accessor method L</access>, for example:

	my $data = $app->data('data1') ;

Alternatively, the user-defined data section can be arbitrarily named by appending a text name after __DATA__. For example, the definition:

	__DATA__
	
	[DESCRIPTION]
	An example
	
	__DATA__ test.txt
	
	some text
	
	__DATA__ a_bit_of_sql.sql
	
	DROP TABLE IF EXISTS `listings2`;
	 

leads to the use of the defined data areas as:

	my $file = $app->data('text.txt') ;
	# or
	$file = $app->data('data1') ;

	my $sql = $app->data('a_bit_of_sql.sql') ;
	# or
	$file = $app->data('data2') ;


=head2 Variable Expansion

The data text can contain variables, defined using the standard Perl format:

	$<name>
	${<name>}

When the data is used, the variable is expanded and replaced with a suitable value. The value will be looked up from a variety of possible sources:
object fields (where the variable name matches the field name) or environment variables.

The variable name is looked up in the following order, the first value found with a matching name is used:

=over 4

=item *

Option names - the values of any command line options may be used as variables

=item *

Application fields - any fields of the $app object may be used as variables

=item *

Environment variables - if no application fields match the variable name, then the environment variables are used

=back 



=cut

use strict ;
use Carp ;

our $VERSION = "1.000" ;


#============================================================================================
# USES
#============================================================================================
use App::Framework::Feature ;
use App::Framework::Base ;

#============================================================================================
# OBJECT HIERARCHY
#============================================================================================
our @ISA = qw(App::Framework::Feature) ; 

#============================================================================================
# GLOBALS
#============================================================================================


=head2 FIELDS

No public fields

=cut

my %FIELDS = (
	'_data'				=> [],
	'_data_hash'		=> {},
	'_user_options'		=> [],
) ;

=head2 ADDITIONAL COMMAND LINE OPTIONS

This feature adds the following additional command line options to any application:

=over 4

=item B<-dbg-data> - show __DATA__

Display the __DATA__ definition text then exit

=item B<-dbg-data-array> - show all __DATA__ items

Show all of the processed __DATA__ items then exit

=back

=cut

my @OPTIONS = (
	['dev:dbg-data',		'Debug option: Show __DATA__', 				'Show __DATA__ definition in script then exit' ],
	['dev:dbg-data-array',	'Debug option: Show all __DATA__ items', 	'Show all processed __DATA__ items then exit' ],
) ;


#============================================================================================

=head2 CONSTRUCTOR

=over 4

=cut

#============================================================================================


=item B< new([%args]) >

Create a new Data.

The %args are specified as they would be in the B<set> method (see L</Fields>).

=cut

sub new
{
	my ($obj, %args) = @_ ;

	my $class = ref($obj) || $obj ;

	# Create object
	my $this = $class->SUPER::new(%args,
		'priority' 			=> $App::Framework::Base::PRIORITY_SYSTEM + 20,		# needs to be after options
		'registered'		=> [qw/app_start_exit application_entry/],
		'feature_options'	=> \@OPTIONS,
	) ;

#$this->debug(2);

	
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

Initialises the Data object class variables.

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

=item B<app_start_exit()>

Called at the end of app_start. Used to expand the variables in the data 

=cut


sub app_start_exit
{
	my $this = shift ;

	## Handle special options
	my $app = $this->app ;
	my %opts = $app->options() ;
	my %app_vars = $app->vars ;
	
	my $data_href = $this->_data_hash() ;

	$this->expand_keys($data_href, [\%opts, \%app_vars, \%ENV]) ;
}


#----------------------------------------------------------------------------

=item B<application_entry()>

Called at start of application 

=cut


sub application_entry
{
	my $this = shift ;

	## Handle special options
	my $app = $this->app ;
	my %opts = $app->options() ;
	## Debug
	if ($opts{'dbg-data'})
	{
		$this->_show_data() ;
		$app->exit(0) ;
	}
	if ($opts{'dbg-data-array'})
	{
		$this->_show_data_array() ;
		$app->exit(0) ;
	}

	
}

#----------------------------------------------------------------------------

=item B< access([$name]) >

Returns the lines for the named __DATA__ section. If no name is specified
returns the first section. If an ARRAY is required, returns the array; otherwise
concatenates the lines with "\n".

Returns undef if no data found, or no section with specified name

=cut

sub access
{
	my $this = shift ;
	my ($name) = @_ ;
	
	my $data_ref ;
	$name ||= "" ;

print "Data: access($name)" if $this->debug() ;
	
	if ($name)
	{
		my $data_href = $this->_data_hash() ;
		if (exists($data_href->{$name}))
		{
			$data_ref = $data_href->{$name} ;
		}		
	}
	else
	{
		my $data_aref = $this->_data() ;
		if (@$data_aref)
		{
			$data_ref = $data_aref->[0] ;
		}
		
	}

	return undef unless $data_ref ;
	
	return wantarray ? @$data_ref : join "\n", @$data_ref ;	
}



#----------------------------------------------------------------------------

=item B<process()>

If caller package namespace has __DATA__ defined then use that information to set
up object parameters.


=cut

sub process 
{
	my $this = shift ;
	my $app = $this->app ;
	
	my $package = $app->package() ;

print "Data: Process data from package $package" if $this->debug() ;

    local (*alias, *stash);             # a local typeglob

    # We want to get access to the stash corresponding to the package
    # name
no strict "vars" ;
no strict "refs" ;
    *stash = *{"${package}::"};  # Now %stash is the symbol table

	if (exists($stash{'DATA'}))
	{
		my @data ;
		my %data ;
		my $data_aref = [] ;
		
		push @data, $data_aref ;
		
		*alias = $stash{'DATA'} ;

print "Reading __DATA__\n" if $this->debug() ;

		## Read data in - first split into sections
		my $line ;
		my $data_num = 0 ;
		while (defined($line=<alias>))
		{
			chomp $line ;
print "DATA: $line\n" if $this->debug()>=2 ;
			
			if ($line =~ m/^\s*__DATA__/)
			{
print "+ New __DATA__\n" if $this->debug()>=2 ;
				# Start a new list
				$data_aref = [] ;
				push @data, $data_aref ;

print "+ Data list size=",scalar(@data),"\n" if $this->debug()>=2 ;
				
				# default name
				my $name = sprintf "data%d", $data_num++ ;
				$data{$name} = $data_aref ;
				
				# Check for specified name
				if ($line =~ m/__DATA__\s*(\S+)/)
				{
					$name = $1 ;
					$data{$name} = $data_aref ;
print "+ + named __DATA__ : $name\n" if $this->debug()>=2 ;
				}
			}
			elsif ($line =~ m/^\s*__END__/ )
			{
print "+ __END__\n" if $this->debug()>=2 ;
				last ;
			}
			elsif ($line =~ m/^\s*__#/ )
			{
print "+ __# comment\n" if $this->debug()>=2 ;
				# skip
			}
			else
			{
				push @$data_aref, $line ;
			}
		}
$this->prt_data("Gathered data=", \@data) if $this->debug()>=2 ;

		# Store
		$this->_data(\@data) ;
		$this->_data_hash(\%data) ;

print "Processing __DATA__\n" if $this->debug() ;
		
		## Look at first section
		my $obj_settings=0;
		$data_aref = $data[0] ;
		my $field ;
		my @field_data ;
		foreach $line (@$data_aref)
		{
#print "field=$field : $line\n" ;

			if ($line =~ m/^\s*\[(\w+)\]/)
			{
				my ($new_field) = lc $1 ;
				
				# This is object settings, so need to remove from list
				$obj_settings=1;

#$this->prt_data(" + Handling field $field - data=", \@field_data) ;
				
				# Use the data found so far for this field
				$this->_handle_field($field, \@field_data) if $field ;
				
				# next field
				$field = $new_field ;
				@field_data = () ;

#print " + NEW field=$field\n" ;
				
			}
			elsif ($field)
			{
#print " + storing line\n" ;
				push @field_data, $line ;
			}
		}

		if ($field)
		{
			# Use the data found so far for this field
			$this->_handle_field($field, \@field_data) ;
		}

	}

}


#----------------------------------------------------------------------------

=item B<append_user_options()>

Adds any user-defined options to the end of the options list 

=cut

sub append_user_options 
{
	my $this = shift ;
	my $app = $this->app ;
	
	my $user_opts_aref = $this->_user_options ;
	$app->feature('Options')->append_options($user_opts_aref, 'user') ;
}

# ============================================================================================
# PRIVATE METHODS
# ============================================================================================


#----------------------------------------------------------------------------
#
#=item B<_handle_field($field_data_aref)>
#
#Set the field based on the accumlated data
#
#=cut
#
sub _handle_field 
{
	my $this = shift ;
	my ($field, $field_data_aref) = @_ ;

	my $app = $this->app ;

print "Data: _handle_field($field, $field_data_aref)\n" if $this->debug()>=2 ;

	# Handle any existing field values
	if ($field eq 'options')
	{
		# Parse the data into options
		my @options = $this->_parse_options($field_data_aref) ;

print "Data: set app options\n" if $this->debug()>=2 ;
		## Access the application's 'Options' feature to set the options
#		$app->feature('Options')->append_options(\@options) ;
		$this->_append_options(\@options) ;
	}
	elsif ($field eq 'args')
	{
		# Parse the data into args
		my @args = $this->_parse_options($field_data_aref) ;

print "Data: set app options\n" if $this->debug()>=2 ;
		## Access the application's 'Options' feature to set the options
		$app->feature('Args')->append_args(\@args) ;
	}
	else
	{
		# Glue the lines together and set the field
		my $data = join "\n", @$field_data_aref ;

		# Remove leading/trailing space
		$data =~ s/^\s+// ;
		$data =~ s/\s+$// ;

print "Data: set app field $field => $data\n" if $this->debug()>=2 ;
			
		## Set field directly into application	
		$app->set($field => $data) ;
	}
}


#----------------------------------------------------------------------------
#
#=item B<_parse_options($data_aref)>
#
#Parses option definition lines(s) of the form:
# 
# -<opt>[=s]		Summary of option [default=<value>]
# Description of option
#
#Optional [default] specification that sets the option to the default if not otherwised specified.
#
#And returns an ARRAY in the format useable by the 'options' method. 
#
#=cut
#
sub _parse_options 
{
	my $this = shift ;
	my ($data_aref) = @_ ;

print "Data: _parse_options($data_aref)\n" if $this->debug()>=2 ;

	my @options ;
	
	# Scan through the options specification to create a number of options entries
	my ($spec, $summary, $description, $default_val) ;
	foreach my $line (@$data_aref)
	{
		## Options specified as:
		#
		# -<name list>[=<opt spec>]  [\[default=<default value>\]]
		#
		# <name list>:
		#    <name>|'<name>'
		#
		# <opt spec> (subset of that supported by Getopt::Long):
		#    <type> [ <desttype> ]	
		# <type>:
		#	s = String. An arbitrary sequence of characters. It is valid for the argument to start with - or -- .
		#	i = Integer. An optional leading plus or minus sign, followed by a sequence of digits.
		#	o = Extended integer, Perl style. This can be either an optional leading plus or minus sign, followed by a sequence of digits, or an octal string (a zero, optionally followed by '0', '1', .. '7'), or a hexadecimal string (0x followed by '0' .. '9', 'a' .. 'f', case insensitive), or a binary string (0b followed by a series of '0' and '1').
		#	f = Real number. For example 3.14 , -6.23E24 and so on.
		#	
		# <desttype>:
		#   @ = store options in ARRAY ref
		#   % = store options in HASH ref
		# 
		if ($line =~ m/^\s*[\-\*\+]\s*([\'\"\w\|\=\%\@\+\{\:\,\}\-\_\>\<\*]+)\s+(.*?)\s*(\[default=([^\]]+)\]){0,1}\s*$/)
		{
			# New option
			my ($new_spec, $new_summary, $new_default, $new_default_val) = ($1, $2, $3, $4) ;
			print " + spec: $new_spec,  summary: $new_summary,  default: $new_default, defval=$new_default_val\n" if $this->debug()>=2 ;

			# Allow default value to be specified with "" or ''
			if (defined($new_default_val))
			{
				$new_default_val =~ s/^['"](.*)['"]$/$1/ ;
			}

			# Save previous option			
			if ($spec)
			{
				# Remove leading/trailing space
				$description ||= '' ;
				$description =~ s/^\s+// ;
				$description =~ s/\s+$// ;

				push @options, [$spec, $summary, $description, $default_val] ;
			}
			
			# update current
			($spec, $summary, $default_val, $description) = ($new_spec, $new_summary, $new_default_val, '') ;
		}
		elsif ($spec)
		{
			# Add to description
			$description .= "$line\n" ;
		}
	}

	# Save option
	if ($spec)
	{
		# Remove leading/trailing space
		$description ||= '' ;
		$description =~ s/^\s+// ;
		$description =~ s/\s+$// ;

		push @options, [$spec, $summary, $description, $default_val] ;
	}
	
	return @options ;
}


#----------------------------------------------------------------------------
#
#=item B<_append_options($aref)>
#
#Add these user defined options to the list
#
#=cut
#
sub _append_options 
{
	my $this = shift ;
	my ($aref) = @_ ;

	my $options = $this->_user_options ;
	push @$options, @$aref ;
}

#----------------------------------------------------------------------------
#
#=item B<_show_data()>
#
#Show the __DATA__ defined in the main script. Run when option --dg-data is used
# 
#=cut
#
sub _show_data 
{
	my $this = shift ;
	my ($package) = @_ ;

    local (*alias);             # a local typeglob

    # We want to get access to the stash corresponding to the package
    # name
no strict "vars" ;
no strict "refs" ;
    *stash = *{"${package}::"};  # Now %stash is the symbol table

	if (exists($stash{'DATA'}))
	{
		*alias = $stash{'DATA'} ;

		print "## DATA ##\n" ;
		my $line ;
		while (defined($line=<alias>))
		{
			print "$line" ;
		}
		print "## DATA END ##\n" ;

	}
}


#----------------------------------------------------------------------------
#
#=item B<_show_data_array()>
#
#Show data array (after processing the __DATA__ defined in the main script). 
#
#Run when option --debug-show-data-arry is used
# 
#=cut
#
sub _show_data_array
{
	my $this = shift ;

	my $data_aref = $this->_data() ;
	my $data_href = $this->_data_hash() ;
	
	# Get addresses from hash
	my %lookup = map { $data_href->{$_} => $_ } keys %$data_href ;
	
	# Show each data
	foreach my $data_ref (@$data_aref)
	{
		my $name = '' ;
		if (exists($lookup{$data_ref}))
		{
			$name = $lookup{$data_ref} ;
		}
		print "\n__DATA__ $name\n" ;
		
		foreach my $data (@$data_ref)
		{
			print "$data\n" ;
		}
		print "--------------------------------------\n" ;
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


