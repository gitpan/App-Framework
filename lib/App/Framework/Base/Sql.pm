package App::Framework::Base::Sql ;

=head1 NAME

Sql - MySql interface

=head1 SYNOPSIS

use Sql ;


=head1 DESCRIPTION


=head1 DIAGNOSTICS

Setting the debug flag to level 1 prints out (to STDOUT) some debug messages, setting it to level 2 prints out more verbose messages.

=head1 AUTHOR

Steve Price E<lt>sdprice@sdprice.plus.comE<gt>

=head1 BUGS

None that I know of!

=head1 INTERFACE

=over 4

=cut

use strict ;
use Carp ;
use Cwd ;

our $VERSION = "2.008" ;

#============================================================================================
# USES
#============================================================================================
use App::Framework::Base::Object::Logged ;

use DBI();
use Date::Manip ;



#============================================================================================
# OBJECT HIERARCHY
#============================================================================================
our @ISA = qw(App::Framework::Base::Object::Logged) ; 

#============================================================================================
# GLOBALS
#============================================================================================

=back

=head2 Fields

	'database'	=> Database name (required)
	'table'		=> Table name
	'user'		=> User name (required)
	'password'	=> Password (required)
	
	'trace'		=> Sql debug trace level (default=0)
	'trace_file'=> If specified, output trace information to file (default=STDOUT)
	
	'prepare'	=> HASH ref to one or more STH definitions (as required by L<sth_create()>)
				   Each HASH entry is of the form:
				   
				   'name' => (specification as per L<sth_create()>)
				   
				   Where 'name' is the name used when the STH is created

=over 4

=cut



my %FIELDS = (
	# Object Data
	'dbh'			=> undef,
	'database'		=> undef,
	'table'			=> undef,
	'user'			=> undef,
	'password'		=> undef,
	'trace'			=> 0,
	'trace_file'	=> undef,
	
	'prepare'		=> undef,		# Special 'parameter' used to create STHs 
	
#	'_result'		=> undef,		# = current sth
#	'_error'		=> undef,		# Not used
#	'_record'		=> undef,		# = ($sth->fetchrow_hashref() || 0) set in next()

#	'_num_rows'		=> undef,		# Not used
#	'_data'			=> {},			# Not used
	
	'_sth'			=> {},
) ;

my $DEFAULT_STH_NAME = "_current" ;

#* DELETE
#
#DELETE [LOW_PRIORITY] [QUICK] [IGNORE] 
#	FROM tbl_name
#    [WHERE where_condition]
#    [ORDER BY ...]
#    [LIMIT row_count]
#
#"DELETE FROM `$table` WHERE `pid`=? AND `channel`=? LIMIT 1;"
#
#
#* INSERT / REPLACE
#
#INSERT [LOW_PRIORITY | DELAYED | HIGH_PRIORITY] [IGNORE]
#    [INTO] tbl_name [(col_name,...)]
#    VALUES ({expr | DEFAULT},...),(...),...
#    [ ON DUPLICATE KEY UPDATE
#      col_name=expr
#        [, col_name=expr] ... ]
#
#"INSERT INTO `$table` ( `pid`, `channel`, `title`, `date`, `start`, `duration`, `episode`, `num_episodes`, `repeat`, `text` ) ". 
#'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);'
#
#Or:
#
#INSERT [LOW_PRIORITY | DELAYED | HIGH_PRIORITY] [IGNORE]
#    [INTO] tbl_name
#    SET col_name={expr | DEFAULT}, ...
#    [ ON DUPLICATE KEY UPDATE
#      col_name=expr
#        [, col_name=expr] ... ]
#
#"INSERT INTO `$table` SET `title`=?, `date`=?, `start`=?, `duration`=?, `text`=?, `episode`=?, `num_episodes`=?, `repeat`=? "
#
#
#
#* SELECT
#
#SELECT
#    [ALL | DISTINCT | DISTINCTROW ]
#      [HIGH_PRIORITY]
#      [STRAIGHT_JOIN]
#      [SQL_SMALL_RESULT] [SQL_BIG_RESULT] [SQL_BUFFER_RESULT]
#      [SQL_CACHE | SQL_NO_CACHE] [SQL_CALC_FOUND_ROWS]
#    select_expr, ...
#    [FROM table_references
#    [WHERE where_condition]
#    [GROUP BY {col_name | expr | position}
#      [ASC | DESC], ... [WITH ROLLUP]]
#    [HAVING where_condition]
#    [ORDER BY {col_name | expr | position}
#      [ASC | DESC], ...]
#    [LIMIT {[offset,] row_count | row_count OFFSET offset}]
#    [PROCEDURE procedure_name(argument_list)]
#    [INTO OUTFILE 'file_name' export_options
#      | INTO DUMPFILE 'file_name'
#      | INTO var_name [, var_name]]
#    [FOR UPDATE | LOCK IN SHARE MODE]]
#
#"SELECT `title` FROM `$table` WHERE `pid`=? AND `channel`=? LIMIT 1;"
#
#
#* UPDATE
#
#UPDATE [LOW_PRIORITY] [IGNORE] 
#	tbl_name
#    SET col_name1=expr1 [, col_name2=expr2] ...
#    [WHERE where_condition]
#    [ORDER BY ... ASC|DESC]
#    [LIMIT row_count]
#
#"UPDATE `$table` SET `title`=?, `date`=?, `start`=?, `duration`=?, `text`=?, `episode`=?, `num_episodes`=?, `repeat`=? ". 
#'WHERE `pid`=? AND `channel`=? LIMIT 1 ;'
#
#			where	order	limit	setlist		
#delete		  Y		Y		Y		-
#insert		  -		-		-		Y
#replace 	  -		-		-		Y
#select		  Y		Y		Y		-
#update		  Y		Y		Y		Y
#
#setlist 	=> [SET] `var`=?, `var`=? ..
#andlist	=> [WHERE] `var`=? AND `var`=? ..
#varlist	=> [SELECT|ORDER BY] `var`, `var`
#

