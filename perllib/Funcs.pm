############################################################################
##  $Header: $
##	Funcs.pm
##
##	Perl module some useful functions.
############################################################################
##
##  MODIFICATION HISTORY:
##  DATE        WHOM                DESCRIPTION
##  07/19/2005  Denis M. Putnam     Created.
##	$Log: Funcs.pm,v $
##	Revision 1.1.1.1  2008/03/26 21:42:38  dputn463
##	
##	
##	Revision 1.1.1.1  2008/03/25 21:15:37  dputn463
##	
##	
##	Revision 1.3  2006/08/29 15:14:48  s5udmp
##	Modified header.
##	
##	Revision 1.2  2006/08/29 15:12:44  s5udmp
##	Modified printArray to use Dumper.
##	
##	Revision 1.28  2006/02/23 23:05:35  denis
##	Fixed join in logHash().
##
##	Revision 1.27  2006/02/23 22:15:04  denis
##	Added {} to ARRAY ref in logHash().
##
##	Revision 1.26  2006/01/20 22:11:22  denis
##	Modified cleanDir() to use atime rather than ctime, and added
##	minutesCleanDirLinux().
##
##	Revision 1.25  2006/01/10 17:30:15  denis
##	Fixed some bugs.
##
##	Revision 1.24  2006/01/09 19:25:31  denis
##	Set autoflush to 1.
##
##	Revision 1.23  2006/01/09 18:18:49  denis
##	Added lock() and unlock().
##
##	Revision 1.22  2006/01/06 18:04:49  denis
##	Added logHash().
##
##	Revision 1.21  2005/12/21 16:29:44  denis
##	Added 2>/dev/null to find command.
##
##	Revision 1.20  2005/11/29 22:13:38  denis
##	Added numdays parameter to cleanDir().
##
##	Revision 1.19  2005/11/29 22:00:40  denis
##	Added cleanDir().
##
##	Revision 1.18  2005/08/26 15:08:40  denis
##	Added flush() to logIt().
##
##	Revision 1.17  2005/08/12 16:53:39  denis
##	Format of perldoc stuff.
##
##	Revision 1.16  2005/08/12 16:49:32  denis
##	Fixed some perldoc stuff.
##
##	Revision 1.15  2005/08/11 20:07:15  denis
##	Another doc fix.
##
##	Revision 1.14  2005/08/11 20:00:28  denis
##	Fixed another misspelling.
##
##	Revision 1.13  2005/08/11 19:57:40  denis
##	Fixed misspelling.
##
##	Revision 1.12  2005/08/11 19:54:05  denis
##	Added perl documentation.
##
##	Revision 1.11  2005/08/08 20:01:06  denis
##	Modified printHash() and printArray() to use hard reference to % and @ since perl module don't honor prototypes.
##
##	Revision 1.10  2005/08/05 16:34:36  denis
##	Added newlines in printHash() and printArray().
##
##	Revision 1.9  2005/08/05 16:20:11  denis
##	Added [] around values output for printHash and printArray.
##
##	Revision 1.8  2005/08/05 16:05:14  denis
##	Added printArray().
##
##	Revision 1.7  2005/08/03 18:49:08  denis
##	Added getFileTimeStamp().
##
##	Revision 1.6  2005/07/29 21:12:21  denis
##	Added function forward delclarations.
##
##	Revision 1.5  2005/07/26 19:51:19  denis
##	Fixed bugs.
##
##	Revision 1.4  2005/07/26 18:54:51  denis
##	Added printHash().
##
##	Revision 1.3  2005/07/26 16:36:27  denis
##	Removed \r
##
##	Revision 1.2  2005/07/26 16:35:08  denis
##	Added MODE.
##
############################################################################
package perllib::Funcs;

use strict;

use Exporter;
use vars qw( @ISA @EXPORT );
@ISA = qw(Exporter);

use Fcntl ':flock';	#	import LOCK_* constants.
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
use Fcntl;

use FileHandle;
use Carp;
use Data::Dumper;
use perllib::Command;

