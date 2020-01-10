###########################################################################
##  $Header: $
##
##  Perl module to handle DB2 connections and queries.
##  $Author: putnam $
############################################################################
##
##  MODIFICATION HISTORY:
##  DATE        WHOM                DESCRIPTION
##	05/17/2012	Denis M. Putnam		Created.
##  $Log: $
############################################################################
package perllib::MyDB2;

use strict;
#use Exporter;
#use vars qw( @ISA @EXPORT );
#@ISA = qw(Exporter);
use DBI;
use DBD::DB2::Constants;
use DBD::DB2;
use perllib::Funcs;
use fields qw(
				debug 
				funcs_object 
				dbh 
				sid 
				user 
				trace_level 
				autocommit 
				STDOUTFLAG 
				err 
				COLUMN_NAMES 
				COLUMN_TYPES 
				COLUMN_TYPE_NAMES 
				COLUMN_TYPE_NAMES_HASH 
				TYPE_INFO
				);
use Data::Dumper;

sub new();
sub setStandardOutFlag($);
sub printMainHash();
sub printArray($$);
sub printHash($$);
sub closeMe();
sub logIt($);
sub debug(;$);
sub init($);
sub doQuery($$);
sub doUpdate($$);
sub getDBHandle();
sub getError();
sub commit($);
sub rollback($);
sub begin_work($);
sub getColumnNames();
sub getColumnTypeNames();
sub getColumnTypeInfo();
sub getColumnTypeName($);
sub getColumnTypes();

=head1 NAME

B<perllib::MyDB2> - Perl module to handle Oracle database connectivity
and queries.

 B<new()> - create an instance of this package.  Not exported.  B<USAGE:>
 my $myObject = new perllib::MyDB2(
                          'sid' => "databasename",
                          'user' => "user_name",
                          'pwd' => "password",
                          'trace_level' => 9,
                          'funcs_object' => $funcsObject
 );
 sid:           Database sid.
 user:          Database user name.
 pwd:           Database user password.
 trace_level:   DBI trace level.
 funcs_object:  An object previously created by the "new perllib::Funcs()"
 call.  See perllib::Funcs.

=cut

