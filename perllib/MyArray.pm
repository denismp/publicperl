###########################################################################
##  $Header: $
##
##  Perl module to deal with the ETL Validation file.
##  $Author: putnam $
############################################################################
##
##  MODIFICATION HISTORY:
##  DATE        WHOM                DESCRIPTION
##	06/27/2011	Denis M. Putnam		Created.
##  $Log: $
############################################################################
package perllib::MyArray;

=head1 NAME

B<perllib::MyArray> - A simple-to-use module to slurp the contents
of a ETL validation file into memory.  The file is an attribute = value
format.


B<new()> - create an instance of this package.  Not exported.  B<USAGE:>
 my $myObject = new perllib::MyArray(
                          'funcs_object' => $funcsObject,
 );
 funcs_object:     Handle to the perllib::Funcs object previously instantiated.

=cut

use strict;

use FileHandle;
use DirHandle;
use Cwd;
use Data::Dumper;
use perllib::Funcs;
use perllib::Command;
use fields qw(
				debug 
				funcs_object 
				STDOUTFLAG 
				);

########################################
#	Prototypes.
########################################
sub new();
sub setStandardOutFlag($);
sub printMainHash();
sub printArray($$);
sub printHash($$);
sub closeMe();
sub logIt($);
sub debug(;$);
sub init();

sub mergeArrays($$);
sub deDup($);
sub outerJoin($$$);
sub sortArray($$);
################################################################################
#   new()
#
#   DESCRIPTION:
#       Perl function to create an instance to this package.
#
#   USAGE:
#       my $myObject = new perllib::MyArray(
#                                 'funcs_object' => $funcsObject,
#       );
#       funcs_object:     Handle to the perllib::Funcs object previously instantiated.
#
#   RETURNS:
#       A reference to this package.
################################################################################
sub new()
{
	my perllib::MyArray $self	= shift;    # Me.
	#$self 							= $self->SUPER::new( @_ );
	my( $opts )						= {@_};		# Stores all the keys and values passed to this function.
	############################################################
	#	Uncomment this and modify for inheritence.
	#$self 							= $self->SUPER::new( 
	#													'xml_file' => $opts->{xml_file},
	#													'xml_string' => $opts->{xml_string},
	#													'funcs_object' => $opts->{funcs_object}
	#													);
	############################################################
	return undef if( !defined( $self ) );
	$self							= fields::new( $self ) unless ref $self;

	#################################################
	#   Set the local variables to the args.
	#################################################
	my $myFuncs 			= $opts->{funcs_object};
	$self->{debug}			= $myFuncs->{DEBUG};
	$self->{funcs_object}	= delete( $opts->{funcs_object} );
	my $args				= delete( $opts->{args} ) || [];

	#die( "Unknown arguments" ) if keys( %{$opts} ); 
	##########################################
	#	If there are any keys left in the
	#	opts hash, then we were called with
	#	an illegal argument.
	##########################################
	if( keys( %{$opts} ) )
	{
		print "perllib::MyArray::new(): Illegal arguments.\n";
		return undef;
	}
	if( !defined($myFuncs) or ( $myFuncs eq "" ) )
	{
		print ref( $self ) . "::new(): You must specify the funcs_object.\n";
		return undef;
	}
	if( ref( $myFuncs ) ne "perllib::Funcs"  )
	{
		print ref( $self ) . "::New(): myFuncs is type " . ref( $myFuncs ) . "\n";
		print ref( $self ) . "::new(): You must specify the funcs_object. of type perllib::Funcs\n";
		return undef;
	}
	#$self->{funcs_object}->debug( ref( $self ) . ":" . Dumper( $self ) );

	##################################
	#	Perform any initialization.
	##################################
	my $rc = $self->init();
	#my $rc = $self->SUPER::init();
	return undef if( $rc );

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
	my perllib::MyArray $self = shift;
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
	my perllib::MyArray $self	= shift;
	my( $name, $href )					= @_;

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
	my perllib::MyArray $self = shift;
	my($flag)								= @_;
	$self->{'STDOUTFLAG'}					= $flag;
	$self->{funcs_object}->setStandardOutFlag($flag);
	$self->SUPER->{'STDOUTFLAG'} 			= $flag;
	$self->SUPER->{funcs_object}->setStandardOutFlag($flag);
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
	my perllib::MyArray $self	= shift;
	my( $name, $aref )					= @_;

	$self->{'funcs_object'}->printArray( $name, $aref );
}

