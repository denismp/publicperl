#######################################################################
#	$Header: $
#
#	DESCRIPTION:
#		This file contains the functionality to run a shell command
#		in Perl.
#
#	AUTHOR:
#		Denis M. Putnam
#
#	$Author: dputn463 $
#
#	$Date: 2008/03/26 21:42:38 $
#
#	$Locker:  $
#	MODIFICATION HISTORY:
#	$Log: Command.pm,v $
#	Revision 1.1.1.1  2008/03/26 21:42:38  dputn463
#	
#	
#	Revision 1.1.1.1  2008/03/25 21:15:37  dputn463
#	
#	
#	Revision 1.3  2005/08/15 16:18:46  denis
#	Fixed Sigs use.
#
#	Revision 1.2  2005/08/15 16:05:10  denis
#	Fixed syntax errors.
#
#	Revision 1.1  2005/08/15 15:57:49  denis
#	Initial revision
#
#	Revision 1.4  2004/07/08 23:59:15  putnam
#	removed prints
#	
#	Revision 1.3  2003/12/04 17:55:20  putnam
#	Latest snap of code.
#	
#	Revision 1.1.1.1  2003/11/18 19:05:15  putnam
#	no message
#	
#	Revision 1.5  2000/08/22 23:26:23  putnam
#	Added the alarmHandler() and the supporting code.
#
#	Revision 1.4  2000/08/22 23:09:41  putnam
#	Fixed the broken reference to Programs and Command.
#
#	Revision 1.3  2000/08/22 23:01:49  putnam
#	Modified code to put the program into the Programs hash to allow signal
#	handlers to kill the child programs.
#
#	Revision 1.2  2000/07/18 18:58:29  putnam
#	Converted to a Perl module so that the proper variables get inherited.
#
#	Revision 1.1  2000/07/18 17:14:53  putnam
#	Initial revision
#
#######################################################################
package perllib::Command;

use FileHandle;
use perllib::Sigs;	# local home grown signal library.
use strict;
#no strict 'refs';
require Exporter;
use vars qw( @ISA @EXPORT @EXPORT_OK );

@ISA		= qw( Exporter );
@EXPORT		= qw( runCommand );
@EXPORT_OK	= qw( $COMMAND );

use vars qw( $COMMAND );
$COMMAND	= new FileHandle;

############################################################
#	runCommand
#
#	DESCRIPTION:
#		This function runs the given command in UNIX.
#
#	RETURN(S):
#		( $Count, @List )
############################################################
sub runCommand
{
	my( $pCommand, $pTimeStamp ) = @_;
	my( $InputLine );
	my( @List );
	my( $Count );
	my( $Error );
	my( $StatusCmd );
	my( $mytime );
	my( $Pid, $Program );
	$SIG{ALRM} = \&alarmHandler;

	if( !defined( $pTimeStamp ) or $pTimeStamp eq "" )
	{
		$mytime = &currentTime();
	}
	else
	{
		$mytime = $pTimeStamp;
	}
	$Count = 0;
	$Error = 0;
	#$StatusCmd = " 2>&1; echo \$\?";
	$StatusCmd = " 2>&1";
	$COMMAND = new FileHandle;

	$pCommand .= $StatusCmd;
	#print "$mytime Running \[$pCommand\]\n";
	$Pid = open( $COMMAND, "$pCommand|" ) or warn "Can't run $pCommand: $!\n";
	$main::Programs{$Pid} = $pCommand;
	while( $InputLine = <$COMMAND> )
	{
		chomp( $InputLine );
		#print "$InputLine\n";
		push( @List, $InputLine );
		$Error = $InputLine;
		$Error =~ /\d+/;
		$Count++;
		if( $InputLine =~ /remshd: Login incorrect./
			or $InputLine =~ /Protocol error/
			or $InputLine =~ /permission denied/
			or $InputLine =~ /Connection timed out/
		)
		{
			$Error = 1;
			last;
		}
	}
	close( $COMMAND );
	$Error = $?;
	&cleanChildren();

	$mytime = &currentTime() if( !defined( $pTimeStamp ) );
	return( $Count, $Error, @List );
}

############################################################
#
#	alarmHandler
#
#	DESCRIPTION:
#		This function is the alarm handler for this program. 
#
#	RETURN(S):
############################################################
sub alarmHandler
{
	my( $signame );
	my( $pid );

	$signame = shift;

	#	Rest the alarmHandler.
	$SIG{ALRM} = \&alarmHandler;

	$main::AlarmFlag = 1;

	&cleanChildren();
}

############################################################
#
#	cleanChildren
#
#	DESCRIPTION:
#		This function clean up children.
#
#	RETURN(S):
############################################################
sub cleanChildren
{
	my( $pid );

	###################################################
	#	Terminate all child process.
	###################################################
	foreach $pid ( sort keys %main::Programs )
	{
		if( $pid != 0 ) # zero causes me to die!
		{
			kill 'TERM', $pid;
			delete( $main::Programs{$pid} ) if( exists( $main::Programs{$pid} ) );
		}
	}
}
1;