################################################################################
#   new()
#
#   DESCRIPTION:
#       Perl function to create an instance to this package.
#
#   USAGE:
#       my $myObject = new perllib::MyDB2(
#                                 'sid' => "databasename",
#                                 'user' => "me",
#                                 'pwd' => "XXXXX"
#                                 'autocommit' => 1,
#                                 'trace_level' => 9,
#                                 'funcs_object' => $funcsObject
#       );
#       sid:          database name.
#       user:         Db User ID.
#       pwd:          password.
#       autocommit:   set AutoCommit on or off.  Default is off.
#       trace_level:  trace_level.
#       funcs_object: Handle to the perllib::Funcs object.
#
#   RETURNS:
#       A reference to this package.
################################################################################
sub new()
{
	#my perllib::MyDB2 $myPackage	= shift;   	# Me.
	#my( $self ) 					= {@_};   	# Stores all the keys and values passed to this function.
	my perllib::MyDB2 $self			= shift;    # Me.
	$self							= fields::new( $self ) unless ref $self;
	my( $opts )						= {@_};		# Stores all the keys and values passed to this function.

	#################################################
	#   Set the local variables to the args.
	#################################################
	my $myFuncs 			= $opts->{funcs_object};
	my $sid					= $opts->{sid};
	my $user				= $opts->{user};
	my $autocommit			= $opts->{autocommit};
	my $pwd					= delete( $opts->{pwd} );
	$self->{debug}			= $myFuncs->{DEBUG};
	$self->{funcs_object}	= delete( $opts->{funcs_object} );
	$self->{sid}			= delete( $opts->{sid} );
	$self->{user}			= delete( $opts->{user} );
	$self->{trace_level}	= delete( $opts->{trace_level} );
	$self->{autocommit}		= delete( $opts->{autocommit} );
	my $args				= delete( $opts->{args} ) || [];

	##########################################
	#	If there are any keys left in the
	#	opts hash, then we were called with
	#	an illegal argument.
	##########################################
	#die( "Unknown arguments" ) if keys( %{$opts} ); 
	if( keys( %{$opts} ) )
	{
		print ref( $self ) . "::new(): Illegal arguments.\n";
		return undef;
	}
	if( !defined($sid) or ( $sid eq "" ) )
	{
		print ref( $self ) . "::new(): You must specify the sid.\n";
		return undef;
	}
	if( !defined($user) or ( $user eq "" ) )
	{
		print ref( $self ) . "::new(): You must specify the user.\n";
		return undef;
	}
	if( !defined($pwd) or ( $pwd eq "" ) )
	{
		print ref( $self ) . "::new(): You must specify the pwd.\n";
		return undef;
	}
	if( !defined($autocommit) or ( $autocommit eq "" ) )
	{
		$self->{autocommit} = 0;
	}
	else
	{
		$self->{autocommit} = $autocommit;
	}
	if( !defined($myFuncs) or ( $myFuncs eq "" ) )
	{
		print ref( $self ) . "::new(): You must specify the funcs_object.\n";
		return undef;
	}
	if( ref( $myFuncs ) ne "perllib::Funcs"  )
	{
		print ref( $self ) . "::new(): myFuncs is type " . ref( $myFuncs ) . "\n";
		print ref( $self ) . "::new(): You must specify the funcs_object. of type perllib::Funcs\n";
		return undef;
	}
	$self->{funcs_object}->debug( ref( $self ) . ":" . Dumper( $self ) );
	#bless $self, $myPackage;

	#########################################
	#	Perform any initializtion.
	#########################################
	my $rc = $self->init($pwd);
	return undef if( $rc == 0 );

	#	Return the handle to this object.
	return $self;
}

=head2
    B<closeMe()>

	Closes this instance.

=cut

###############################################################################
#   closeMe()
#
#   DESCRIPTION:
#       Closes this instance.
#
#   PARAMETERS:
#       None.
#
#   RETURN(S):
#       Nothing.
###############################################################################
sub closeMe()
{
	my perllib::MyDB2 $self = shift;
	$self->{dbh}->disconnect();
	$self = undef;
}

=head2
    B<printHash($name,$href)> 
	
	Logs the given hash to the log.
	B<PARAMETERS:> 
		$name is a string containing a name.  
		$href is the hash the you wish to log.

=cut

###############################################################################
#   printHash()
#
#   DESCRIPTION:
#       Print the Hash information.
#
#	PARAMETERS:
#		$hashName
#		\%theHash
#
#   RETURN(S):
#		Nothing.
###############################################################################
sub printHash($$)
{
	my perllib::MyDB2 $self	= shift;
	my( $name, $href )			= @_;

	return if( !defined( $name ) );

	$self->{'funcs_object'}->logHash( $name, $href );
}

=head2
    B<setStandardOutFlag($flag)>

	Set flag indicator for standard output.  Default behavior
	is determined by B<funcs_object> object and how it was instantiated.  By default 
	output only gets written to the log file.  Turning this on will make this 
	module do both.  Not exported.  
	B<PARAMETERS:> 
		$flag - either 0 or 1.

=cut

###############################################################################
#   setStandardOutFlag()
#
#   DESCRIPTION:
#       Set the STDOUTFLAG.
#
#   PARAMETERS:
#       $flag -- either 0 or 1.
#
#   RETURN(S):
#       Nothing.
###############################################################################
sub setStandardOutFlag($)
{
	my perllib::MyDB2 $self = shift;
	my($flag)				= @_;
	$self->{'STDOUTFLAG'}	= $flag;
	$self->{funcs_object}->setStandardOutFlag($flag);
}