my %CMDS = (
	'(sel|check)'	=> 'select',  
	'(del|rm)'		=> 'delete',  
	'ins'			=> 'insert',  
	'rep'			=> 'replace', 
	'upd'			=> 'update',  
) ;


=back

=head2 %CMD_SQL - Parse control hash

Variables get created with the name 

	* $sqlvar_<context>
	
where <context> is the hash key. This created variable contains the sql for this command or option.

If the control hash entry contains a 'vals' entry, then the following variable is created:

	* @sqlvar_<context>

This will be a text string containing something like "@sqlvar_select_vals,@sqlvar_where_vals" i.e. a comma
seperated list of references to other arrays. These values will be expanded into a real array before use in the
sql prepare.

Also, as each entry is processed, extra variables are created:

	* $sqlvar_<context>_prefix	- Prefix string for this entry
	* $sqlvar_<context>_format	- Just the same as sqlvar_<context>


=head2 Specification variables

This control hash is used to direct processing of the SQL specification passed to sth_create(). If the spec
contains a 'vars' field then these additional variables are created in the context: 

	* $sqlvar_<context>_varlist	- List of the 'vars' in the format `var`, `var` ..
	* $sqlvar_<context>_andlist	- List of the 'vars' in the format `var` AND `var` ..
	* $sqlvar_<context>_varlist	- List of the 'vars' in the format `var`=?, `var`=? ..

If the spec has a 'vals' entry, then these are pushed on to an ARRAY ref and stored in:

	* @sqlvar_<context>_vals

@sqlvar_<context>_vals = Real ARRAY ref (provided by the spec)
@sqlvar_<context> = String in the format "@sqlvar_select_vals,@sqlvar_where_vals" (provided by parse control hash)

=over 4

=cut



my %CMD_SQL = (

	## Overall query 
	'query'			=> {
			'format'	=> '$sqlvar_select$sqlvar_delete$sqlvar_insert$sqlvar_replace$sqlvar_update',
			'vals'		=> '@sqlvar_select,@sqlvar_delete,@sqlvar_insert,@sqlvar_replace,@sqlvar_update',
	},


	## Specific SQL commands
	'select'	=> {
			'prefix'	=> 'SELECT $sqlvar_select_varlist FROM `$sqlvar_table`',
			'format'	=> 'SELECT $sqlvar_select_varlist FROM `$sqlvar_table` $sqlvar_where $sqlvar_order $sqlvar_limit',
			'vals'		=> '@sqlvar_select_vals,@sqlvar_where_vals,@sqlvar_order_vals',
	},
	'delete'		=> {
			'prefix'	=> 'DELETE FROM `$sqlvar_table`',
			'format'	=> 'DELETE FROM `$sqlvar_table` $sqlvar_where $sqlvar_order $sqlvar_limit',
			'vals'		=> '@sqlvar_where_vals,@sqlvar_order_vals',
	},
	'insert'			=> {
			'prefix'	=> 'INSERT INTO `$sqlvar_table`',
			'format'	=> 'INSERT INTO `$sqlvar_table` SET $sqlvar_insert_setlist',
			'vals'		=> '@sqlvar_insert_vals',
	},
	'replace'			=> {
			'prefix'	=> 'REPLACE INTO `$sqlvar_table`',
			'format'	=> 'REPLACE INTO `$sqlvar_table` SET $sqlvar_replace_setlist',
			'vals'		=> '@sqlvar_replace_vals',
	},
	'update'			=> {
			'prefix'	=> 'UPDATE `$sqlvar_table`',
			'format'	=> 'UPDATE `$sqlvar_table` SET $sqlvar_update_setlist $sqlvar_where $sqlvar_order $sqlvar_limit',
			'vals'		=> '@sqlvar_update_vals,@sqlvar_where_vals,@sqlvar_order_vals',
	},
	
	## Command options
	'where'			=> {
			'prefix'	=> 'WHERE',
			'format'	=> 'WHERE $sqlvar_where_andlist',
	},

	'order'			=> {
			'prefix'	=> 'ORDER BY',
			'format'	=> 'ORDER BY $sqlvar_order_varlist $sqlvar_asc',
	},

	'limit'			=> {
			'prefix'	=> 'LIMIT',
			'format'	=> 'LIMIT $limit',
	},

) ;


#============================================================================================
# CONSTRUCTOR 
#============================================================================================

=item C<App::Framework::Base::Sql-E<gt>new([%args])>

Create a new Sql object.

The %args are specified as they would be in the B<set> method, for example:

	'mmap_handler' => $mmap_handler

The full list of possible arguments are :

	'fields'	=> Either ARRAY list of valid field names, or HASH of field names with default values 

=cut

sub new
{
	my ($obj, %args) = @_ ;

	my $class = ref($obj) || $obj ;

	# Create object
	my $this = $class->SUPER::new(%args) ;

	# Connect
	$this->connect() ;

	return($this) ;
}