=head2
    B<printMainHash()>
	
	Logs the MyArray hash for this object.

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
	my perllib::MyArray $self	= shift;
	my $name							= "perllib::MyArray";

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
	my perllib::MyArray $self	= shift;
	my($msg)							= @_;

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
	my perllib::MyArray $self	= shift;
	my( $msg )							= @_;

	$self->{'funcs_object'}->debug($msg);
}

################################################################################
#   init()
#
#   DESCRIPTION:
#       Initialize this object from the test file.
#
#   PARAMETERS:
# 
#   RETURNS: 
#       0 for success or non-zero otherwise.
################################################################################
sub init()
{
	my perllib::MyArray $self	= shift;
	my $rc = 0;
	return 1 if( !$self );
	return $rc;
}

=head2
    B<sortArray()>
	
	Sort the given array on the given columns.
	B<PARAMETERS:> 
		$aref  - first array reference.
		$ckeys - something like "1,5,3". 
	B<RETURN:> 
		@sorted

=cut

################################################################################
#   sortArray()
#
#   DESCRIPTION:
#		Sort the given array on the given columns.
#
#   PARAMETERS:
#		$aref - first array reference.
#		$ckeys - something like "0,5,3".
# 
#   RETURNS: 
#		( $ar1, $ar2 )
################################################################################
sub sortArray($$)
{
	my perllib::MyArray $self		= shift;
	my( $aref, $ckeys )				= @_;
	my @aKeys						= split( ",", $ckeys );
	my $numKeys						= scalar( @aKeys );
	my %h1;
	my @ar1;

	#####################################
	#	Build the hash for h1 from aref
	#####################################
	foreach my $rec ( @{$aref} )
	{
		my $sKey = "";
		foreach my $myKey ( @aKeys )
		{
			$myKey =~ s/\s*//g;
			my $tKey = $rec->[$myKey];
			$tKey =~ s/\s*//g;

			$sKey .= $rec->[$myKey] . "|";	
		}
		$sKey =~ s/\|$//;
		$h1{ $sKey } = $rec;
	}

	#####################################
	#	Build the return array.
	#####################################
	foreach my $hkey ( sort keys %h1 )
	{
		push( @ar1, $h1{ $hkey } );
	}
	return @ar1;
}

=head2
    B<outerJoin()>
	
	Perform an outer join on two arrays.
	B<PARAMETERS:> 
		$aref1 - first array reference.
		$aref2 - second array reference.
		$ckeys - something like "1,5,3".  Columns to join over.
	B<RETURN:> 
		( $aref1, $aref2 )

=cut

################################################################################
#   outerJoin()
#
#   DESCRIPTION:
#		Perform an outer join on two arrays.
#
#   PARAMETERS:
#		$aref1 - first array reference.
#		$aref2 - second array reference.
#		$ckeys - something like "0,5,3".  Columns to join over.
# 
#   RETURNS: 
#		( $ar1, $ar2 )
################################################################################
sub outerJoin($$$)
{
	my perllib::MyArray $self		= shift;
	my( $aref1, $aref2, $ckeys )	= @_;
	my @aKeys						= split( ",", $ckeys );
	my $numKeys						= scalar( @aKeys );
	my %h1;
	my %h2;
	my @ar1;
	my @ar2;

	#####################################
	#	Build the hash for h1 from aref1
	#####################################
	foreach my $rec ( @{$aref1} )
	{
		my $sKey = "";
		foreach my $myKey ( @aKeys )
		{
			$myKey =~ s/\s*//g;
			my $tKey = $rec->[$myKey];
			$tKey =~ s/\s*//g;

			$sKey .= $rec->[$myKey] . "|";	
		}
		$sKey =~ s/\|$//;
		$h1{ $sKey } = $rec;
	}
	#####################################
	#	Build the hash for h2 from aref2
	#####################################
	foreach my $rec ( @{$aref2} )
	{
		my $sKey = "";
		foreach my $myKey ( @aKeys )
		{
			$myKey =~ s/\s*//g;
			my $tKey = $rec->[$myKey];
			$tKey =~ s/\s*//g;

			$sKey .= $rec->[$myKey] . "|";	
		}
		$sKey =~ s/\|$//;
		$h2{ $sKey } = $rec;
	}

	############################################
	#	Check which hash is bigger.
	############################################
	if( scalar( keys %h1 ) >= scalar( keys %h2 ) )
	{
		############################
		#	hash 1 drives
		############################
		foreach my $hkey ( sort keys %h1 )
		{
			if( !defined( $h2{ $hkey } ) )
			{
				#################################
				#	Create the 'empty' rows.
				#################################
				my $haref = $h1{ $hkey };
				my @row;
				for( my $i = 0; $i < scalar( @{$haref} ); $i++ )
				{
					my $el	= $haref->[ $i ];
					push( @row, $el );
				}
				$h2{ $hkey } = \@row;
			}
		}
		#####################################
		#	Build the return arrays.
		#####################################
		foreach my $hkey ( sort keys %h1 )
		{
			push( @ar1, $h1{ $hkey } );
			push( @ar2, $h2{ $hkey } );
		}
	}
	else
	{
		############################
		#	hash 2 drives
		############################
		foreach my $hkey ( sort keys %h2 )
		{
			if( !defined( $h1{ $hkey } ) )
			{
				#################################
				#	Create the 'empty' rows.
				#################################
				my $haref = $h2{ $hkey };
				my @row;
				for( my $i = 0; $i < scalar( @{$haref} ); $i++ )
				{
					my $el	= $haref->[ $i ];
					push( @row, $el );
				}
				$h1{ $hkey } = \@row;
			}
		}
		#####################################
		#	Build the return arrays.
		#####################################
		foreach my $hkey ( sort keys %h2 )
		{
			push( @ar2, $h2{ $hkey } );
			push( @ar1, $h1{ $hkey } );
		}
	}
	return( \@ar1, \@ar2 );
}

