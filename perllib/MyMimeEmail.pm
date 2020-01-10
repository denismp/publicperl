###########################################################################
##  $Header: $
##
## 	Module for handling emails with attachments.
##  $Author: putnam $
############################################################################
##
##  MODIFICATION HISTORY:
##  DATE        WHOM                DESCRIPTION
##	08/24/2011	Denis M. Putnam		Created.
##  $Log: $
############################################################################
package perllib::MyMimeEmail;

=head1 NAME

B<perllib::MyMimeEmail> - Handle MIME emails for attachments.

 B<new()> - create an instance of this package.  Not exported.  B<USAGE:>
 my $myObject = new perllib::MyMimeEmail(
                          'mailhost'     => $host,
                          'from_address' => $from_address,
                          'to_address'   => $to_address,
                          'subject'      => $subject,
                          'message'      => $message,
                          'attachment'   => "/tmp/my.xlsx",
                          'attach_type'  => "application/x-ms-excel"
                          'funcs_object' => $funcsObject
 );
 mailhost:      Something like "mail.company.com".
 from_address:  Something like "denis.putnam@mydomain.com".
 to_address:    Something like "denis.putnam@mydomain.com|joe.blow@somedomain.com"
 subject:       Subject of the email.
 message:       Text of the email message.
 attachment:    Fully qualified path of the file to be sent.
 attach_type:   Any one of the accepted Content-type: values.
 funcs_object:  Handle to the perllib::Funcs object previously instantiated.

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
use MIME::Lite;
use Net::SMTP;
use fields qw(
				mailhost
				from_address 
				to_address
				subject
				message
				attachment
				attach_type
				debug 
				funcs_object 
				STDOUTFLAG 
				mime_container
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
sub attach($$);
sub send();

################################################################################
#   new()
#
#   DESCRIPTION:
#       Perl function to create an instance to this package.
#
#   USAGE:
#       my $myObject = new perllib::MyMimeEmail(
#                          'mailhost'     => $mailhost,
#                          'from_address' => $from_address,
#                          'to_address'   => $to_address,
#                          'subject'      => $subject,
#                          'message'      => $message,
#                          'attachment'   => "/tmp/my.xlsx",
#                          'attach_type'  => "application/x-ms-excel"
#                          'funcs_object' => $funcsObject
#       );
#       mailhost:      Something like "mail.mycompany.com".
#       from_address:  Something like "denis.putnam@mydomain.com".
#       to_address:    Something like "denis.putnam@mydomain.com|joe.blow@somedomain.com"
#       subject:       Subject of the email.
#       message:       Text of the email message.
#       attachment:    Fully qualified path of the file to be sent.
#       attach_type:   Any one of the accepted Content-type: values.
#       funcs_object:  Handle to the perllib::Funcs object previously instantiated.
#
#   RETURNS:
#       A reference to this package.
################################################################################
sub new()
{
	my perllib::MyMimeEmail $self	= shift;    # Me.
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
	my $mailhost   			= $opts->{mailhost};
	my $from_address   		= $opts->{from_address};
	my $to_address			= $opts->{to_address};
	my $subject				= $opts->{subject};
	my $message				= $opts->{message};
	my $attachment			= $opts->{attachment};
	my $attach_type			= $opts->{attach_type};
	$self->{debug}			= $myFuncs->{DEBUG};
	$self->{funcs_object}	= delete( $opts->{funcs_object} );
	$self->{mailhost}		= delete( $opts->{mailhost} );
	$self->{from_address}	= delete( $opts->{from_address} );
	$self->{to_address}		= delete( $opts->{to_address} );
	$self->{subject}		= delete( $opts->{subject} );
	$self->{message}		= delete( $opts->{message} );
	$self->{attachment}		= delete( $opts->{attachment} );
	$self->{attach_type}	= delete( $opts->{attach_type} );
	my $args				= delete( $opts->{args} ) || [];

	#die( "Unknown arguments" ) if keys( %{$opts} ); 
	##########################################
	#	If there are any keys left in the
	#	opts hash, then we were called with
	#	an illegal argument.
	##########################################
	if( keys( %{$opts} ) )
	{
		print "perllib::MyMimeEmail::new(): Illegal arguments.\n";
		foreach my $key ( %{$opts} )
		{
			print ref( $self ) . "::new(): Illegal argument " . $key . " => " . $opts->{$key} . "\n";
		}
		return undef;
	}
	if( !defined($from_address) or ( $from_address eq "" ) )
	{
		print ref( $self ) . "::new(): You must specify the from_address.\n";
		return undef;
	}
	if( !defined($to_address) or ( $to_address eq "" ) )
	{
		print ref( $self ) . "::new(): You must specify the to_address.\n";
		return undef;
	}
	if( !defined($subject) or ( $subject eq "" ) )
	{
		print ref( $self ) . "::new(): You must specify the subject.\n";
		return undef;
	}
	if( !defined($message) or ( $message eq "" ) )
	{
		print ref( $self ) . "::new(): You must specify the message.\n";
		return undef;
	}
	#if( !defined($attachment) or ( $attachment eq "" ) )
	#{
	#	print ref( $self ) . "::new(): You must specify the attachment.\n";
	#	return undef;
	#}
	#if( !defined($attach_type) or ( $attach_type eq "" ) )
	#{
	#	print ref( $self ) . "::new(): You must specify the attach_type.\n";
	#	return undef;
	#}
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
	my perllib::MyMimeEmail $self = shift;
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
	my perllib::MyMimeEmail $self	= shift;
	my( $name, $href )				= @_;

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
	my perllib::MyMimeEmail $self 			= shift;
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
	my perllib::MyMimeEmail $self	= shift;
	my( $name, $aref )				= @_;

	$self->{'funcs_object'}->printArray( $name, $aref );
}

=head2
    B<printMainHash()>
	
	Logs the MyMimeEmail hash for this object.

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
	my perllib::MyMimeEmail $self	= shift;
	my $name						= "perllib::MyMimeEmail";

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
	my perllib::MyMimeEmail $self	= shift;
	my($msg)						= @_;

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
	my perllib::MyMimeEmail $self	= shift;
	my( $msg )						= @_;

	$self->{'funcs_object'}->debug($msg);
}

