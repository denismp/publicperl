#!/usr/bin/env perl
############################################################################
##	addcsrf.pl
##  Perl script to add the cross site request forgery tokens to the 
##	.ajax call in the javascript files.
##
## Sample parameter file:  See perllib::MyConfig.pm.
############################################################################
##
##  MODIFICATION HISTORY:
##  DATE        WHOM                DESCRIPTION
##  08/12/2016  Denis M. Putnam     Created.
##	$History: $
############################################################################

use strict;
use warnings;
#use diagnostics;

use perllib::Funcs;
use Getopt::Long;
use Carp;
use Cwd;
use Data::Dumper;
use File::Basename;
use File::Copy;
#use File::Path qw(mkpath rmtree);
use File::Path qw(make_path remove_tree);
use perllib::Command;
use perllib::MyConfig;
use Sys::Hostname;
use FileHandle;
use DirHandle;

##################################
#	Function forward declarations
##################################
sub copyFiles($);
sub addcsrf();
sub addTheCsrf($$);
sub initialize();
sub getCmdOptions();
sub resetInit(\%);
sub printVersionInfo();
sub doWork();
sub cleanUp();

###################################
#   Begin MAIN section.
###################################
###################################
#   Declare my CONFIG hash.
###################################
my %CONFIG;

################################################################################
#   Initialize the program.
################################################################################
initialize();

## Populate command-line options
getCmdOptions();

## Print file version info
printVersionInfo();

my $rc;
$rc = doWork();

cleanUp();
exit( $rc );
###################################
#   End MAIN section.
###################################