#============================================================================================
# CLASS METHODS 
#============================================================================================

#-----------------------------------------------------------------------------

=item C<App::Framework::Base::Sql-E<gt>init_class([%args])>

Initialises the Sql object class variables.

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
# OBJECT METHODS 
#============================================================================================

#----------------------------------------------------------------------------

=item C<Object-E<gt>set(%args)>

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

	# ensure priority args are handled first
	my %priority ;
	foreach my $arg (qw/database user password table/)
	{
		my $val = delete $args{$arg} ;
		$priority{$arg} = $val if $val ; 
	}
	if (keys %priority)
	{
		$this->SUPER::set(%priority) ;

		# Connect
		$this->connect() ;		
	}
	
	# handle the rest
	$this->SUPER::set(%args) if keys %args ;

}


#----------------------------------------------------------------------------

=item C<Sql-E<gt>prepare($prepare_href)>

Use HASH ref to create 1 or more STHs

=cut

sub prepare
{
	my $this = shift ;
	my ($prepare_href) = @_ ;
	
	if (ref($prepare_href) eq 'HASH')
	{
		foreach my $name (keys %$prepare_href)
		{
			# Just create each one
			$this->sth_create($name, $prepare_href->{$name});
		}
	}

	return undef ;
}

#----------------------------------------------------------------------------

=item C<Sql-E<gt>trace(@args)>

Change trace level

=cut

sub trace
{
	my $this = shift ;
	my (@args) = @_ ;

	# Update value
	my $trace = $this->SUPER::trace(@args) ;

	if (@args)
	{
		my $dbh = $this->dbh() ;
	#	my $trace = $this->trace() ;
		my $trace_file = $this->trace_file() ;
		
		# Update trace level
		$this->_set_trace($dbh, $trace, $trace_file) ;
	}
	
	return $trace ;
}

#----------------------------------------------------------------------------

=item C<Sql-E<gt>trace_file(@args)>

Change trace file

=cut

sub trace_file
{
	my $this = shift ;
	my (@args) = @_ ;
	
	# Update value
	my $trace_file = $this->SUPER::trace_file(@args) ;
	
	if (@args)
	{
		my $dbh = $this->dbh() ;
		my $trace = $this->trace() ;
	#	my $trace_file = $this->trace_file() ;
		
		# Update trace level
		$this->_set_trace($dbh, $trace, $trace_file) ;	
	}
	
	return $trace_file ;
}




#----------------------------------------------------------------------------

=item C<Sql-E<gt>connect(%args)>

Connects to database. Either uses pre-set values for user/password/database,
or can use optionally specified args

=cut

sub connect
{
	my $this = shift ;
	my (%args) = @_ ;

	$this->set(%args) ;

	print "Sql::connect() => ".$this->database()."\n" if $this->debug() ;

	my $dbh ;
	eval
	{
		# Disconnect if already connected
		$this->disconnect() ;
		
		# Connect
		$dbh = DBI->connect("DBI:mysql:database=".$this->database().";host=localhost",
					$this->user(), $this->password(),
					{'RaiseError' => 1}) or die $DBI::errstr ;
		$this->dbh($dbh) ;
		
		# Update trace level
#		my $trace = $this->trace() ;
#		my $trace_file = $this->trace_file() ;
#		$this->_set_trace($dbh, $trace, $trace_file) ;
	};
	if ($@)
	{
		$this->throw_fatal("SQL connect error: $@", 1000) ;
	}
	
	print " + connected dbh=$dbh : db=".$this->database()." user=".$this->user()." pass=".$this->password()."\n" if $this->debug() ;
	
	return $dbh ;
}

#----------------------------------------------------------------------------

=item C<Sql-E<gt>disconnect()>

Disconnect from database (if connected)

=cut

sub disconnect
{
	my $this = shift ;

	my $dbh = $this->dbh() ;

	print "Sql::disconnect() => dbh=$dbh\n" if $this->debug() ;

	eval
	{
		if ($dbh)
		{
## TODO: Work out why this causes problems! (Mysql server gone away)
##			$dbh->disconnect() ;	
			$this->dbh(0) ;
		}
	};
	if ($@)
	{
		$this->throw_fatal("SQL disconnect error: $@", 1000) ;
	}

	print " + disconnected\n" if $this->debug() ;
}


#----------------------------------------------------------------------------

=item C<Sql-E<gt>sth_create($name, $spec)>

Prepare a named SQL query & store it for later execution by query_sth()

Name is saved as $name. Certain names are 'special':

 ins*	- Create an 'insert' type command
 upd*	- Create an 'update' type command
 sel*	- Create a 'select' type command
 check* - Create a 'select' type command
 
The $spec is either a SCALAR or HASH ref 

If $spec is a SCALAR then it is in the form of sql. Note, when the query is executed the values
(if required) must be specified.