@EXPORT = qw( getDate getFileTimeStamp );

sub new();
sub setStandardOutFlag($);
sub getDate(;$);
sub closeMe();
sub printHash($$);
sub logHash($$);
sub printArray($$);
sub logIt($);
sub debug(;$);
sub getFileTimeStamp();
sub cleanDir($$$);
sub lock($);
sub unlock($);
sub minutesCleanDirLinux($$$);
sub getLogFileName();
sub getLogFH();
################################################################################
#   new()
#
#   DESCRIPTION:
#       Perl function to create an instance to this package.
#
#   USAGE:
#       $myFuncs = new perllib::Funcs(
#                            'LOGFILE' => "/tmp/mylog.log",
#                            'MODE' => 0,
#                            'STDOUTFLAG' => 1,
#                            'DEBUG' => 1
#                                   );
#       MODE is: 0 -- create, 1 -- append.
#
#   RETURNS:
#       A reference to this package.
################################################################################
sub new()
{
	my( $myPackage )   = shift;   # Me.
	my( $self ) = { @_ };   # Stores all the keys and values passed to this function.
	my $logFile;
	my $stdoutFlag;
	my $debug;
	my $mode;

	#################################################
	#   Set the local variables to the args.
	#################################################
	$logFile = $self->{'LOGFILE'};
	$stdoutFlag = $self->{'STDOUTFLAG'};
	$debug = $self->{'DEBUG'};
	$mode = $self->{'MODE'};

	if( !defined( $logFile ) or ( $logFile eq "" ) )
	{
		print "perllib::Funcs You must specify the LOGFILE.\n";
		return undef;
	}

	my $fileHandle = new FileHandle;
	if( !defined( $mode ) or $mode == 0 )
	{
		if( ! $fileHandle->open( ">$logFile" ) )
		{
			print "perllib::Funcs Unable to open $logFile: $!\n";
			return undef;
		}
	}
	else
	{
		if( ! $fileHandle->open( ">>$logFile" ) )
		{
			print "perllib::Funcs Unable to open $logFile: $!\n";
			return undef;
		}
	}

	$fileHandle->autoflush( 1 );
	$self->{'LOG_FH'} = $fileHandle;

	bless $self, $myPackage;

	return $self;
}

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
	my $self	= shift;
	my( $flag )	= @_;
	$self->{'STDOUTFLAG'} = $flag;
}
###############################################################################
#   getDate
#
#   DESCRIPTION:
#       Gets the current date.
#
#   RETURN(S):
#       A string containing the date.
###############################################################################
sub getDate(;$)
{
	my( $modDate )	= @_;
	my @localTime;
	my $rVal;
	if( defined( $modDate ) )
	{
		@localTime  = localtime($modDate);
	}
	else
	{
		@localTime  = localtime();
	}
	my $sec    = sprintf("%02d", $localTime[0]);
	my $min    = sprintf("%02d", $localTime[1]);
	my $hours  = $localTime[2];
	my $day    = $localTime[3];
	my $currMonth  = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
					  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')[ $localTime[4] ];
	my $year   = $localTime[5] + 1900;
	$rVal = sprintf( "%s_%02d_%4d_%02d%02d%02d", $currMonth, $day, $year, $hours, $min, $sec );
	return $rVal;
}
###############################################################################
#   getFileTimeStamp
#
#   DESCRIPTION:
#       Get the current time without spaces for a file timestamp.
#
#   RETURN(S):
#		A string containing a file timestamp.
###############################################################################
sub getFileTimeStamp()
{
	my $rVal = perllib::Funcs::getDate();
	$rVal =~ s/\s+/_/g;
	$rVal =~ s/,//g;
	$rVal =~ s/://g;
	return $rVal;
}
###############################################################################
#   cleanDir()
#
#   DESCRIPTION:
#		Removed the file pattern of files from the given directory.
#
#	PARAMETERS:
#		$directory		-- Directory name.
#		$filepattern	-- Wild card pattern of files to delete.
#		$numdays		-- number of days back.
#
#   RETURN(S):
#		0 for success or >0.
###############################################################################
sub cleanDir($$$)
{
	my $self									= shift;
	my( $directory, $filepattern, $numdays )	= @_;

	my $command = "find $directory -name \"$filepattern\" -atime +$numdays 2>/dev/null | xargs rm -f";
	$self->logIt( "perllib::Funcs::cleanDir(): $command\n" );
	my( $rc, $err, @list ) = runCommand( $command );
	foreach my $line ( @list )
	{
		$self->debug( "perllib::Funcs::cleanDir(): $line\n" );
	}
	return $rc;
}
###############################################################################
#   minutesCleanDirLinux()
#
#   DESCRIPTION:
#		Removed the file pattern of files from the given directory.
#
#	PARAMETERS:
#		$directory		-- Directory name.
#		$filepattern	-- Wild card pattern of files to delete.
#		$numMins		-- number of minutes back.
#
#   RETURN(S):
#		0 for success or >0.
###############################################################################
sub minutesCleanDirLinux($$$)
{
	my $self									= shift;
	my( $directory, $filepattern, $numMins )	= @_;

	my $command = "find $directory -maxdepth 1 -name \"$filepattern\" -amin +$numMins | xargs rm -f";
	$self->logIt( "perllib::Funcs::minutesCleanDirLinux(): $command\n" );
	my( $rc, $err, @list ) = runCommand( $command );
	foreach my $line ( @list )
	{
		$self->logIt( "perllib::Funcs::minutesCleanDirLinux(): $line\n" );
	}
	return $rc;
}
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
	my $self        = shift;
	my $fileHandle	= $self->{'LOG_FH'};
	$self->debug( "Funcs instance has been closed.\n" );
	$fileHandle->close();
	undef( $self->{'LOG_FH'} );
}
################################################################################
#
#   printArray()
#
#   DESCRIPTION:
#       Logs the hash for this program.
#
#   RETURN(S):
#       Nothing.
################################################################################
sub printArray($$)
{
	my $self			= shift;
	my( $name, $aref )	= @_;
	my $value;
	my $key;
	$self->debug( "\nBegin contents of the $name array.\n\n" );
	#foreach $key (@{$aref}) 
	#{
	#	$self->debug( "[$key]\n" );
	#}
	$self->debug( Dumper( $aref ) . "\n" );
	$self->debug( "\nEnd contents of the $name array.\n\n" );
}
################################################################################
#
#   printHash()
#
#   DESCRIPTION:
#       Logs the hash for this program.
#
#   RETURN(S):
#       Nothing.
################################################################################
sub printHash($$)
{
	my $self			= shift;
	my( $name, %href )	= @_;
    $self->debug( "\nBegin contents of the $name hash.\n\n" );
	$self->debug( Dumper( \%href ) );
	#foreach my $key (sort keys %href) 
	#{
	#    $self->debug( "$key = [$href{$key}]\n" );
	#    #logIt( "$key = $href->{$key}\n" );
	#}
	$self->debug( "\nEnd contents of the $name hash.\n\n" );
}
###############################################################################
#   logHash()
#
#   DESCRIPTION:
#       Log the Hash information similar to dump.
#
#	PARAMETERS:
#		$hashName
#		\%theHash
#
#   RETURN(S):
#		Nothing.
###############################################################################
sub logHash($$)
{
	my $self			= shift;
	my( $name, $href )	= @_;

	return if( !defined( $name ) );

	$self->logIt( "\nBegin contents of the $name hash.\n\n" );
	$self->logIt( Dumper( $href ) );
	if( 0 )
	{
	foreach my $key (sort keys %{$href}) 
	{
		#if( ref( $href->{$key} )
		my $myRef = ref $href->{$key};
		$self->logIt( "$key ref is a [$myRef]\n" ) if( $myRef ne "" );
		if( !defined( $myRef ) or $myRef eq "" )
		{
			$self->logIt( "$key = [$href->{$key}]\n" );
		}
		elsif( $myRef eq "ARRAY" )
		{
			my $output = join( '|', @{$href->{$key}} );
			$self->logIt( "$key=[$output]\n" );
		}
		elsif( $myRef eq "HASH" )
		{
			my $catKey = $name . "->{" . $key . "}";
			#$self->logHash( $catKey, $href->{$key} );
			$self->logIt( Dumper( $href->{$key} ) );
		}
	}
	}
	$self->logIt( "\nEnd contents of the $name hash.\n\n" );
}
################################################################################
#   logIt()
#
#   DESCRIPTION:
#       Perl function to print and log the given msg.  This function is internal
#       to the module.
#
#   PARAMETERS:
#       $msg    -- String to be printed
#
#   RETURNS:
#       Nothing.
################################################################################
sub logIt($)
{
	my $self    	= shift;
	my( $msg )  	= @_;
	my $logFile 	= $self->{'LOGFILE'};
	my $fileHandle	= $self->{'LOG_FH'};

	if( defined( $fileHandle ) )
	{
		print $fileHandle getDate() . ":" . $msg;
		$fileHandle->flush();
		print getDate() . ":" . $msg if( $self->{'STDOUTFLAG'} );
	}
}
################################################################################
#   debug()
#
#   DESCRIPTION:
#       Perl function to print and log the given msg.  This function is internal
#       to the module.
#
#   PARAMETERS:
#       $msg    -- String to be printed
#
#   RETURNS:
#       Nothing.
################################################################################
sub debug(;$)
{
	my $self    = shift;
	my( $msg )  = @_;
	my $debug   = $self->{'DEBUG'};

	$self->logIt( $msg ) if( defined( $debug ) && $debug >= 1 );
}
################################################################################
#	lock()
#
#	DESCRIPTION:
#		Get an exclusive lock on the file
#
#	PARAMETERS:
#		$FH	-- FileHandle.  Has to be open with a write intent.
#
#	RETURNS:
#		1 if successful, or 0.
################################################################################
sub lock($)
{
	my	$self	= shift;
	my( $FH )	= @_;
	my $done	= 0;
	my $count	= 0;
	#$self->debug( "perllib::MonitorHash::lock(): Entered.\n" );
	while( !$done )
	{
		my $flags = fcntl( $FH, F_GETFL, 0 );
		#$self->debug( "perllib::MonitorHash::lock(): flags=$flags\n" );
		my $rVal = fcntl( $FH, F_SETFL, LOCK_EX | LOCK_NB );
		#$self->debug( "perllib::MonitorHash::lock(): rVal=[$rVal].\n" );
		#print ( "perllib::MonitorHash::lock(): rVal=[$rVal].\n" );
		$done = 1 if( $rVal eq "0 but true" );
		last if( $done == 1 );
		$count++;
		last if( $count > 99 );
		sleep( 2 );
	}
	return $done;
}
################################################################################
#	unlock()
#
#	DESCRIPTION:
#		Release an exclusive lock on the file
#
#	PARAMETERS:
#		$FH	-- FileHandle.
#
#	RETURNS:
#		1 if successful, or 0.
################################################################################
sub unlock($)
{
	my	$self	= shift;
	my( $FH )	= @_;
	my $done	= 0;
	if( defined( $FH ) )
	{
		my $flags = fcntl( $FH, F_GETFL, 0 );
		#$self->debug( "perllib::MonitorHash::unlock(): flags=$flags\n" );
		my $rVal = fcntl( $FH, F_SETFL, LOCK_UN );
		$done = 1 if( $rVal eq "0 but true" );
		#$self->debug( "perllib::MonitorHash::unlock(): rVal=[$rVal]\n" );
	}
	return $done;
}
################################################################################
#	getLogFileName()
#
#	DESCRIPTION:
#		Get the this instance's log file name.
#
#	PARAMETERS:
#
#	RETURNS:
#		The log file name of this instance.
################################################################################
sub getLogFileName()
{
	my	$self	= shift;
	return $self->{LOGFILE};
}
################################################################################
#	getLogFH()
#
#	DESCRIPTION:
#		Get the this instance's log file handle.
#
#	PARAMETERS:
#
#	RETURNS:
#		The log file handle of this instance.
################################################################################
sub getLogFH()
{
	my	$self	= shift;
	return $self->{LOG_FH};
}
################################################################################
1;