###################################
#   Begin subroutine section.
###################################
###############################################################################
#   doWork()
#
#   DESCRIPTION:
#       Does the main work for this program.
#
#   RETURN(S):
#       Nothing.
###############################################################################
sub doWork()
{
	my $rc = 0;

	printInfo();

	make_path( $CONFIG{origDir} );
	make_path( $CONFIG{editDir} );

	$rc = copyFiles( $CONFIG{parseDir} );
	$rc = addcsrf();

	return $rc;
}
################################################################################
#
#   addTheScrf()
#
#   DESCRIPTION:
#       Read the source file and write to the destination file with the 
#		csrf() added for the .ajax calls.
#
#   RETURN(S):
#       0 if successfull.
################################################################################
sub addTheCsrf($$)
{        
	my( $srcFile, $destFile ) = @_;
	my $inFH = new FileHandle;
	my $outFH = new FileHandle;
	if( !$inFH->open("<$srcFile") ) {
		logIt( "main::addTheCsrf(): failed to open " . $srcFile . ":$!\n" );
		return 1;
	}
	if( !$outFH->open(">$destFile") ) {
		logIt( "main::addTheCsrf(): failed to open " . $destFile . ":$!\n" );
		return 1;
	}
	my $line;
	my $previousLine;
	while( $line = <$inFH> ) {
		if( $line =~ m/\$\.ajax/ ){
			print $outFH "	var csrf_token = \$\(\"\#topNavCSRFTagId\"\).val()\;\n";
			print $outFH $line;
			print $outFH "\t\tbeforeSend \: function\(xhr\)\{\n";
			print $outFH "\t\t\txhr.setRequestHeader\(\'X-CSRF-Token\'\, csrf_token\)\;\n";
			print $outFH "\t\t\},\n";
			while( $line = <$inFH> ) {
				if( $line =~ m/\}\)\;/ ) {
					#print $outFH "\t\t,\n\t\tbeforeSend \: function\(xhr\)\{\n";
					#print $outFH "\t\t\txhr.setRequestHeader\(\'X-CSRF-Token\'\, csrf_token\)\;\n";
					#print $outFH "\t\t\}\n";
					print $outFH $line;
					last;
				}
				if( $line =~ m/data\s*\:\s*\{/ ) {
					print $outFH $line;
					print $outFH "token \: csrf_token,\n";
				}
				print $outFH $line;
			}
		} else {
			print $outFH $line;
		}
		$previousLine = $line;
	}
	$inFH->close();
	$outFH->close();
}
################################################################################
#
#   addcsrf()
#
#   DESCRIPTION:
#       Parse the javascript files for the ".ajax" patterns 
#
#   RETURN(S):
#       0 if successfull.
################################################################################
sub addcsrf()
{        
	foreach my $fileName ( @{$CONFIG{fileList}} ) {
		logIt( "fileName=" . $fileName . "\n" );
		my $srcFile = $CONFIG{workOrigDir} . "/" . $fileName;
		my $destFile = $CONFIG{workEditDir} . "/" . $fileName;
		logIt( "srcFile=" . $srcFile . "\n" );
		logIt( "destFile=" . $destFile . "\n" );
		addTheCsrf( $srcFile, $destFile );
	}
	return 0;
}
################################################################################
#
#   copyFiles()
#
#   DESCRIPTION:
#       Copy the files to the original and edit directories.
#
#   RETURN(S):
#       0 if successfull.
################################################################################
sub copyFiles($)
{        
	my( $parseDir ) = @_;
	my $dirH = new DirHandle;
	logIt("parseDir=" . $parseDir . "\n" );
	$dirH->open( $parseDir );
	my @fileList;

	my @files = readdir( $dirH );
	$dirH->close();
	my $rc = 0;
	my $newPath = $parseDir;
	$newPath =~ s/^\///;
	my $origDir = $CONFIG{origDir} . "/" . $newPath;
	my $editDir = $CONFIG{editDir} . "/" . $newPath;
	make_path( $origDir );
	make_path( $editDir );
	$CONFIG{workOrigDir} = $origDir;
	$CONFIG{workEditDir} = $editDir;

	foreach my $fileName (@files) {
		next if( $fileName =~ m/^\./ );
		#logIt("FILENAME=".$fileName . "\n" );	
		my $fullPath = $parseDir . "/" . $fileName;
		copyFiles( $fullPath ) if( -d $fullPath );
		next if( $fileName !~ m/\.js$/ );
		logIt("FILENAME=".$fullPath . "\n" );	
		$rc = copy( $fullPath, $origDir );
		$rc = copy( $fullPath, $editDir );
		push( @fileList, $fileName );
	}
	$CONFIG{fileList} = \@fileList;
	logIt( Dumper( \%CONFIG ) );
	return 0;
}
###############################################################################
#   cleanUp
#
#   DESCRIPTION:
#      Cleans up this program.
#
#   RETURN(S):
#       Nothing.
###############################################################################
sub cleanUp()
{
	$CONFIG{date} = "$0 complete: " . perllib::Funcs::getDate();
	logIt($CONFIG{date} . "\n\n\n");
	$CONFIG{funcs}->closeMe() if( defined( $CONFIG{funcs} ) );
}
###############################################################################
#   resetInit()
#
#   DESCRIPTION:
#       Resets the initialization after we get the command line args.
#
#   RETURN(S):
#       Nothing.
###############################################################################
sub resetInit(\%)
{
	my( $myRef )		= @_;
	$CONFIG{log_file}	= $myRef->{'log_file'} if( defined( $myRef->{'log_file'} ) );
	$CONFIG{debug}		= $myRef->{'debug'} if( defined( $myRef->{'debug'} ) );
	$CONFIG{stdout}		= $myRef->{'stdout'} if( defined( $myRef->{'stdout'} ) );
	$CONFIG{config}		= $myRef->{'config'} if( defined( $myRef->{'config'} ) );
	$CONFIG{log_file}	=~ s/\.pl//;
	#$CONFIG{log_file}	.= $env . "_" . $what . "_" . $CONFIG{file_date} . ".log";
	my $funcsObject	= new perllib::Funcs(
							'LOGFILE'		=> $CONFIG{log_file},
							'STDOUTFLAG'	=> $CONFIG{stdout},
							'DEBUG'			=> $CONFIG{debug} 
	);
	$CONFIG{funcs}			= $funcsObject;
	$CONFIG{configObject}	= new perllib::MyConfig( file => $CONFIG{config}, funcs_object => $CONFIG{funcs} );
	if( defined( $CONFIG{configObject} ) )
	{
		if( defined( $myRef->{'parsedir'} ) )
		{
			$CONFIG{parseDir}		= $myRef->{'parsedir'};
		}
		else
		{
			$CONFIG{parseDir}		= $CONFIG{configObject}->getValue( "parsedir" );
		}
		if( !defined( $CONFIG{parseDir} ) )
		{
			logIt( "main::resetInit(): parsedir is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( defined( $myRef->{'origdir'} ) )
		{
			$CONFIG{origDir}		= $myRef->{'origdir'};
		}
		else
		{
			$CONFIG{origDir}		= $CONFIG{configObject}->getValue( "origdir" );
		}
		if( !defined( $CONFIG{origDir} ) )
		{
			logIt( "main::resetInit(): origdir is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( defined( $myRef->{'editdir'} ) )
		{
			$CONFIG{editDir}		= $myRef->{'editdir'};
		}
		else
		{
			$CONFIG{editDir}		= $CONFIG{configObject}->getValue( "editdir" );
		}
		if( !defined( $CONFIG{editDir} ) )
		{
			logIt( "main::resetInit(): editdir is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
	}
	else
	{
		logIt( "main::resetInit(): Unable to retrieve the configuration object for " . $CONFIG{config} . "\n" );
		cleanUp();
		exit( 1 );
	}
}
###############################################################################
#   getCmdOptions
#
#   DESCRIPTION:
#       Gets the command line options for this program.
#
#   RETURN(S):
#       Nothing.
###############################################################################
sub getCmdOptions()
{
	my $href_opts = {};
	my $rc = undef;
	my $program = $0;
	my $usage_string = 
		$program . "\n"  .
		"\t[-parsedir]        -- Directory of java code to parse (optional: default is $CONFIG{parseDir}).\n" .
		"\t[-config]          -- Configuration file (optional: default is $CONFIG{config}).\n" .
		"\t[-log_file]        -- full path name of log of archive directory (optional: default is $CONFIG{log_file}).\n" .
		"\t[-debug]           -- set debug option on.\n" . 
		"\t[-stdout]          -- set standard output flag option on.\n" . 
		"\t[-help]            -- displays the usage.\n" .
		"Example: addcsrf.pl -config ./addcsrf.cfg -stdout\n"; 


	$rc = GetOptions(
				'parsedir=s'		=> \$href_opts->{'parsedir'},
				'config=s'			=> \$href_opts->{'config'},
				'log_file=s'		=> \$href_opts->{'log_file'},
				'debug'				=> \$href_opts->{'debug'},
				'stdout'			=> \$href_opts->{'stdout'},
				'help'				=> \$href_opts->{'help'}
			 );

	my @missing_opts;
	my %opt_display = (
			'parsedir'		=> 'parsedir',
			'config'		=> 'config',
			'log_file'		=> 'log_file',
			'debug'			=> 'debug',
			'stdout'		=> 'stdout',
			'help'			=> 'help'
		);

	if( ( $rc ne 1 ) or ( $href_opts->{'help'} ) )
	{
		print $usage_string, "\n";
		exit(1);
	}
	# Check for required options and notify the user which required options are missing
	#foreach my $option (qw(config))
	#{
	#	push (@missing_opts, $option) unless $href_opts->{$option};
	#}

	(scalar(@missing_opts) > 0) && 
	do 
	{
		my $msg;
		$msg = "$0 Must provide the following command-line options:\n";
		print "Must provide the following command-line options: ";
		foreach my $opt (@missing_opts)
		{
			print "-", $opt_display{$opt}, ' ';
			$msg .= "\t-" . $opt_display{$opt} . "\n";
		}
		print "\n";
		print $usage_string, "\n";
		#die;
		fatalError( $msg );
	};

	resetInit( %$href_opts );
}
################################################################################
#
#   fatalError()
#
#   DESCRIPTION:
#       Initializes things for this application.
#
#   RETURN(S):
#       Nothing.
################################################################################
sub fatalError(;$)
{        
	my ($msg) = @_;

	logIt($msg); 
	#croak();
	cleanUp();
	exit( 1 );
}

################################################################################
#
#   initialize()
#
#   DESCRIPTION:
#       Initializes things for this application.
#
#   RETURN(S):
#       Nothing.
################################################################################
sub initialize()
{
	$|++;    ## forces an fflush(3) after every write or print

	$CONFIG{date}			= perllib::Funcs::getDate();
	$CONFIG{file_date}		= perllib::Funcs::getFileTimeStamp();
	$CONFIG{ret}			= 0;
	$CONFIG{debug}			= 0;
	$CONFIG{stdout}		    = 0;
	$CONFIG{config}			= "./addcsrf.cfg";
	$CONFIG{parseDir}		= "./";
	my $osName = lc( $^O );
	if( $osName =~ m/mswin/ )
	{
		$CONFIG{log_file}		= "c:/temp/" . basename($0);
	}
	elsif( $osName =~ m/cygwin/ )
	{
		$CONFIG{log_file}		= "/cygdrive/c/temp/" . basename($0);
	}
	else
	{
		$CONFIG{log_file}		= "/tmp/" . basename($0);
	}
	$CONFIG{log_file}		=~ s/\.pl//;
	$CONFIG{log_file}		.= ".log";
}

################################################################################
#
#   printVersionInfo()
#
#   DESCRIPTION:
#       Logs the version information about this script.
#
#   RETURN(S):
#       Nothing.
################################################################################
sub printVersionInfo()
{
	my $modDate  = (stat( $0 ))[9]; 
	my $currDate = perllib::Funcs::getDate( $modDate );

	logIt( "Perl Script: $0\n" );
	logIt( "Version Date: $currDate\n" );
}
################################################################################
#
#   printInfo()
#
#   DESCRIPTION:
#       Logs the information about this program.
#
#   RETURN(S):
#       Nothing.
################################################################################
sub printInfo()
{
	############################################################################
	#   Log myself.
	############################################################################
	my $host			= hostname;

	logIt( "Todays date = $CONFIG{date}\n" ); 
	logIt( "$0 Program Started\n" );
	logIt( "        Configuration file is: $CONFIG{config}\n" );
	logIt( "                  Log file is: $CONFIG{log_file}\n" );
	logIt( "               Stdout flag is: on\n" ) if( $CONFIG{stdout} );
	logIt( "               Stdout flag is: off\n" ) if( !$CONFIG{stdout} );
	logIt( "                Debug flag is: on\n" ) if( $CONFIG{debug} );
	logIt( "                Debug flag is: off\n" ) if( !$CONFIG{debug} );
	logIt( "\n" );
	printCONFIG() if( $CONFIG{debug} >= 1);
}
################################################################################
#
#   printCONFIG()
#
#   DESCRIPTION:
#       Logs the CONFIG hash for this program.
#
#   RETURN(S):
#       Nothing.
################################################################################
sub printCONFIG()
{
	my( $value );
	my( $key );
	logIt( "\nBegin contents of the CONFIG hash.\n" );
	#logIt( Dumper( \%CONFIG ) );
	if( 1 )
	{
	foreach $key (sort keys %CONFIG) 
	{
		logIt( "$key = $CONFIG{$key}\n" ) if( $key ne "ccb_pwd"  && $key ne "oubi_pwd" );
		#logIt( "$key = $CONFIG{$key}\n" );
	}
	}
	logIt( "\nEnd contents of the CONFIG hash.\n" );
}
################################################################################
#
#   logIt()
#
#   DESCRIPTION:
#       Logs the the message.
#
#   RETURN(S):
#       Nothing.
################################################################################
sub logIt(;$)
{
	my( $msg ) = @_;

	if( defined( $CONFIG{funcs} ) )
	{
		$CONFIG{funcs}->logIt( $msg );
	}
	else
	{
		print $msg;
	}
}
################################################################################
#
#   debug()
#
#   DESCRIPTION:
#       Logs the the message.
#
#   RETURN(S):
#       Nothing.
################################################################################
sub debug(;$)
{
	my( $msg ) = @_;

	return if( $CONFIG{debug} == 0 );
	logIt( $msg );
}
###################################
#   End subroutine section.
###################################