If $spec is a HASH ref then it can contain the following fields:

	'cmd'	=> Command type: 'insert', 'update', 'select'
	'vars'	=> ARRAY ref list of variable names (used for 'insert', 'update')
	'vals'	=> Provides values to be used in the query (no extra values need to be specified). HASH ref or ARRAY ref. 
	           HASH ref - the hash is used to look up the values using the 'vars' names
	           ARRAY ref - list of values (or refs to values)
	           NOTE: If insufficient values are provided for the query, then the remaining values must be specified in the query call
	'sql'  	=> Sql string.
			   NOTE: Depending on the command type, if the command is not specified then a default will be prepended to this string.
	'table'	=> Overrides the object table setting for this query
	'limit'	=> Sets the limit on the number of results
	'group'	=> Specify group by string
	'where'	=> Where clause. String or HASH ref.
			   String - specify sql for where clause (can omit 'WHERE' prefix)
			   HASH ref - specify where clause as HASH:  
					'sql' => Used to specify more complicated where clauses (e.g. '`pid`=? AND `channel`=?')
					'vars'	=> ARRAY ref list of variable names (used for 'where'). If no 'sql' is specified, then the where clause
							   is created by ANDing the vars together (e.g. [qw/pid channel/] gives '`pid`=? AND `channel`=?')
					'vals'	=> Provides values to be used in the query (no extra values need to be specified). HASH ref or ARRAY ref.

EXAMPLES

The following are all (almost) equivalent:

	$sql->sth_create('check',  {
					'table'	=> '$table',
					'limit'	=> 1,
					'where'	=> {
						'sql' => '`pid`=? AND `channel`=?',
						'vars'	=> [qw/pid channel/],
						'vals'	=> \%sql_vars
					}) ;

	$sql->sth_create('check2',  {
					'table'	=> '$table',
					'limit'	=> 1,
					'where'	=> '`pid`=? AND `channel`=?',# need to pass in extra params to query method
					}}) ;

	$sql->sth_create('check3',  "SELECT * FROM `$table` WHERE `pid`=? AND `channel`=? LIMIT 1") ;
	
	$sql->sth_create('select',  "WHERE `pid`=? AND `channel`=? LIMIT 1") ;

They are then used as:

	$sql->sth_query('check') ; # already given it's parameters
	$sql->sth_query('check2', $pid, $channel) ;
	$sql->sth_query('check3', $pid, $channel) ;
	$sql->sth_query('select', $pid, $channel) ;
			  

=cut

sub sth_create
{
	my $this = shift ;
	my ($name, $spec) = @_ ;
	
	my @vals ;
	
	## Set up vars
	my %vars = $this->vars() ;

	$vars{'sqlvar_select_varlist'} = '*' ;
	$vars{'sqlvar_query'} = $CMD_SQL{'query'}{'format'} ;
	$vars{'@sqlvar_query'} = $CMD_SQL{'query'}{'vals'} ;
	
	# Default table name
	$vars{'sqlvar_table'} = $vars{'table'} ;

print "sth_create($name)\n" if $this->debug()>=2 ;
	
	## Guess command based on name
	my $cmd = $this->_sql_cmd($name) ;

print " + cmd=$cmd\n" if $this->debug()>=2 ;
	
	## Handle hash
	if (ref($spec) eq 'HASH')
	{
		my %spec = (%{$spec}) ;
		
		# Set table if specified
		$vars{'sqlvar_table'} = delete $spec{'table'} if (exists($spec{'table'})) ; 

		# see if command specified
		$cmd = delete $spec{'cmd'} if (exists($spec{'cmd'})) ; 
		$cmd = lc $cmd ;

		# error check
		$this->throw_fatal("Error: No valid sql command") unless $cmd ;

		# Process spec - set vars
		$this->_sql_setvars($cmd, \%spec, \%vars) ;
	}
	elsif (!ref($spec))
	{
		# Process spec - set vars
		$this->_sql_setvars($cmd || 'query', $spec, \%vars) ;
	}

$this->prt_data("Vars=", \%vars) if $this->debug()>=2 ;

print "+ expand vars\n" if $this->debug()>=2 ;

	## Run through all vars and expand them
	$this->_sql_expand_vars(\%vars) ;

	## Run through all vars and expand arrays them
	$this->_sql_expand_arrays(\%vars) ;
	
	
	# query should now be in variable 'sqlvar_query'
	my $sql = $vars{'sqlvar_query'} ;

	# values should now be in variable '@sqlvar_query'
	my $values_aref = $vars{'@sqlvar_query'} ;

if ($this->debug())
{
	print "\n------------------------------------\n" ;
	print "PREPARE SQL($name): $sql\n----------\n" ;
	$this->prt_data("Values=", $values_aref) ;
}

#$this->prt_data("Values=", $values_aref, "\n--------------------\nVars=", \%vars) ;

	## Use given/created command sql
	my $dbh = $this->dbh() ;
	$this->throw_fatal("No database created", 1) unless $dbh ;
	
	my $sth ;
	eval
	{
		$sth = $dbh->prepare($sql) ;
	};
	$this->throw_fatal("STH prepare error $@\nQuery=$sql", 1) if $@ ;
	
	my $sth_href = $this->_sth() ;
	$sth_href->{$name} = {
		'sth' => $sth,
		'vals' => $values_aref,
		'query' => $sql,		# For debug
	} ;
	
}




#----------------------------------------------------------------------------

=item C<Sql-E<gt>sth_query($name, [@vals])>

Use a pre-prepared named sql query to return results. If the query has already been
given a set of values, then use them; otherwise use the values specified in this call
(or append the values to an insufficient list of values given when the sth was created)

=cut