__END__

=head1 NAME

B<perllib::Funcs> - Home grown perl module with some useful functions/utilities.

B<new()> - create an instance of this package.  Not exported.  B<USAGE:>
$myFuncs = new perllib::Funcs( 'LOGFILE' => "/tmp/mylog.log", 'MODE' => 0,
'STDOUTFLAG' => 1, 'DEBUG' => 1 );	MODE is: 0 -- create, 1 -- append.

B<setStandardOutFlag($)> - Flag indicator for standard output.  By default 
output only gets written to the log file.  Turning this on will make this 
module do both.  Not exported.  B<PARAMETERS:> $flag - either 0 or 1.

B<getDate(;$)> - Get the current date or that of the integer argument that 
represents the value returned from the Perl time() function.  The time is 
returned as a string in the "Mon dd, yyyy hh:mm:ss" format.  This method is 
exported and must be call by the complete package name 
perllib::getDate( $time ).  B<PARAMETERS:> $time - integer value usually 
returned from the Perl time() function.  This parameter is optional.

B<getFileTimeStamp()> - Get the current date returned from the Perl time() 
function.  The time is returned as a string in the "Mon_dd_yyyy_hh:mm:ss" 
format.  This method is exported and must be call by the complete package name 
perllib::getFileTimeStamp().