=head2
    B<send()>
	
	Send the email.
	B<PARAMETERS:> 
	B<RETURN:> 
		0 for success.

=cut

################################################################################
#   send()
#
#   DESCRIPTION:
# 		Send the email.
#
#   PARAMETERS:
# 
#   RETURNS: 
#       0 if successfull.
################################################################################
sub send()
{
	my perllib::MyMimeEmail $self	= shift;

	my $msg 	= $self->{mime_container};
	#MIME::Lite->send( 'sendmail', "/usr/sbin/sendmail -oB -v -t -oi" );
	#MIME::Lite->send( 'smtp', 're2imail01.fhlmc.com', Debug => $self->{debug} );
	MIME::Lite->send( 'smtp', $self->{mailhost}, Debug => $self->{debug} );
	my $rs;
	eval{
		$rs		= $msg->send() or $self->logIt( ref( $self ) . "::send(): Error sending the email:$!\n" );
	};
	if( $@ )
	{
		$self->logIt( ref( $self ) . "::send():" . $@ . "\n" );
	}

	return 1 if( ! defined( $rs ) );
	return 0;
}

=head2
    B<attach($type,$file)>
	
	Add an additional attachment to the email.
	B<PARAMETERS:> 
		$type - one of the accepted Content-type:, i.e., 'application/x-ms-excel'
		$file - file to be attached.
	B<RETURN:> 
		0 for success.

=cut