sub sth_query
{
	my $this = shift ;
	my ($name, @vals) = @_ ;

	my $sth_href = $this->_sth_record($name) ;
	if ($sth_href)
	{
		my ($sth, $vals_aref, $query) = @$sth_href{qw/sth vals query/} ;

		# TODO: expand vars?
		my @args ;
		foreach my $arg (@$vals_aref)
		{
			## process each value			
			if (ref($arg) eq 'SCALAR')
			{
				## Ref to scalar
				push @args, $$arg ;
			}
			elsif (ref($arg) eq 'HASH')
			{
				## Special case handling where STH was created with an ARRAY ref or HASH ref
				if ($arg->{'type'} eq 'HASH')
				{
					## get latest value from hash ref
					push @args, $arg->{'hash'}{$arg->{'var'}} ;
				}
				elsif ($arg->{'type'} eq 'ARRAY')
				{
					## get latest value from array ref
					push @args, $arg->{'array'}[$arg->{'index'}] ;
				}
			}
			elsif (!ref($arg))
			{
				## Standard scalar
				push @args, $arg ;
			}
		}

		

		$this->prt_data("Sql::sth_query($query) : args=", \@args, "vals=", \@vals) if $this->debug()>=2 ;
		
		# execute
		eval
		{
			$sth->execute(@args, @vals) ;
		};
		if ($@)
		{
			my $vals = join(', ', @args, @vals) ;
			$this->throw_fatal("STH \"$name\"execute error $@\nQuery=$query\nValues=$vals", 1) if $@ ;
		}
	
#		print "Sql::sth_query($query) => sth=$sth\n" if $this->debug()>=2 ;
			
		# Save handle for later
#		$this->_result($sth) ;
	}

	return $this ;
}

#----------------------------------------------------------------------------

=item C<Sql-E<gt>sth_query_all($name, [@vals])>

Use a pre-prepared named sql query to return results. Return all results in array.

=cut

sub sth_query_all
{
	my $this = shift ;
	my ($name, @vals) = @_ ;

	my @results ;
	
	$this->sth_query($name, @vals) ;
	while(my $href = $this->next($name))
	{
		push @results, $href ;
	}
	
	return @results ;
}



#----------------------------------------------------------------------------

=item C<Sql-E<gt>query($query [, @vals])>

Query database

=cut

sub query
{
	my $this = shift ;
	my ($query, @vals) = @_ ;
	
	$this->sth_create($DEFAULT_STH_NAME, $query) ;
	$this->sth_query($DEFAULT_STH_NAME, @vals) ;

	return $this ;
}

#----------------------------------------------------------------------------

=item C<Sql-E<gt>query_all($query)>

Query database - return array of complete results, each entry is a hash ref

=cut

sub query_all
{
	my $this = shift ;
	my ($query, @vals) = @_ ;
	
	my @results ;
	
	$this->query($query, @vals) ;
	while(my $href = $this->next())
	{
		push @results, $href ;
	}
	
	return @results ;
}

#----------------------------------------------------------------------------

=item C<Sql-E<gt>do($sql)>

Do sql command

=cut

sub do
{
	my $this = shift ;
	my ($sql) = @_ ;
	
	my $dbh = $this->dbh() ;

	# Do query
	eval
	{
		$dbh->do($sql) ;
	};
	if ($@)
	{
		$this->throw_fatal("SQL do error $@\nSql=$sql", 1) if $@ ;
	}

	return $this ;
}

#----------------------------------------------------------------------------

=item C<Sql-E<gt>do_sql_text($sql_text)>

Process the SQL text, split it into one or more SQL command, then execute each of them

=cut

sub do_sql_text
{
	my $this = shift ;
	my ($sql_text) = @_ ;
	
	while ($sql_text =~ /([^;]*);/gm)
	{
		$this->do($1) ;
	}
	
	return $this ;
}

#----------------------------------------------------------------------------

=item C<Sql-E<gt>next([$name])>

Returns hash ref to next row (as a result of query). Uses prepared STH name $name
(as created by sth_create method), or default name (as created by query method)

=cut

sub next
{
	my $this = shift ;
	my ($name) = @_ ;
	
	# Get STH and get next row
	$name ||= $DEFAULT_STH_NAME ;
	my $sth = $this->_sth_record_sth($name) ;
	my $href = $sth->fetchrow_hashref() ;

	print "Sql::next() => sth=$sth : record=".$href."\n" if $this->debug() ;
	
	return $href ;

	
#	my $sth = $this->_result() ;
#
#	# Get row and save it
#	$this->_record($sth->fetchrow_hashref() || 0) ;
#
#	print "Sql::next() => sth=$sth : record=".$this->_record()."\n" if $this->debug() ;
#	
#	# return result
#	return ($this->_record() || undef) ;
}

#----------------------------------------------------------------------------

=item C<Sql-E<gt>tables()>

Returns list of tables for this database

=cut

sub tables
{
	my $this = shift ;
	
	# return result
	return $this->dbh()->tables() ;
}


#----------------------------------------------------------------------------

=item C<Sql-E<gt>datestr_to_sqldate($datestr)>

Convert standard date string (d-MMM-YYYY) to SQL based date (YYYY-MM-DD)
	
=cut

sub datestr_to_sqldate
{
	my $this = shift ;
	my ($datestr) = @_ ;

	my $sqldate ;

#print "datestr_to_sqldate($datestr)\n" ;
	
	if ($datestr =~ m/(\d{2})\-(\d{2})\-(\d{4})/)
	{
		$sqldate = "$3-$2-$1" ;
#print " + simple : date=$sqldate\n" ;
	}
	else
	{
		$datestr =~ s%-%/%g ;
		my $date = ParseDate($datestr) ;
		$sqldate = UnixDate($date, "%Y-%m-%d") ;
#print " + UnixDate : date=$sqldate\n" ;
	}
	
	return $sqldate ;
}


#----------------------------------------------------------------------------

