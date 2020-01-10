##############################################################################
#
#	Sigs.pm
#
#	@(#) sigs.pl 1.4@(#)
#	$Header: $
#
#	Copyright (c) Western Enterprises, Inc. 1997
#
#	DESCRIPTION:
#		Perl functions to to perform signal handling.  The caller must
#		define a function called "cleanUp".  It also has a runProgram
#		function so that the caller may execute parallel perl progams.
#
#
#	MODIFICATION HISTORY:
#	Date		Programmer			Reason
#	09/04/1997	Denis M. Putnam		Created.
#	02/17/1998	Denis M. Putnam		Changed SIGTTOU and SIGTTIN to ignore.
#	02/23/1998	Denis M. Putnam		Modified the runProgram function to add
#									the pid to the %Programs hash table.
#	03/09/1998	Denis M. Putnam		Changed the program,pid pair values to
#									pid,program in the %Progams hash.
#	05/11/1998	Denis M. Putnam		Added if( defined( LOG ) ) checks.
#	06/09/1999	Denis M. Putnam		Change LOG to $LOG everywhere.
#	07/12/1999	Denis M. Putnam		Added the AlarmFlag and logic.
#	$Log: Sigs.pm,v $
#	Revision 1.1.1.1  2008/03/26 21:42:38  dputn463
#	
#	
#	Revision 1.1.1.1  2008/03/25 21:15:38  dputn463
#	
#	
#	Revision 1.3  2006/07/31 15:59:11  s5udmp
#	Commented out warnings and diagnostics to allow it to be specified from the caller.
#	
#	Revision 1.2  2006/07/31 15:57:42  s5udmp
#	got diagnostics and warnings to be clean
#	
#	Revision 1.1.1.1  2006/07/25 19:09:54  s5udmp
#	Imported sources
#	
#	Revision 1.7  2006/01/17 17:59:22  denis
#	Capitalized sigs.
#
#	Revision 1.6  2005/08/26 16:45:09  denis
#	Commented out WAITING.
#
#	Revision 1.5  2005/08/15 16:49:03  denis
#	Fixed sigs for AIX.
#
#	Revision 1.3  2005/08/15 16:22:24  denis
#	Fixed EXPORT values.
#
#	Revision 1.2  2005/08/15 15:59:52  denis
#	Added explicit package names.
#
#	Revision 1.1  2005/08/15 15:57:49  denis
#	Initial revision
#
#	Revision 1.7  2004/04/07 19:30:04  putnam
#	Commented out specific locations for nslookup in the getHostInfo() function.
#	
#	Revision 1.6  2004/03/09 19:43:03  putnam
#	Removed some prints.
#	
#	Revision 1.4  2004/03/05 16:33:38  putnam
#	Added some $LOG calls.
#	
#	Revision 1.3  2004/03/04 23:20:01  putnam
#	Added main:: for cleanUp() and changed main::AlarmFlag to sgs::AlarmFlag.
#	
#	Revision 1.2  2003/12/04 17:55:20  putnam
#	Latest snap of code.
#	
#	Revision 1.15  2001/05/18 19:32:47  putnam
#	Undid revision 1.14.
#
#	Revision 1.13  2000/10/18 15:03:51  don
#	get hostname from Sys::Hostname
#
#	Revision 1.12  2000/10/06 03:44:29  don
#	added getHostInfo function
#
#	Revision 1.11  2000/03/22 21:38:32  sybase
#	Commented out CHLD signal handle assignment.
#
#	Revision 1.10  2000/03/22 21:01:29  putnam
#	Made CHLD a legitamit handled signal.
#
#	Revision 1.9  2000/03/22 19:17:46  putnam
#	Removed standard out statements for Nate.
#
##############################################################################

##################################################################
#	Signal handling stuff.
##################################################################
package perllib::Sigs;

use Data::Dumper;
use FileHandle;
use strict;
#use warnings;
#use diagnostics;
use Config;
use Sys::Hostname;
require Exporter;

use vars qw( @ISA @EXPORT );
@ISA		= qw( Exporter );
@EXPORT	= qw( signalHandler InitSignals getHostInfo runProgram currentTime );
#@Sigs::EXPORT_OK	= qw( $COMMAND );

defined $Config{sig_name} or die "No signals?";

#%Sigs::signo = %SIG;
#@Sigs::signame = ();
#$Sigs::AlarmFlag = 0;

##################################################################
#	Create a hash table to associate the program names with their
#	pids, so that we can terminate any child processes.
#	This hash has the form ( <pid>,<program name> ).  Pid is the
#	key to the hash.
#	
##################################################################
#%Sigs::Programs = ();
use vars qw( %Programs %signo @signame $AlarmFlag );
%Programs = ();
%signo = %SIG;
@signame = ();
$AlarmFlag = 0;

##################################################################
#	signalHandler
#
#	PURPOSE:
#		This function handles the signals for this program.
#
#	RETURN(S):
#		Nothing.
##################################################################
sub signalHandler
{
	my( $signame );
	my( $pid );

	$signame = shift;

	#print "In signalHandler:$signame\n";
	##################################################################
	#	Check for the alarm signal.
	##################################################################
	if( $signame eq $Config{ALRM} )
	{
		#	Reset the handler.
		#print "Resetting alarm signal handler.\n";
		$SIG{ALRM} = \&Sigs::signalHandler;

		#	Set the global flag.
		#$Sigs::AlarmFlag = 1;
		$AlarmFlag = 1;
		#print "Returning from signal handler.\n";
		return;
	}
	else
	{
		$SIG{$signame} = 'IGNORE';
	}

	##################################################################
	#	Terminate all child processes.
	##################################################################
	foreach $pid (sort keys %Programs )
	{
		if( $pid != 0 )	# zero causes me to die!
		{
			#kill 'TERM', $Programs{$pid};
			kill 'TERM', $pid;
		}
	}

	##################################################################
	#	Clean up and exit.
	##################################################################
	if( defined( &main::cleanUp ) )
	{
		&main::cleanUp();
	}
	exit( 1 );
}

