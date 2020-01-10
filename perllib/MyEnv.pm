###########################################################################
##  $Header: $
##
##  Perl module to handle the system environment.
##  $Author: putnam $
############################################################################
##
##  MODIFICATION HISTORY:
##  DATE        WHOM                DESCRIPTION
##	05/23/2011	Denis M. Putnam		Created.
##  $Log: $
############################################################################
package perllib::MyEnv;

=head1 NAME

B<perllib::MyEnv> - A simple-to-use module to deal with environment variables.

B<new()> - create an instance of this package.  Not exported.  B<USAGE:>
 my $myObject = new perllib::MyEnv(
                          'funcs_object' => $funcsObject,
 );
 funcs_object:        Handle to the perllib::Funcs object previously instantiated.

=cut

use strict;

use FileHandle;
use DirHandle;
use Cwd;
use File::Copy;
use File::Path;
use File::Basename;
use Data::Dumper;
use perllib::Funcs;
use fields qw(
				debug 
				funcs_object 
				STDOUTFLAG 
				_ENV_
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
sub getEnvKeys();
sub logEnv();

################################################################################
#   new()
#
#   DESCRIPTION:
#       Perl function to create an instance to this package.
#
#   USAGE:
#       my $myObject = new perllib::MyEnv(
#                                 'funcs_object' => $funcsObject,
#       );
#       funcs_object:     Handle to the perllib::Funcs object previously instantiated.
#
#   RETURNS:
#       A reference to this package.
################################################################################
sub new()
{
	my perllib::MyEnv $self		= shift;    # Me.
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
		print "perllib::MyEnv::new(): Illegal arguments.\n";
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
	my perllib::MyEnv $self = shift;
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
	my perllib::MyEnv $self	= shift;
	my( $name, $href )		= @_;

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
	my perllib::MyEnv $self 				= shift;
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
	my perllib::MyEnv $self	= shift;
	my( $name, $aref )					= @_;

	$self->{'funcs_object'}->printArray( $name, $aref );
}

=head2
    B<printMainHash()>
	
	Logs the MyEnv hash for this object.

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
	my perllib::MyEnv $self	= shift;
	my $name							= "perllib::MyEnv";

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
	my perllib::MyEnv $self	= shift;
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
	my perllib::MyEnv $self	= shift;
	my( $msg )					= @_;

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
	my perllib::MyEnv $self	= shift;
	my $rc = 0;
	return 1 if( !$self );

	for my $env ( sort keys %ENV )
	{
		$self->{_ENV_}{$env} = $ENV{$env};
	}
	return $rc;
}

=head2
    B<getEnvKeys()>
	
	Get all the environment keys.
	B<PARAMETERS:> 

	B<RETURN:> 
		@keys

=cut

################################################################################
#   getEnvKeys()
#
#   DESCRIPTION:
#		Get all the environment keys.
#
#   PARAMETERS:
# 
#   RETURNS: 
#		@keys
################################################################################
sub getEnvKeys()
{
	my perllib::MyEnv $self	= shift;
	my @keys = sort %{$self->{_ENV_}};
	return @keys;
}

=head2
    B<logEnv()>
	
	Log the environment.
	B<PARAMETERS:> 

	B<RETURN:> 

=cut

################################################################################
#   logEnv()
#
#   DESCRIPTION:
#		Log the environment.
#
#   PARAMETERS:
# 
#   RETURNS: 
################################################################################
sub logEnv()
{
	my perllib::MyEnv $self	= shift;
	my @keys = sort %{$self->{_ENV_}};
	for my $env ( @keys )
	{
		$self->logIt( ref( $self ) . "::logEnv(): $env=" . $self->{_ENV_}{$env} . "\n" );
	}
}

=head2
    B<getValue($)>
	
	Get the environmental variable.
	B<PARAMETERS:> 
		$key - the name of the environmental variable.

	B<RETURN:> 
		$value

=cut

################################################################################
#   getValue()
#
#   DESCRIPTION:
#		Get the environmental variable.
#
#   PARAMETERS:
#		$key - the name of the environmental variable.
# 
#   RETURNS: 
#		$value
################################################################################
sub getValue($)
{
	my perllib::MyEnv $self	= shift;
	my( $key )				= @_;
	return $self->{_ENV_}{$key};
}

################################################################################
1;

__END__


=head1 SYNOPSIS

 use perllib::MyEnv;

 my $myObject = new perllib::MyEnv(
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

This module manages the given B<ccb_mappings_object> for processing.

=head1 EXAMPLE

    use Data::Dumper;
    use perllib::MyEnv;

    ##########################################
    #    Get an instance of the MyEnv.
    ##########################################
    my $myObject = new perllib::MyEnv(
                          'funcs_object' => $funcsObject,
    );
    if( $myObject )
    {
        $myObject->closeMe();
        $rc = $lrc ? 0 : 1;
    }

=head1 BUGS
 
None at the time of this writing.  May 23, 2011

=head1 AUTHOR

Denis M. Putnam, May 23, 2011.

=cut