=item C<Sql-E<gt>sqldate_to_date($sql_date)>

Convert SQL based date (YYYY-MM-DD) to standard date string (d-MMM-YYYY)
	
=cut

sub sqldate_to_date
{
	my $this = shift ;
	my ($sqldate) = @_ ;

	my $datestr ;

	if ($sqldate =~ m/(\d{4})\-(\d{2})\-(\d{2})/)
	{
		$datestr = "$3-$2-$1" ;
	}
	else
	{
		$sqldate =~ s%-%/%g ;
		my $date = ParseDate($sqldate) ;

		$datestr = UnixDate($date, "%d-%m-%Y") ;
		
	}

	return $datestr ;
}


#    /**
#     * query the database
#     *
#     * @param string $query the SQL query
#     * @param string $type the type of query
#     * @param string $format the query format
#     */
#    function query($query, $type = SQL_NONE, $format = SQL_ASSOC) 
#    {
#
#		$this->record = array();
#		$_data = array();
#        
#		// determine fetch mode (index or associative)
#        $_fetchmode = ($format == SQL_ASSOC) ? DB_FETCHMODE_ASSOC : null;
#        
#        $this->result = $this->db->query($query);
#        if (DB::isError($this->result)) {
#            $this->error = $this->result->getMessage();
#            $this->error .= "\nQuery: $query\n" ;
#            return false;
#        }
#        switch ($type) {
#            case SQL_ALL:
#				// get all the records
#                while($_row = $this->result->fetchRow($_fetchmode)) {
#                    $_data[] = $_row;   
#                }
#                $this->result->free();            
#                $this->record = $_data;
#                break;
#            case SQL_INIT:
#				// get the first record
#                $this->record = $this->result->fetchRow($_fetchmode);
#                break;
#            case SQL_NONE:
#            default:
#				// records will be looped over with next()
#                break;   
#        }
#        return true;
#    }
#    
#    /**
#     * Get next row
#     *
#     * @param string $format the query format
#     */
#    function next($format = SQL_ASSOC) 
#    {
#		// fetch mode (index or associative)
#        $_fetchmode = ($format == SQL_ASSOC) ? DB_FETCHMODE_ASSOC : null;
#        if ($this->record = $this->result->fetchRow($_fetchmode)) {
#            return $this->record;
#        } else {
#            $this->result->free();
#            return false;
#        }
#            
#    }
#    
#    /**
#     * Return full Sql error/warning message
#     *
#     */
#    function error_message() 
#    {
#//    	$message = '' ;
#//		$message .= "Sql Error:" . $this->db->getMessage() . "\n";
#//		$message .= "'Standard Code: " . $this->db->getCode() . "\n";
#//		$message .= "DBMS/User Message: " . $this->db->getUserInfo() . "\n";
#//		$message .= "DBMS/Debug Message: " . $this->db->getDebugInfo() . "\n";
#//		return $message ;
#return $this->error ;            
#    }
#
#	# Convert SQL based date (YYYY-MM-DD) to standard date string (d-MMM-YYYY)
#	function sqldate_to_datestr($sqldate)
#	{
#		list($year, $month, $day) = explode('-',$sqldate);
#
#// int mktime ( [int hour [, int minute [, int second [, int month [, int day [, int year [, int is_dst]]]]]]] )
#
#		$time = mktime(0,0,0,1*$month,1*$day,1*$year) ;
#		$datestr = date("d-M-Y", $time) ;
#	
#		return $datestr ;
#	}
#	
#	# Convert standard date string (d-MMM-YYYY) to SQL based date (YYYY-MM-DD)
#	function datestr_to_sqldate($datestr)
#	{
#		list($day, $month, $year) = explode('-',$datestr);
#		$time = mktime(0,0,0,$month,$day,$year) ;
#		$datestr = date("d-M-Y", $time) ;
#	
#		return $datestr ;
#	}
#	
#	
#	# Convert SQL based date (YYYY-MM-DD) to timestamp
#	function sqldate_to_date($sqldate)
#	{
#		return strtotime(sqldate_to_datestr($sqldate)) ;
#	}
#	
#	
#	# Convert SQL based time (HH:MM:SS) to standard time string (HH:MM)
#	function sqltime_to_timestr($sqltime)
#	{
#		list($hours, $mins, $secs) = explode(':',$sqltime);
#		return sprintf("%02d:%02d", $hours, $mins) ;
#	}




# ============================================================================================
# PRIVATE METHODS
# ============================================================================================


#----------------------------------------------------------------------------

=item C<Sql-E<gt>_sql_cmd($name)>

Convert $name into a sql command if possible

=cut

sub _sql_cmd
{
	my $this = shift ;
	my ($name) = @_ ;

	my $cmd ;
	foreach my $match (keys %CMDS)
	{
		if ($name =~ m/^$match/i)
		{
			$cmd = $CMDS{$match} ;
			last ;
		}
	}
	
	return $cmd ;
}

#----------------------------------------------------------------------------

=item C<Sql-E<gt>_sql_setvars($context, $spec, $vars_href)>

Set/add variables into the $vars_href HASH driven by the specification $spec (which may
be a sql string or a HASH specification). Creates the variables in the namespace defined by
the $context string (which is usually the lookup string into the %CMD_SQL table)

=cut