=head2
    B<printArray($name,$aref)>
	
	Logs the given array to the log with the given name.
	B<PARAMETERS:> 
		$name is a string containing a name.  
		$aref is the array that you wish
to log.

=cut

################################################################################
#
#   printArray()
#
#   DESCRIPTION:
#       Prints an array.
#
#   RETURN(S):
#       Nothing.
################################################################################
sub printArray($$)
{
	my perllib::MyDB2 $self	= shift;
	my( $name, $aref )			= @_;

	$self->{'funcs_object'}->printArray( $name, $aref );
}

=head2
    B<printMainHash()>
	
	Logs the hash for this object.

=cut

################################################################################
#
#   printMainHash()
#
#   DESCRIPTION:
#       Logs the hash for this program.
#
#   RETURN(S):
#       Nothing.
################################################################################
sub printMainHash()
{
	my perllib::MyDB2 $self	= shift;
	my $name					= ref( $self );

	$self->printHash( $name, $self );
}

=head2
    B<logIt($msg)>
	
	Perl function to print and log the given message.  
	B<PARAMETERS:>
		$msg - message to be printed and logged.

=cut

################################################################################
#   logIt()
#
#   DESCRIPTION:
#       Perl function to print and log the given msg.
#
#   PARAMETERS:
#       $msg    -- String to be printed
#
#   RETURNS:
#       Nothing.
################################################################################
sub logIt($)
{
	my perllib::MyDB2 $self	= shift;
	my($msg)				= @_;

	$self->{'funcs_object'}->logIt($msg);
}

=head2
    B<debug($msg)>
	
	Perl function to print and log the given message if debugging is
	turned on.  
	B<PARAMETERS:> 
		$msg - message to be printed and logged.

=cut

################################################################################
#   debug()
#
#   DESCRIPTION:
#       Perl function to print and log the given msg for debug purposes.
#
#   PARAMETERS:
#       $msg    -- String to be printed
# 
#   RETURNS: 
#       Nothing.
################################################################################
sub debug(;$)
{
	my perllib::MyDB2 $self	= shift;
	my( $msg )				= @_;

	$self->{'funcs_object'}->debug($msg);
}
################################################################################
#   init()
#
#   DESCRIPTION:
#       Initialize this object.
#
#   PARAMETERS:
#		$pwd
# 
#   RETURNS: 
#       1 for success or zero.
################################################################################
sub init($)
{
	my perllib::MyDB2 $self	= shift;
	my( $pwd )				= @_;
	#my $host				= $self->{host};
	my $sid					= $self->{sid};
	my $user				= $self->{user};
	#my $port				= $self->{port};
	my $logFile				= $self->{funcs_object}->getLogFileName();
	$self->{err}			= "";
	DBI->trace( $self->{trace_level}, $logFile ) if( $self->{trace_level} && $self->{trace_level} > 0 );

	##############################################################################
	#my $string = "dbi:DB2:DATABASE=$db; HOSTNAME=$hostname; PORT=$port; PROTOCOL=TCPIP; UID=$user; PWD=$pass;";
	#my $dbh = DBI->connect($string, $user, $pass) || die "Connection failed with error: $DBI::errstr";

	#my $dsn = "dbi:DB2:" . $sid . "; HOSTNAME=" . $host . "; PORT=" . $port . "; PROTOCOL=TCPIP" . "; UID=" . $user . "; PWD=" . $pwd;
	#my $dsn = "dbi:DB2:DATABASE=" . $sid . "; HOSTNAME=" . $host . "; PORT=" . $port . "; PROTOCOL=TCPIP";
	#my $dsn = "dbi:DB2:" . $sid . "; HOSTNAME=" . $host . "; PORT=" . $port;
	##############################################################################

	my $dsn = "dbi:DB2:" . $sid;
	$self->logIt( ref( $self ) . "::init(): $dsn=$dsn\n" );
	my $rc = 1;
	if( $self->{dbh} = DBI->connect( $dsn, $user, $pwd, { RaiseError => 1, AutoCommit => $self->{autocommit}, PrintError => 0 } ) )
	{
		$self->logIt( ref( $self ) . "::init(): $dsn connected successfully.\n" );
		# set up $dbh->{HandleError} = sub{...};
		#my $previous_handler = $dbh->{HandleError};
		$self->{dbh}->{HandleError} = sub{
			#return 1 if( $previous_handler and &$previous_handler(@_) );
			my $msg		= $_[0];
			my $err		= $_[1]->err;
			my $errstr	= $_[1]->errstr;
			my $state	= $_[1]->state;
			$self->logIt( ref( $self ) . ": $msg:$err:$errstr:$state\n" );
		};
	}
	else
	{
		$self->logIt( ref( $self ) . "::init(): Unable to connect to $dsn:$DBI::errstr\n" );
		undef( $self->{dbh} ); 
		return 0;
	}

	$self->logIt( ref( $self ) . "::init(): " . Dumper( @{ $DBI::EXPORT_TAGS{sql_types} } ) . "\n" );
	################################################################
	#	This will be update as more is learned about the DB2 types.
	################################################################
	$self->{COLUMN_TYPE_NAMES_HASH}->{1}	= "SQL_CHAR";
	$self->{COLUMN_TYPE_NAMES_HASH}->{12}	= "SQL_VARCHAR";
	$self->{COLUMN_TYPE_NAMES_HASH}->{4}	= "SQL_INTEGER";
	$self->{COLUMN_TYPE_NAMES_HASH}->{8}	= "SQL_DOUBLE";
	$self->{COLUMN_TYPE_NAMES_HASH}->{3}	= "SQL_DECIMAL";
	$self->{COLUMN_TYPE_NAMES_HASH}->{91}	= "SQL_DATE";
	$self->{COLUMN_TYPE_NAMES_HASH}->{93}	= "SQL_TIMESTAMP";
	$self->{COLUMN_TYPE_NAMES_HASH}->{-99}	= "SQL_CLOB";
	return $rc;
}