##################################################################
#	InitSignals
#
#	PURPOSE:
#		This function sets up signal handling for this program.
#
#	RETURN(S):
#		Nothing.
##################################################################
sub InitSignals
{
	my( $signalHandler ) = @_;
	my( $i );
	my( $name );

	#print "In InitSignals\n";

	$i = 0;
	foreach $name (split(' ', $Config{sig_name}))
	{
		#$Sigs::signo{$name}	= $i;
		$signo{$name}	= $i;
		#$Sigs::signame[$i]	= $name;
		$signame[$i]	= $name;
		$SIG{$i}			= \&$signalHandler if( defined( $SIG{$i} ) );
#		print "$signame[$i]:$signo{$name}\n";
		$i++;
	}

	$SIG{HUP}		=  'DEFAULT';
	$SIG{INT}		=  \&$signalHandler;
	$SIG{QUIT}		=  'IGNORE';
	$SIG{ALRM}		=  \&$signalHandler;
	$SIG{TERM}		=  \&$signalHandler;
	$SIG{USR1}		=  'IGNORE';
	$SIG{USR2}		=  'IGNORE';
	#$SIG{CHLD}		=  \&$signalHandler;
	$SIG{PWR}		=  \&$signalHandler;
	$SIG{WINCH}		=  'IGNORE';
	$SIG{URG}		=  'IGNORE';
	$SIG{STOP}		=  'IGNORE';
	$SIG{TSTP}		=  'DEFAULT';
	$SIG{CONT}		=  'DEFAULT';
	$SIG{TTIN}		=  'IGNORE';
	$SIG{TTOU}		=  'IGNORE';
	$SIG{VTALRM}	=  'IGNORE';
	$SIG{PROF}		=  'IGNORE';
	$SIG{XCPU}		=  'DEFAULT';
	$SIG{XFSZ}		=  \&$signalHandler;
	#$SIG{WAITING}	=  'IGNORE';
#	$SIG{LWP}		=  'IGNORE';
}

##################################################################
#
#	getHostInfo
#
#	PURPOSE:
#		Gets FQDN, IP addr, os for localhost.
#
#	RETURN(S):
#		Array returned ( FQDN, IP_ADDR, OS )
#
##################################################################
sub getHostInfo()
{
	my($h_) = &hostname();
	my($s_);
	my(@i_);
	#my($nslookup_) = '/usr/sbin/nslookup';
	my($nslookup_) = 'nslookup';
	my($ip_);

	chomp($s_=`uname -s`);
	@i_ = unpack('C4', gethostbyname $h_);
	$ip_ = "$i_[0].$i_[1].$i_[2].$i_[3]";

	#if ( -x $nslookup_ )
	#{
	#}
	#elsif ( -x ($nslookup_ = '/bin/nslookup'))
	#{
	#}
	#else
	#{
	#	print "$0 can't find nslookup\n";
	#	#exit 1;
	#	return;
	#}

	chomp($h_ = `$nslookup_ $ip_ | grep Name:`);
	$h_ =~ s/Name: *//;

	return ($h_, $ip_, $s_);
}

##################################################################
#	runProgram
#
#	PURPOSE:
#		Runs the given string argument as a parallel program.
#		This function does NOT wait for the process to complete.
#
#	RETURN(S):
#		The child's pid and process name ( <pid>, <process name> ).
##################################################################
sub runProgram
{
	my( $Program, @args ) = @_;
	my( $pid );
	my( $mytime );

#	return( 0, "" );

	#print Dumper( \@args );
	$mytime = &currentTime();
	FORK:
	{
		if( $pid = fork )
		{
			#	parent here
			#	child process pid is available in $pid
			#print "$mytime Returning pid $pid\n";
			$Programs{$pid} = $Program;
			return( $pid, $Program );
		}
		elsif( defined $pid )
		{
			#	child here
			#	parent process pid is available with getppid
			#print "$mytime Executing $Program...\n";
			exec( $Program, @args ) || die "Exec failed for $Program:$!\n";
			#exec '/bin/echo', 'Your arguments are: ', @args;
			#exec @args;
		}
		elsif( $! =~ /No more process/ )
		{
			#	EAGAIN, supposedly recoverable fork error
			sleep 5;
			redo FORK;
		}
		else
		{
			#	weird fork error
			die "Can't fork: $!\n";
		}
	}
	return( -1, "" );
}

##################################################################
#	currentTime
#
#	PURPOSE:
#		To get the current date and time in the following format:
#		mm dd yyyy hh:mm:ss
#
#	RETURN(S):
#		A string containing the current date and time.
##################################################################
sub currentTime
{
	my( $sec );
	my( $min );
	my( $hour );
	my( $mday );
	my( $mon );
	my( $year );
	my( $wday );
	my( $yday );
	my( $isdst );
	my( $retString );
	my( $CenturyYear );
	my( $RealMon );

	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$CenturyYear = 1900 + $year;
	$RealMon = $mon + 1;

	$retString = sprintf( "%s-%.2d-%.2d %.2d:%.2d:%.2d",
			$CenturyYear,
			$RealMon,
			$mday,
			$hour,
			$min,
			$sec
			);
	return( $retString );
}
1;