sub _sql_setvars
{
	my $this = shift ;
	my ($context, $spec, $vars_href) = @_ ;

print " > _sql_setvars($context)\n" if $this->debug()>=2 ;


	## Start by getting control info from %CMD_SQL if possible
	my $var = "sqlvar_${context}" ;
	my ($format, $prefix) ;
	if (exists($CMD_SQL{$context}))
	{
		## Get default sql string
		$format = $CMD_SQL{$context}{'format'} ;

		## Set variables
		$prefix = $CMD_SQL{$context}{'prefix'} if exists($CMD_SQL{$context}{'prefix'}) ;
		foreach my $name (qw/format prefix/)
		{
			$vars_href->{"${var}_$name"} = $CMD_SQL{$context}{$name} if exists($CMD_SQL{$context}{$name}) ; 
		}

		## Array
		$vars_href->{"\@${var}"} = $CMD_SQL{$context}{'vals'} if exists($CMD_SQL{$context}{'vals'}) ; 
	}

print " > + var=$var format=$format\n" if $this->debug()>=2 ;

	## Handle hash
	if (ref($spec) eq 'HASH')
	{
		## HASH
		my %spec = (%{$spec}) ;
		
		# Handle any vars
		my $vars_aref = [] ;
		if (exists($spec{'vars'}))
		{
			# create set of lists within this context namespace
			$vars_aref = delete $spec{'vars'} ;

			# TODO: error report

			if (ref($vars_aref) eq 'ARRAY')
			{
				# Supported lists:
				#setlist 	=> [SET] `var`=?, `var`=? ..
				#andlist	=> [WHERE] `var`=? AND `var`=? ..
				#varlist	=> [SELECT|ORDER BY] `var`, `var`
				my ($setlist, $andlist, $varlist) ;
				foreach my $var (@$vars_aref)
				{
					$setlist .= ', ' if $setlist ;
					$setlist .= "`$var`=?" ;

					$andlist .= ' AND ' if $andlist ;
					$andlist .= "`$var`=?" ;

					$varlist .= ', ' if $varlist ;
					$varlist .= "`$var`" ;
				}
				
				# Set vars
				$vars_href->{"${var}_setlist"} = $setlist ;
				$vars_href->{"${var}_andlist"} = $andlist ;
				$vars_href->{"${var}_varlist"} = $varlist ;
			}
		}
		
		# Handle any vals
		if (exists($spec{'vals'}))
		{
			# create set of lists within this context namespace
			my $vals_ref = delete $spec{'vals'} ;

			# TODO: error report

			## Array
			my $array_name = "\@${var}_vals" ;
			$vars_href->{$array_name} = [] ; 

print " > + + VALS : array=$array_name, vals_ref=$vals_ref\n" if $this->debug()>=2 ;


			if (ref($vals_ref) eq 'ARRAY')
			{
print " > + + + adding array\n" if $this->debug()>=2 ;
				foreach (my $idx=0; $idx < scalar(@$vals_ref); ++$idx)
				{
					## Store the HASH ref for ALL variables. Then, when we access the values, they will be the latest
					push @{$vars_href->{$array_name}}, {
						'type' 	=> 'ARRAY',
						'array'	=> $vals_ref,
						'index'	=> $idx,
					} ;
				}
			}
			elsif (ref($vals_ref) eq 'HASH')
			{
print " > + + + adding hash\n" if $this->debug()>=2 ;
				foreach my $var (@$vars_aref)
				{
print " > + + + + $var=$vars_href->{$var}\n" if $this->debug()>=2 ;
#					$vals_ref->{$var} ||= '' ;
#					push @{$vars_href->{$array_name}}, \$vals_ref->{$var} ; 

					## Store the HASH ref for ALL variables. Then, when we access the values, they will be the latest
					push @{$vars_href->{$array_name}}, {
						'type' 	=> 'HASH',
						'hash'	=> $vals_ref,
						'var'	=> $var,
					} ;
				}
			}
		}
		
		## If sql specified, use it
		if (exists($spec{'sql'}))
		{
			# create set of lists within this context namespace
			$format = delete $spec{'sql'} ;
		}

print " > + processing hash ...\n" if $this->debug()>=2 ;
#$this->prt_data("spec=", \%spec) ;
		
		## cycle through the other hash keys to produce other variables
		foreach my $var (keys %spec)
		{
print " > + + $var = $spec{$var}\n" if $this->debug()>=2 ;

			$this->_sql_setvars($var, $spec{$var}, $vars_href) ;
		}

#$this->prt_data("done hash : spec=", \%spec) ;
		
	}
	elsif (!ref($spec))
	{
		## String
		$format = $spec ;
		
print " > + spec is string : format=$format\n" if $this->debug()>=2 ;


	}

print " > Now: prefix=$prefix , format=$format\n" if $this->debug()>=2 ;


	## Ensure prefix is present
	if ($format && $prefix)
	{
		# Use prefix if necessary
		unless ($format =~ m/^\s*$context/i)
		{
print " > + + Adding prefix=$prefix to format=$format\n" if $this->debug()>=2 ;
			$format = "$prefix $format" ;
		}
	}

	# Set var
	$vars_href->{$var} = $format ;

print " > _sql_setvars($context) - END [format=$format]\n" if $this->debug()>=2 ;

}

#----------------------------------------------------------------------------

=item C<Sql-E<gt>_sql_expand_vars($vars_href)>

Expand all the variables in the HASH ref

=cut