=head2
    B<commit($)>
	
	Perform the commit on the database.
	B<PARAMETERS:> 
		$caller - is a string containing the name of the caller.
	B<RETURN:> Nothing.

=cut

################################################################################
#   commit()
#
#   DESCRIPTION:
#       Commit the transaction to the database.
#
#   PARAMETERS:
#		$caller
# 
#   RETURNS: 
#       Nothing.
################################################################################
sub commit($)
{
	my perllib::MyDB2 $self= shift;
	my( $caller )	= @_;
	$self->{err}	= "";
	$self->{dbh}->commit() or $self->logIt( ref( $self ) . "::commit(): $caller failed.  " . $self->{err}=$self->{dbh}->errstr() . "\n" ) ;
}

=head2
    B<rollback($)>
	
	Perform the rollback on the database.
	B<PARAMETERS:> 
		$caller - is a string containing the name of the caller.
	B<RETURN:> Nothing.

=cut

################################################################################
#   rollback()
#
#   DESCRIPTION:
#       Rollback the transaction to the database.
#
#   PARAMETERS:
#		$caller
# 
#   RETURNS: 
#       Nothing.
################################################################################
sub rollback($)
{
	my perllib::MyDB2 $self= shift;
	my( $caller ) 	= @_;
	$self->{err}	= "";
	$self->{dbh}->rollback() or $self->logIt( ref( $self ) . "::rollback(): $caller failed.  " . $self->{err}=$self->{dbh}->errstr() . "\n" ) ;
}

=head2
    B<begin_work($)>
	
	Start the transaction to the database.
	B<PARAMETERS:> 
		$caller - is a string containing the name of the caller.
	B<RETURN:> Nothing.

=cut