=head2
    B<deDup()>
	
	Dedup the given array.
	B<PARAMETERS:> 
		$aref - array reference.
	B<RETURN:> 
		@array

=cut

################################################################################
#   deDup()
#
#   DESCRIPTION:
#		Dedup the given array.
#
#   PARAMETERS:
#		$aref	-- array reference.
# 
#   RETURNS: 
#		@array 
################################################################################
sub deDup($)
{
	my perllib::MyArray $self	= shift;
	my( $aref )					= @_;
	my @rList;
	my %wHash;
	foreach my $el ( @{$aref} )
	{
		my $string = join( '|', @{$el} );
		$wHash{ $string } = 1;
	}
	foreach my $myKey ( keys %wHash )
	{
		my @mylist = split( /\|/, $myKey );
		push( @rList, \@mylist  );
	}

	return @rList;
}

=head2
    B<mergeArrays()>
	
	Merge two arrays.
	B<PARAMETERS:> 
		$aref1 - first array reference.
		$aref2 - second array reference.
	B<RETURN:> 
		@array

=cut

################################################################################
#   mergeArrays()
#
#   DESCRIPTION:
#		Merge the given arrays.
#
#   PARAMETERS:
#		$aref1	-- first array reference.
#		$aref2	-- second array reference.
# 
#   RETURNS: 
#		@array 
################################################################################
sub mergeArrays($$)
{
	my perllib::MyArray $self	= shift;
	my( $aref1, $aref2 )		= @_;
	my @rList;
	foreach my $el ( @{$aref1} )
	{
		push( @rList, $el );
	}
	foreach my $el ( @{$aref2} )
	{
		push( @rList, $el );
	}
	@rList = $self->deDup( \@rList );
	return @rList;
}
################################################################################
1;

__END__


=head1 SYNOPSIS

 use perllib::MyArray;

 my $myObject = new perllib::MyArray(
                          'funcs_object' => $funcsObject,
 );

 $myObject->setStandOutFlag(1);

 $myObject->logIt("Some log message\n");

 $myObject->debug("Some debug message\n");

 $myObject->printMainHash();

 $myObject->printArray( "my array", @myArray );

 $myObject->printHash( "my hash", %myHash );

 $myObject->closeMe();

=head1 DESCRIPTION

This module manages the given B<ccb_mapping_file> for processing.

=head1 EXAMPLE

    use Data::Dumper;
    use perllib::MyArray;

    ##########################################
    #    Get an instance of the MyArray.
    ##########################################
    my $myObject = new perllib::MyArray(
                        funcs_object => $CONFIG{funcs},
                        );
    if( $myObject )
    {
        $myObject->closeMe();
        $rc = $lrc ? 0 : 1;
    }

=head1 BUGS
 
None at the time of this writing.  July 6, 2011

=head1 AUTHOR

Denis M. Putnam, July 6, 2011.

=cut