sub _sql_expand_vars
{
	my $this = shift ;
	my ($vars_href) = @_ ;

print "_sql_expand_vars()\n" if $this->debug()>=2 ;
$this->prt_data("vars", \$vars_href) if $this->debug()>=2 ;


	# do all vars in HASH
	foreach my $var (keys %$vars_href)
	{
		# skip non SCALAR
		next if ref($vars_href->{$var}) ;

print " + $var\n" if $this->debug()>=2 ;
		
		# Keep replacing until all variables have been expanded
		my $ix = index $vars_href->{$var}, '$' ;
		while ($ix >= 0)
		{
print " + + ix=$ix : $var = $vars_href->{$var}\n" if $this->debug()>=2 ;


			# At least 1 more variable to replace, so replace it
			$vars_href->{$var} =~ s{
								     \$                         # find a literal dollar sign
								     \{{0,1}					# optional brace
								    (\w+)                       # find a "word" and store it in $1
								     \}{0,1}					# optional brace
									}{
									    if (defined $vars_href->{$1}) {
									        $vars_href->{$1};       # expand 
									    } else {
									        "";  					# remove
									    }
									}egx;

		$ix = index $vars_href->{$var}, '$' ;

print " + + + $var = $vars_href->{$var}\n" if $this->debug()>=2 ;
			
		}
	}

print "_sql_expand_vars - END\n" if $this->debug()>=2 ;

}

#----------------------------------------------------------------------------

=item C<Sql-E<gt>_sql_expand_arrays($vars_href)>

Expand all the array variables in the HASH ref

=cut

sub _sql_expand_arrays
{
	my $this = shift ;
	my ($vars_href) = @_ ;

print "_sql_expand_arrays()\n" if $this->debug()>=2 ;
$this->prt_data("vars", \$vars_href) if $this->debug()>=2 ;

	# do all vars in HASH
	foreach my $var (keys %$vars_href)
	{
print " + $var=$vars_href->{$var}\n" if $this->debug()>=2 ;

		# skip variables that aren't named @....
		next unless $var =~ /^\@/ ;
		
		# skip if already an array
		next if ref($vars_href->{$var}) eq 'ARRAY' ;

		# Expand it
		$this->_sql_expand_array($var, $vars_href) ;
	}

print "_sql_expand_arrays() - END\n" if $this->debug()>=2 ;

}

#----------------------------------------------------------------------------

=item C<Sql-E<gt>_sql_expand_array($arr, $vars_href)>

Expand the named array

=cut

sub _sql_expand_array
{
	my $this = shift ;
	my ($array, $vars_href) = @_ ;

print "_sql_expand_array($array)\n" if $this->debug()>=2 ;

	# skip if already an array
	unless (ref($vars_href->{$array}) eq 'ARRAY')
	{
		# split on commas
		my @arr_list = split(/[,\s+]/, $vars_href->{$array}) ;
		
		# start array off
		$vars_href->{$array} = [] ;

print " -- setting array\n" if $this->debug()>=2 ;

		# process them
		foreach my $arr (@arr_list)
		{
print " -- -- get $arr\n" if $this->debug()>=2 ;

			# if reference to another array, evaluate it
			if ($arr =~ /^\@/)
			{
print " -- -- -- expand $arr\n" if $this->debug()>=2 ;
				my $arr_aref = $this->_sql_expand_array($arr, $vars_href) ;
				
print " -- -- -- push array $arr=$arr_aref\n" if $this->debug()>=2 ;

				# Add to list
				push @{$vars_href->{$array}}, @$arr_aref ;
			}
			else
			{
print " -- -- -- push value $arr\n" if $this->debug()>=2 ;
				# Add to list
				push @{$vars_href->{$array}}, $arr ;
			}			
		}
		
	}

$this->prt_data("ARRAY $array=", $vars_href->{$array}) if $this->debug()>=2 ;
print "_sql_expand_array($array) - END\n" if $this->debug()>=2 ;

	return ($vars_href->{$array}) ;
}


#----------------------------------------------------------------------------

=item C<Sql-E<gt>_sth_record($name)>

Returns the saved sth information looked up from $name; returns undef otherwise

=cut

sub _sth_record
{
	my $this = shift ;
	my ($name) = @_ ;

	my $sth_href = $this->_sth() ;
	if (exists($sth_href->{$name}))
	{
		$sth_href = $sth_href->{$name} ;

		# error check
		$this->throw_fatal("Error: sth $name not created") unless $sth_href ;				

	}
	else
	{
		# error
		$this->throw_fatal("Error: sth $name not created") ;				
	}
		
	return $sth_href ;
}

#----------------------------------------------------------------------------

=item C<Sql-E<gt>_sth_record_sth($name)>

Returns the saved sth looked up from $name; returns undef otherwise

=cut

sub _sth_record_sth
{
	my $this = shift ;
	my ($name) = @_ ;

	my $sth ;
	my $sth_href = $this->_sth_record($name) ;
	
	if ($sth_href && exists($sth_href->{'sth'}))
	{
		$sth = $sth_href->{'sth'} ;

		# TODO: error
die "Error: sth $name not created" unless $sth ;				

	}
	else
	{
		# TODO: error
die "Error: sth $name not created" ;				
	}
		
	return $sth ;
}

#----------------------------------------------------------------------------

=item C<Sql-E<gt>_set_trace($dbh, $trace, $trace_file)>

Update trace level

=cut

sub _set_trace
{
	my $this = shift ;
	my ($dbh, $trace, $trace_file) = @_ ;
	
	if ($dbh)
	{
		$dbh->trace($trace, $trace_file)
	}
}

# ============================================================================================
# END OF PACKAGE
1;

__END__