################################################################################
#   begin_work()
#
#   DESCRIPTION:
#       Start the transaction to the database.
#
#   PARAMETERS:
#		$caller
# 
#   RETURNS: 
#       Nothing.
################################################################################
sub begin_work($)
{
	my perllib::MyDB2 $self= shift;
	my( $caller )	= @_;
	$self->{err}	= "";
	$self->{dbh}->begin_work() or $self->logIt( ref( $self ) . "::begin_work(): $caller failed.  " . $self->{err}=$self->{dbh}->errstr() . "\n" ) ;
}

=head2
    B<getColumnNames()> 
	
	Get the column names from the last doQuery().
	B<PARAMETERS:> 
	B<RETURN:> 
		$aref of column names.

=cut

################################################################################
#   getColumnNames()
#
#   DESCRIPTION:
#       Get the column names from the last doQuery().
#
#   PARAMETERS:
# 
#   RETURNS: 
#       $aref of results.
################################################################################
sub getColumnNames()
{
	my perllib::MyDB2 $self= shift;
	return $self->{COLUMN_NAMES};
}

=head2
    B<getColumnTypeNames()> 
	
	Get the column type names from the last doQuery().
	B<PARAMETERS:> 
	B<RETURN:> 
		$aref of column type names.

=cut

################################################################################
#   getColumnTypeNames()
#
#   DESCRIPTION:
#       Get the column type names from the last doQuery().
#
#   PARAMETERS:
# 
#   RETURNS: 
#       $aref of results.
################################################################################
sub getColumnTypeNames()
{
	my perllib::MyDB2 $self= shift;
	return $self->{COLUMN_TYPE_NAMES};
}


=head2
    B<getColumnTypes()> 
	
	Get the column types from the last doQuery().
	B<PARAMETERS:> 
	B<RETURN:> 
		$aref of column type names.

=cut

################################################################################
#   getColumnTypes()
#
#   DESCRIPTION:
#       Get the column types from the last doQuery().
#
#   PARAMETERS:
# 
#   RETURNS: 
#       $aref of results.
################################################################################
sub getColumnTypes()
{
	my perllib::MyDB2 $self= shift;
	return $self->{COLUMN_TYPES};
}

=head2
    B<getColumnTypeInfo()> 
	
	Get the column type name for the given column name.
	B<PARAMETERS:> 
	B<RETURN:> 
		$aref of column type info.

=cut

################################################################################
#   getColumnTypeInfo()
#
#   DESCRIPTION:
#       Get the column type info from the last doQuery().
#
#   PARAMETERS:
# 
#   RETURNS: 
#       $aref of results.
################################################################################
sub getColumnTypeInfo()
{
	my perllib::MyDB2 $self= shift;
	return $self->{TYPE_INFO};
}

=head2
    B<getColumnTypeName($column_name)> 
	
	Get the column type name for the given column name.
	B<PARAMETERS:> 
		$name is a string containing a name.  
	B<RETURN:> 
		$columTypeName or undef

=cut

################################################################################
#   getColumnTypeName()
#
#   DESCRIPTION:
#       Get the column type names from the last doQuery().
#
#   PARAMETERS:
# 
#   RETURNS: 
#       $columnTypeName or undef
################################################################################
sub getColumnTypeName($)
{
	my perllib::MyDB2 $self	= shift;
	my( $columnName ) 			= @_;
	my $index					= 0;
	foreach my $colName ( @{$self->{COLUMN_NAMES}} )
	{
		last if( $colName eq $columnName );	
		$index++;
	}
	if( $index < scalar( @{$self->{COLUMN_NAMES}} ) )
	{
		return $self->{COLUMN_TYPE_NAMES}->[$index];
	}
	else
	{
		return undef;
	}
}

=head2
    B<doQuery($$)>
	
	Do the given query.
	B<PARAMETERS:> 
		$caller - is a string containing the name of the caller.
		$query - is a string containing the query.
	B<RETURN:> 
		@results

