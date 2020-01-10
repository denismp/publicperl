###########################################################################
##  $Header: $
##
##  Perl module to deal with encryption.
##  $Author: putnam $
############################################################################
##
##  MODIFICATION HISTORY:
##  DATE        WHOM                DESCRIPTION
##	07/07/2011	Denis M. Putnam		Created.
##  $Log: $
############################################################################
package perllib::MyEncrypt;

=head1 NAME

B<perllib::MyEncrypt> - A simple-to-use module to perform encryption
and decryption.


B<new()> - create an instance of this package.  Not exported.  B<USAGE:>
 my $myObject = new perllib::MyEncrypt(
                          'funcs_object' => $funcsObject,
 );
 funcs_object:  Handle to the perllib::Funcs object previously instantiated.

=cut

use strict;

use FileHandle;
use DirHandle;
use Cwd;
use Data::Dumper;
use perllib::Funcs;
use perllib::Command;
use Crypt::CBC;
use fields qw(
				special
				handle
				err
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
sub encrypt($);
sub decrypt($);
sub getError();

################################################################################
#   new()
#
#   DESCRIPTION:
#       Perl function to create an instance to this package.
#
#   USAGE:
#       my $myObject = new perllib::MyEncrypt(
#                                 'funcs_object' => $funcsObject,
#       );
#       funcs_object:     Handle to the perllib::Funcs object previously instantiated.
#
#   RETURNS:
#       A reference to this package.
################################################################################
sub new()
{
	my perllib::MyEncrypt $self	= shift;    # Me.
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
		print "perllib::MyEncrypt::new(): Illegal arguments.\n";
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
	my perllib::MyEncrypt $self = shift;
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
	my perllib::MyEncrypt $self	= shift;
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
	my perllib::MyEncrypt $self = shift;
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
	my perllib::MyEncrypt $self	= shift;
	my( $name, $aref )					= @_;

	$self->{'funcs_object'}->printArray( $name, $aref );
}

=head2
    B<printMainHash()>
	
	Logs the MyEncrypt hash for this object.

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
	my perllib::MyEncrypt $self	= shift;
	my $name							= "perllib::MyEncrypt";

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
	my perllib::MyEncrypt $self	= shift;
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
	my perllib::MyEncrypt $self	= shift;
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
	my perllib::MyEncrypt $self	= shift;
	my $rc = 0;
	return 1 if( !$self );
	my $mySpecial		= "9319255386ABCDEF";
	$self->{special}	= pack( "H16", $mySpecial );
	$self->{handle}		= new Crypt::CBC( 
										-key			=> $self->{special},
										-cipher			=> 'Blowfish',
										-regenerate_key	=> 1,
										-pcbc			=> 1
										);
	return $rc;
}

=head2
    B<encrypt($plaintext)>
	
	Encrypt the given token.
	B<PARAMETERS:> 
		$plaintext - the thing to be encrypted.

=cut

################################################################################
#   encrypt()
#
#   DESCRIPTION:
# 		Encrypt the given token.
#
#   PARAMETERS:
#       $plaintext  -- The thing to be encrypted.
# 
#   RETURNS: 
#       $ciphertest
################################################################################
sub encrypt($)
{
	my perllib::MyEncrypt $self	= shift;
	my( $plaintext )			= @_;
	my $ciphertext				= $plaintext;
	$self->{err}				= "";

	eval
	{
		$ciphertext = $self->{handle}->encrypt_hex( $plaintext );
	};
	if( $@ )
	{
		$self->logIt( ref( $self ) . "::encrypt(): failed.\n" );
		$self->{err} =  ref( $self ) . "::encrypt(): failed.\n";
	}
	return $ciphertext;
}

=head2
    B<decrypt($ciphertext)>
	
	Encrypt the given token.
	B<PARAMETERS:> 
		$ciphertext - the thing to be encrypted.

=cut

################################################################################
#   decrypt()
#
#   DESCRIPTION:
# 		Decrypt the given token.
#
#   PARAMETERS:
#       $ciphertext  -- The thing to be decrypt.
# 
#   RETURNS: 
#       $ciphertest
################################################################################
sub decrypt($)
{
	my perllib::MyEncrypt $self	= shift;
	my( $ciphertext )			= @_;
	my $plaintext				= $ciphertext;
	$self->{err}				= "";

	eval
	{
		$plaintext = $self->{handle}->decrypt_hex( $ciphertext );
	};
	if( $@ )
	{
		$self->logIt( ref( $self ) . "::decrypt(): failed.\n" );
		$self->{err} =  ref( $self ) . "::decrypt(): failed.\n";
	}
	return $plaintext;
}

=head2
    B<getError()>
	
	Get the last error.
	B<PARAMETERS:> 
	B<RETURN:> 
		$error

=cut

################################################################################
#   getError()
#
#   DESCRIPTION:
# 		Get the last error.
#
#   PARAMETERS:
# 
#   RETURNS: 
#       $error
################################################################################
sub getError()
{
	my perllib::MyEncrypt $self	= shift;
	return $self->{err};
}
################################################################################
1;

__END__


=head1 SYNOPSIS

 use perllib::MyEncrypt;

 my $myObject = new perllib::MyEncrypt(
                          'funcs_object' => $funcsObject,
 );

 $myObject->setStandOutFlag(1);

 $myObject->logIt("Some log message\n");

 $myObject->debug("Some debug message\n");

 $myObject->printMainHash();

 my $ciphertext = $myObject->encrypt( "my password" );
 
 my $plaintext = $myObject->decrypt( $ciphertext );

 $myObject->printArray( "my array", @myArray );

 $myObject->printHash( "my hash", %myHash );

 $myObject->closeMe();

=head1 DESCRIPTION

This module manages encryption and decryption of a token like a password.

=head1 EXAMPLE

    use Data::Dumper;
    use perllib::MyEncrypt;

    ##########################################
    #    Get an instance of the MyEncrypt.
    ##########################################
    my $myObject = new perllib::MyEncrypt(
                        funcs_object => $CONFIG{funcs},
                        );
    if( $myObject )
    {
        $myObject->closeMe();
        $rc = $lrc ? 0 : 1;
    }

=head1 BUGS
 
None at the time of this writing.  July 7, 2011

=head1 AUTHOR

Denis M. Putnam, July 7, 2011.

=cut