################################################################################
#   attach()
#
#   DESCRIPTION:
# 		Add an additional attachment to the email.
#
#   PARAMETERS:
#       $type    -- one of the accepted Content-type:
#       $file    -- file to be attached.
# 
#   RETURNS: 
#       0 if successfull.
################################################################################
sub attach($$)
{
	my perllib::MyMimeEmail $self	= shift;
	my( $type, $file )				= @_;

	my $msg 		= $self->{mime_container};
	my $fileName	= basename( $file );
	my $part		= $msg->attach( 
								Type => $self->{attach_type}, 
								Path => $file, 
								Filename => $fileName, 
								Dispostion => 'attachment' ) 
								or $self->logIt( ref( $self ) . "::attach(): Error adding " . $fileName . ":$!\n" );

	return 1 if( ! defined( $part ) );
	return 0;
}


################################################################################
#   init()
#
#   DESCRIPTION:
#       Initialize this object.
#
#   PARAMETERS:
# 
#   RETURNS: 
#       0 for success or non-zero otherwise.
################################################################################
sub init()
{
	my perllib::MyMimeEmail $self	= shift;
	my $rc							= 0;
	my $whereflg					= 0;
	return 1 if( !$self );

	$self->{mailhost} = "localhost" if( !defined( $self->{mailhost} ) || $self->{mailhost} eq "" );
	my $to = $self->{to_address};
	my @to = split( /\|/, $to );
	my $to = join( " ", @to );
	$self->{mime_container} = MIME::Lite->new( 
									From => $self->{from_address},
									To => $to,
									Subject => $self->{subject},
									Type => 'multipart/mixed',
	) or $self->logIt( ref( $self ) . "::init(): Error creating multipart container: $!\n" );

	return 1 if( ! defined( $self->{mime_container} ) );

	my $msg = $self->{mime_container};
	my $part		= $msg->attach( 
								Type => 'TEXT', 
								Data => $self->{message} 
								)
								or $self->logIt( ref( $self ) . "::init(): Error adding " . $self->{message} . ":$!\n" );

	return 2 if( ! defined( $part ) );
	my $fileName	= $self->{attachment};
	$part			= $msg->attach( 
								Type => $self->{attach_type}, 
								Path => $fileName, 
								Filename => basename( $fileName ), 
								Dispostion => 'attachment' ) 
								or $self->logIt( ref( $self ) . "::init(): Error adding " . $fileName . ":$!\n" ) if( defined( $fileName ) && $fileName ne ""  );

	return 3 if( ! defined( $part ) );
	return $rc;
}


################################################################################
1;

__END__


=head1 SYNOPSIS

 use perllib::MyMimeEmail;
 my $myObject = new perllib::MyMimeEmail(
                          'mailhost'     => $mailhost,
                          'from_address' => $from_address,
                          'to_address'   => $to_address,
                          'subject'      => $subject,
                          'message'      => $message,
                          'attachment'   => "/tmp/my.xlsx",
                          'attach_type'  => "application/x-ms-excel"
                          'funcs_object' => $funcsObject
 );

 $myObject->setStandOutFlag(1);

 $myObject->logIt("Some log message\n");

 $myObject->debug("Some debug message\n");

 $myObject->printMainHash();

 $myObject->printArray( "my array", @myArray );

 $myObject->printHash( "my hash", %myHash );

 $myObject->closeMe();

=head1 DESCRIPTION

This module manages MIME email with attachments

=head1 EXAMPLE

    use Data::Dumper;
    use perllib::MyMimeEmail;

    ##########################################
    #    Get an instance of the MyMimeEmail.
    ##########################################
    my $myObject = new perllib::MyMimeEmail(
                          'mailhost'     => "mail.mycompany.com",
                          'from_address' => "denis\@mail.com",
                          'to_address'   => "denis\@mail.com",
                          'subject'      => "Hello",
                          'message'      => "hello message",
                          'attachment'   => "/tmp/my.xlsx",
                          'attach_type'  => "application/x-ms-excel"
                          'funcs_object' => $funcsObject
    );
    if( $myObject )
    {
        $myObject->closeMe();
        $rc = $lrc ? 0 : 1;
    }

=head1 BUGS
 
None at the time of this writing.  August 24, 2011

=head1 AUTHOR

Denis M. Putnam, August 24, 2011.

=cut