B<closeMe()> - Closes this instance.

B<printArray($$)> - Print the given array to the log file.  B<PARAMETERS:>
$name - name of array, $aref - array reference that contains the data.

B<printHash($$)> - Print the given array to the log file.  B<PARAMETERS:>
$name - name of hash, $href - hash reference that contains the data.

B<logHash($$)> - Log the given array to the log file. This is a deep recursive
print similar to dump.  B<PARAMETERS:>
$name - name of hash, $href - hash reference that contains the data.

B<logIt($)> - Perl function to print and log the given message.  B<PARAMETERS:>
$msg - message to be printed and logged.

B<debug($)> - Perl function to print and log the given message if debugging is
turned on.  B<PARAMETERS:> $msg - message to be printed and logged.

B<cleanDir($$)> - Perl function to purge old files.
$directory - Directory to be purged. $filepattern - wild card file pattern.

=head1 SYNOPSIS

 use perllib::Funcs;

 my $myFuncs = new perllib::Funcs(
                            'LOGFILE' => "/tmp/mylog.log",
                            'MODE' => 0,
                            'STDOUTFLAG' => 1,
                            'DEBUG' => 1
                            );
        # MODE is: 0 -- create, 1 -- append.
        # STDOUTFLAG is: 0 -- no standard output, 1 -- standard ouput.
        # DEBUG is: 0 -- debug off, 1 -- debug on.

 $myFuncs->setStandOutFlag(1);

 my $time = time();
 my $myDate = perllib::Funcs::getDate($time);

 my $myDate = perllib::Funcs::getDate();

 my $myFileDate = perllib::Funcs::getFileTimeStamp();

 $myFuncs->closeMe();

 $myFuncs->printArray("myarray",@myarray);

 $myFuncs->printHash("myhash",%myhash);

 $myFuncs->logHash("myhash",%myhash);

 $myFuncs->logIt("Some log message\n");

 $myFuncs->debug("Some debug message\n");
 
 $rc = myFuncs->cleanDir( "/tmp", "*.txt" );

=head1 DESCRIPTION

This module contains some useful functions and utilites for use in user
written perl modules and programs.

=head1 BUGS

None at the time of this writing.  January 06, 2006

=head1 AUTHOR

Denis M. Putnam, August 1, 2005.

=cut