=cut

################################################################################
#   doQuery()
#
#   DESCRIPTION:
#       Do the given query.
#
#   PARAMETERS:
#		$caller
#		$queryString
# 
#   RETURNS: 
#       @results
################################################################################
sub doQuery($$)
{
	my perllib::MyDB2 $self	= shift;
	my( $caller, $query )	= @_;
	#my $aref				= [];
	my @rows;
	my $err					= "";
	my $sth;
	$self->{err}			= "";
	$self->debug( ref( $self ) . "::doQuery(): $caller [$query]\n" );
	eval
	{
		$sth = $self->{dbh}->prepare( $query ) or $self->{err}=$self->{dbh}->errstr();
	};
	if( $@ )
	{
		$self->{err} = ref( $self ) . "::doQuery()->prepare(): $caller failed.  " . $self->{err};
		$self->logIt( $self->{err} . "\n" );
		return @rows;
	}
	eval
	{
		my $rc	= $sth->execute() or $self->{err}=$sth->errstr();
		$self->{COLUMN_NAMES} = $sth->{NAME_uc};
		$self->debug( ref( $self ) . "::doQuery(): COLUMN_NAMES" . Dumper( $self->{COLUMN_NAMES} ) . "\n" );
		$self->{COLUMN_TYPES} = $sth->{TYPE};
		$self->debug( ref( $self ) . "::doQuery(): COLUMN_TYPES" . Dumper( $self->{COLUMN_TYPES} ) . "\n" );
		$self->debug( ref( $self ) . "::doQuery(): TYPES" . Dumper( \@{ $sth->{TYPE} } ) . "\n" );
		#my @columnTypeNames		= map{ scalar $self->{dbh}->type_info($_)->{TYPE_NAME} } @{ $sth->{TYPE} };
		my @columnTypeNames;
		foreach my $type ( @{ $sth->{TYPE} } )
		{
			push( @columnTypeNames, $self->{COLUMN_TYPE_NAMES_HASH}->{$type} );
		}
		$self->{COLUMN_TYPE_NAMES} = \@columnTypeNames;
		$self->debug( ref( $self ) . "::doQuery(): COLUMN_TYPE_NAMES" . Dumper( $self->{COLUMN_TYPE_NAMES} ) . "\n" );
		#my @type_info = $self->{dbh}->type_info();
		#$self->debug( ref( $self ) . "::doQuery(): type_info" . Dumper( \@type_info ) . "\n" );
		#$self->{TYPE_INFO} = \@type_info;
	};
	if( $@ )
	{
		$self->{err} = ref( $self ) . "::doQuery()->execute(): $caller failed.  " . $self->{err};
		$self->logIt( $self->{err} . "\n" );
		$sth->finish() if( defined( $sth ) );
		return @rows;
	}
	while( my @row = $sth->fetchrow_array() )
	{
		#push( @$aref, \@row );
		push( @rows, \@row );
	}
	$err = $sth->errstr() if( defined( $sth ) );
	if( $err )
	{
		$self->{err} = ref( $self ) . "::doQuery(): sth->fetchrow_array(): failed for [$query]:$err";
		$self->logIt( $self->{err} . "\n" );
	}
	$sth->finish() if( defined( $sth ) );
	#return $aref;
	return @rows;
}

=head2
    B<doUpdate($$)>
	
	Do the given update.
	B<PARAMETERS:> 
		$caller - is a string containing the name of the caller.
		$query - is a string containing the query.
	B<RETURN:> 
		$aref of results.

=cut

