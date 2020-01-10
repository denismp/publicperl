###########################################################################
##  $Header: $
##
##  Perl module to deal with the attribute/value configuration file.
##  $Author: putnam $
############################################################################
##
##  MODIFICATION HISTORY:
##  DATE        WHOM                DESCRIPTION
##	06/27/2011	Denis M. Putnam		Created.
##  $Log: $
############################################################################
package perllib::MyConfig;

=head1 NAME

B<perllib::MyConfig> - A simple-to-use module to slurp the contents
of an attribute/value configuration file into memory.  The file is an attribute = value
format.


B<new()> - create an instance of this package.  Not exported.  B<USAGE:>
 my $myObject = new perllib::MyConfig(
                          'file' => "./MyConfig.cfg",
                          'funcs_object' => $funcsObject,
 );
 file:             The validation configuration file.
 funcs_object:     Handle to the perllib::Funcs object previously instantiated.

=cut

use strict;

use FileHandle;
use DirHandle;
use Cwd;
use Data::Dumper;
use perllib::Funcs;
use perllib::Command;
#use perllib::MyEncrypt;
use fields qw(
				file 
				KEYS
				MAPPINGS
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

sub getKeys();
sub getValue($);
sub getValues();
################################################################################
#   new()
#
#   DESCRIPTION:
#       Perl function to create an instance to this package.
#
#   USAGE:
#       my $myObject = new perllib::MyConfig(
#                                 'file' => "./MyConfig.cfg",
#                                 'funcs_object' => $funcsObject,
#       );
#       file:             config file.
#       funcs_object:     Handle to the perllib::Funcs object previously instantiated.
#
#   RETURNS:
#       A reference to this package.
################################################################################
sub new()
{
	my perllib::MyConfig $self	= shift;    # Me.
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
	my $file				= $opts->{file};
	$self->{debug}			= $myFuncs->{DEBUG};
	$self->{funcs_object}	= delete( $opts->{funcs_object} );
	$self->{file}			= delete( $opts->{file} );
	my $args				= delete( $opts->{args} ) || [];

	#die( "Unknown arguments" ) if keys( %{$opts} ); 
	##########################################
	#	If there are any keys left in the
	#	opts hash, then we were called with
	#	an illegal argument.
	##########################################
	if( keys( %{$opts} ) )
	{
		print "perllib::MyConfig::new(): Illegal arguments.\n";
		return undef;
	}
	if( !defined($file) or ( $file eq "" ) )
	{
		print ref( $self ) . "::new(): You must specify the file.\n";
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
	my perllib::MyConfig $self = shift;
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
	my perllib::MyConfig $self	= shift;
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
	my perllib::MyConfig $self = shift;
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
	my perllib::MyConfig $self	= shift;
	my( $name, $aref )					= @_;

	$self->{'funcs_object'}->printArray( $name, $aref );
}

=head2
    B<printMainHash()>
	
	Logs the MyConfig hash for this object.

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
	my perllib::MyConfig $self	= shift;
	my $name							= "perllib::MyConfig";

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
	my perllib::MyConfig $self	= shift;
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
	my perllib::MyConfig $self	= shift;
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
	my perllib::MyConfig $self	= shift;
	my $rc = 0;
	my @FILELIST;
	return 1 if( !$self );
	#my $encObject	= new perllib::MyEncrypt( funcs_object => $self->{funcs_object} );
	my $MyFH		= new FileHandle;
	if( -e $self->{file} )
	{
		my $myfile	= $self->{file};
		if( $MyFH->open( "<$myfile" ) )
		{
			my $line;
			while( $line = <$MyFH> )
			{
				chomp( $line );

				next if( $line =~ m/^#/ );		# Skip comments
				$line =~ s/\s*\=/\=/;			# Strip white space.
				$line =~ s/\=\s*/\=/;			# Strip white space.
				next if( $line eq "" );			# Skip blank lines.
				next if( $line !~ m/=/ );		# Skip lines with no '='.
				$self->debug( ref( $self ) . "::init(): $line\n" ); 
				my( $key, $value ) = split( "=", $line );
				#if( $key =~ m/PASSWORD/i )
				#{
					#$value = $encObject->decrypt( $value );
					#if( $encObject->getError() ne "" )
					#{
					#	$self->logIt( ref( $self ) . "::init(): Unable to decrypt $key\n" );
					#}
				#}

				push( @{$self->{KEYS}}, $key );		# Keep the attribute names as keys.
				$self->{MAPPINGS}{$key} = $value;	# Hash the value.
			}
			$MyFH->close();
			#$self->debug( ref( $self ) . "::init(): KEYS=" . Dumper( $self->{KEYS} ) . "\n" ); 
			#$self->debug( ref( $self ) . "::init(): MAPPINGS=" . Dumper( $self->{MAPPINGS} ) . "\n" ); 
		}
		else
		{
			$self->logIt( ref( $self ) . "::init(): Failed to open $myfile:$!\n" );
			return 1;
		}
	}
	else
	{
		$self->logIt( ref( $self ) . "::init(): " . $self->{file} . " doesn't exist.\n" );
		return 2;
	}
	return $rc;
}

=head2
    B<getKeys()>
	
	Get the keys.
	B<PARAMETERS:> 
	B<RETURN:> 
		@keys - 

=cut

################################################################################
#   getKeys()
#
#   DESCRIPTION:
#		Get the keys.
#
#   PARAMETERS:
# 
#   RETURNS: 
#		@keys - 
################################################################################
sub getKeys()
{
	my perllib::MyConfig $self	= shift;
	return @{$self->{KEYS}}
}

=head2
    B<getValue($key)>
	
	Get the value for the given key.
	B<PARAMETERS:> 
        $key - Something like "CCB_DB_NAME"
	B<RETURN:> 
		$value

=cut

################################################################################
#   getValue()
#
#   DESCRIPTION:
#		Get the value for the given key.
#
#   PARAMETERS:
#		$key - Something like "CCB_DB_NAME"
# 
#   RETURNS: 
#		$value
################################################################################
sub getValue($)
{
	my perllib::MyConfig $self	= shift;
	my( $key )							= @_;
	
	#$self->debug( ref( $self ) . "::getValue(): key=" . $key . "\n" ); 
	my $value = $self->{MAPPINGS}{$key};
	#$self->debug( ref( $self ) . "::getValue(): value=" . $value . "\n" ); 
	return $value;	
}

=head2
    B<getValues()>
	
	Get all the records.
	B<PARAMETERS:> 
	B<RETURN:> 
		@records - [[$fileName, $processFlow, $description],[...]]

=cut

################################################################################
#   getValues()
#
#   DESCRIPTION:
#		Get all the values.
#
#   PARAMETERS:
# 
#   RETURNS: 
#		@records - [[$key, $value],[...]]
################################################################################
sub getValues()
{
	my perllib::MyConfig $self	= shift;
	my @records;

	foreach my $key ( @{$self->{KEYS}} )
	{
		my @row = $self->getValues( $key );
		#$self->debug( ref( $self ) . "::getValues(): row=" . Dumper( \@row ) . "\n" ); 

		push( @records, @row );
	}
	return @records;	
}
################################################################################
1;

__END__


=head1 SYNOPSIS

 use perllib::MyConfig;

 my $myObject = new perllib::MyConfig(
                          'file' => "./MyConfig.cfg",
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

This module manages the given B<file> for processing.
 Sample parameter file:  If the line is blank or begins with #; it will be ignored
 #-------------- beginning of file -----------
 # database connection values
 DRIVER               = Oracle

 CCB_DB_NAME          = CCBP
 CCB_DB_USERNAME      = CISREAD
 CCB_DB_PASSWORD      = pwd

 OUBI_DB_NAME         = OUBIP
 OUBI_DB_USERNAME     = CISBGE
 OUBI_DB_PASSWORD     = pwd

 #-----------------------------------

=head1 EXAMPLE

    use Data::Dumper;
    use perllib::MyConfig;

    ##########################################
    #    Get an instance of the MyConfig.
    ##########################################
    my $myObject = new perllib::MyConfig(
                        'file' => "./MyConfig.cfg",
                        funcs_object => $CONFIG{funcs},
                        );
    if( $myObject )
    {
        $myObject->closeMe();
        $rc = $lrc ? 0 : 1;
    }

=head1 BUGS
 
None at the time of this writing.  June 27, 2011

=head1 AUTHOR

Denis M. Putnam, June 27, 2011.

=cut