################################################################################
#   doUpdate()
#
#   DESCRIPTION:
#       Do the given update.
#
#   PARAMETERS:
#		$caller
#		$queryString
# 
#   RETURNS: 
#       >0 for success or 0.
################################################################################
sub doUpdate($$)
{
	my perllib::MyDB2 $self= shift;
	my( $caller, $query )	= @_;
	my $rc					= 0;
	my $err					= "";
	my $sth;
	$self->{err}			= "";
	$self->debug( ref( $self ) . "::doUpdate(): $caller [$query]\n" );
	eval
	{
		$sth = $self->{dbh}->prepare( $query ) or $self->{err}=$self->{dbh}->errstr();
	};
	if( $@ )
	{
		$self->{err} = ref( $self ) . "::doUpdate()->prepare(): $caller failed.  " . $self->{err};
		$self->logIt( $self->{err} . "\n" );
		return 0;
	}
	eval
	{
		$rc	= $sth->execute() or $self->{err}->$sth->errstr();
	};
	if( $@ )
	{
		$self->{err} = ref( $self ) . "::doUpdate()->execute(): $caller failed.  " . $self->{err};
		$self->logIt( $self->{err} . "\n" );
		$sth->finish() if( defined( $sth ) );
		return 0;
	}
	$rc = 0 if( !defined( $rc ) || $rc == -1 );
	$sth->finish() if( defined( $sth ) );
	$rc = 0 if( $err ne "" );
	return $rc;
}

=head2
    B<getError()>
	
	Get the latest error if any.
	B<PARAMETERS:> 
	B<RETURN:> 
		The result of the call to errstr().

=cut

################################################################################
#   getError()
#
#   DESCRIPTION:
#       Get the latest error if any.
#
#   PARAMETERS:
# 
#   RETURNS: 
#       The result of the call to errstr().
################################################################################
sub getError()
{
	my perllib::MyDB2 $self= shift;
	return $self->{err};
}

=head2
    B<getDBHandle()>
	
	Get the database handle
	B<PARAMETERS:> 
	B<RETURN:> 
		$dbh

=cut

################################################################################
#   getDBHandle()
#
#   DESCRIPTION:
#       Get the database handle.
#
#   PARAMETERS:
# 
#   RETURNS: 
#       $dbh
################################################################################
sub getDBHandle()
{
	my perllib::MyDB2 $self= shift;
	return $self->{dbh};
}
################################################################################
1;

__END__

=head1 SYNOPSIS

 use perllib::MyDB2;

 my $myObject = new perllib::MyDB2(
                          'sid' => "ORC",
                          'user' => "user_name",
                          'pwd' => "password",
                          'autocommit' => 1,
                          'trace_level' => 9,
                          'funcs_object' => $funcsObject
 );

 $myObject->setStandOutFlag(1);

 $myObject->logIt("Some log message\n");

 $myObject->debug("Some debug message\n");

 $myObject->printMainHash();

 $myObject->printArray( "my array", @myArray );

 $myObject->printHash( "my hash", %myHash );

 my $aref = $myObject->doQuery( "me", "select * from mytable" );

 my $rc = $myObject->doUpdate( "me", "update mytable set col=1 where col=2" );

 $myObject->closeMe();

=head1 DESCRIPTION

This module performs a connection to the given database via the Oracle data source.
Once connected the B<doQuery> and B<doUpdate> methods allow the user to perform
select and update queries.  The B<getDBHandle> method returns the underlying
connection handle to the caller so that the DBI methods are available
to the user if desired.

=head1 EXAMPLE

    use perllib::MyDB2;

    my $myObject = new perllib::MyDB2(
                          'sid' => "ORC",
                          'user' => "user_name",
                          'pwd' => "password",
                          'autocommit' => 1,
                          'trace_level' => 9,
                          'funcs_object' => $funcsObject
    );

    $myObject->printMainHash();
    my $line = "myvar=myvalue";
    my $aref = $myObject->doQuery( "me", "select * from mytable" );
    my $rc = $myObject->doUpdate( "me", "update mytable set col=1 where col=2" );
    $myObject->closeMe();

=head1 BUGS
 
None at the time of this writing.  May 17, 2012

=head1 AUTHOR

Denis M. Putnam, May 17, 2012.

=cut
