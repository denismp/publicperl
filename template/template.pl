#!/usr/bin/env perl
############################################################################
##	template.pl
##  Perl script to check the CI_CHG_LOG table.
##
## Sample parameter file:  See perllib::MyConfig.pm.
############################################################################
##
##  MODIFICATION HISTORY:
##  DATE        WHOM                DESCRIPTION
##  07/31/2011  Denis M. Putnam     Created.
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
use File::Path qw(mkpath rmtree);
use perllib::MyOracle;
use perllib::Command;
use perllib::MyConfig;
use perllib::RptChangeLog;
use perllib::RptCheckView;
use perllib::RptDiffView;
use perllib::MyMimeEmail;
use Sys::Hostname;
use Excel::Writer::XLSX;

##################################
#	Function forward declarations
##################################
sub initialize();
sub getCmdOptions();
sub resetInit(\%);
sub printVersionInfo();
sub doWork();
sub cleanUp();
sub dbConnect();
sub getData();
sub joinData($$$);
sub getSearchColumnsHash();
sub getCCBReturnColumnsHash();
sub getOUBIReturnColumnsHash();
sub writeChangeLogData($);
sub writeViewData($$);
sub writeCCBOrClause($);
sub writeOUBIOrClause($);
sub writeQuery($$);
sub writeInfo();
sub getBatchNbr();

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
#   dbConnect()
#
#   DESCRIPTION:
#       Connects to the two databases.
#
#   RETURN(S):
#		0 if successfull or non-zero.
###############################################################################
sub dbConnect()
{
	my $rc = 0;
	my $rptObject = new perllib::MyOracle( 
								sid				=> $CONFIG{rpt_sid},
								user			=> $CONFIG{rpt_user},
								pwd 			=> $CONFIG{rpt_pwd},
								autocommit		=> 1,
								trace_level 	=> 0,
								funcs_object	=> $CONFIG{funcs}
	);
	if( !defined( $rptObject ) )
	{
		logIt( "main::dbConnect(): new perllib::MyOracle() failed for RPT:" . $CONFIG{rpt_sid} . "\n" );
		return 1;
	}
	else
	{
		$CONFIG{rpt_pwd} = undef;
		logIt( "main::dbConnect(): new perllib::MyOracle() succeeded for RPT." . $CONFIG{rpt_sid} . "\n" );
		$CONFIG{rptObject} = $rptObject;
	}
	my $ccbObject = new perllib::MyOracle( 
								sid				=> $CONFIG{ccb_sid},
								user			=> $CONFIG{ccb_user},
								pwd 			=> $CONFIG{ccb_pwd},
								autocommit		=> 1,
								trace_level 	=> 0,
								funcs_object	=> $CONFIG{funcs}
	);
	if( !defined( $ccbObject ) )
	{
		logIt( "main::dbConnect(): new perllib::MyOracle() failed for CCB:" . $CONFIG{ccb_sid} . "\n" );
		return 2;
	}
	else
	{
		$CONFIG{ccb_pwd} = undef;
		logIt( "main::dbConnect(): new perllib::MyOracle() succeeded for CCB." . $CONFIG{ccb_sid} . "\n" );
		$CONFIG{ccbObject} = $ccbObject;
	}
	my $oubiObject = new perllib::MyOracle( 
								sid				=> $CONFIG{oubi_sid},
								user			=> $CONFIG{oubi_user},
								pwd 			=> $CONFIG{oubi_pwd},
								autocommit		=> 1,
								trace_level 	=> 0,
								funcs_object	=> $CONFIG{funcs}
	);
	if( !defined( $oubiObject ) )
	{
		logIt( "main::dbConnect(): new perllib::MyOracle() failed for OUBI:" . $CONFIG{oubi_sid} . "\n" );
		return 3;
	}
	else
	{
		$CONFIG{oubi_pwd} = undef;
		logIt( "main::dbConnect(): new perllib::MyOracle() succeeded for OUBI." . $CONFIG{oubi_sid} . "\n" );
		$CONFIG{oubiObject} = $oubiObject;
	}
	return $rc;
}
###############################################################################
#   writeChangeLogData()
#
#   DESCRIPTION:
#       Write the data
#
#   RETURN(S):
#       0 for success.
###############################################################################
sub writeChangeLogData($)
{
	my( $chgLogObject ) = @_;
	my $rc				= 0;
	return 0 if( !defined( $chgLogObject ) );
	if( defined( $CONFIG{workbook} ) )
	{
		my $sheetName	= "CHG_LOG";
		my $worksheet	= $CONFIG{workbook}->add_worksheet( $sheetName );

		my @results = $chgLogObject->getResults();
		my @columns = $chgLogObject->getColumnNames();
		my $cindex	= 0;
		foreach my $col ( @columns )
		{
			$worksheet->write( 0, $cindex, $col );
			$cindex++;
		}
		$cindex	= 0;
		my $rindex = 1;
		foreach my $row ( @results )
		{
			foreach my $col ( @{$row} )
			{
				$col = "UNDEFINED" if( !defined( $col ) || $col eq "" );
				$worksheet->write( $rindex, $cindex, $col );
				$cindex++;
			}
			$cindex = 0;
			$rindex++;
		}
		$worksheet->autofilter( 0, 0, 0, scalar( @columns ) - 1 );
		$worksheet->freeze_panes( 1, 0 );

	}
	else
	{
		logIt( "main::writeChangeLogData(): The workbook has not been created.\n" );
		return 1;
	}
	return $rc;
}
###############################################################################
#   writeQuery()
#
#   DESCRIPTION:
#       Write the or clause.
#
#   RETURN(S):
#       0 for success.
###############################################################################
sub writeQuery($$)
{
	my ( $dataObject, $view_name )	= @_;
	my $rc							= 0;

	return 0 if( !defined( $dataObject ) );
	if( defined( $CONFIG{workbook} ) )
	{
		my $query		= $dataObject->getFullQuery();

		my $sheetName	= "SQL" . basename( $view_name );
		my $columnName	= "QUERY";
		my $worksheet	= $CONFIG{workbook}->add_worksheet( $sheetName );

		$worksheet->write( 0, 0, $columnName );
		my $rindex	= 1;
		my @results	= split( /\n/, $query );
		foreach my $row ( @results )
		{
			$worksheet->write( $rindex, 0, $row );
			
			$rindex++;
		}

		$worksheet->autofilter( 0, 0, 0, 0 );
		$worksheet->freeze_panes( 1, 0 );
	}
	else
	{
		logIt( "main::writeQuery(): The workbook has not been created.\n" );
		return 1;
	}
	return $rc;
}
###############################################################################
#   writeCCBOrClause()
#
#   DESCRIPTION:
#       Write the or clause.
#
#   RETURN(S):
#       0 for success.
###############################################################################
sub writeCCBOrClause($)
{
	my ( $chgLogObject )	= @_;
	my $rc					= 0;

	return 0 if( !defined( $chgLogObject ) );

	if( defined( $CONFIG{workbook} ) )
	{
		my $or_clause = $chgLogObject->getCCBOrClause();

		my $sheetName	= "CCB_OR_CLAUSE";
		my $columnName	= "OR_CLAUSE";
		my $worksheet	= $CONFIG{workbook}->add_worksheet( $sheetName );
		$worksheet->write( 0, 0, $columnName );

		my $rindex	= 1;
		my @results	= split( /\n/, $or_clause );
		foreach my $row ( @results )
		{
			$worksheet->write( $rindex, 0, $row );
			
			$rindex++;
		}
		$worksheet->autofilter( 0, 0, 0, 0 );
		$worksheet->freeze_panes( 1, 0 );
	}
	else
	{
		logIt( "main::writeCCBOrClause(): The workbook has not been created.\n" );
		return 1;
	}
	return $rc;
}
###############################################################################
#   writeOUBIOrClause()
#
#   DESCRIPTION:
#       Write the or clause.
#
#   RETURN(S):
#       0 for success.
###############################################################################
sub writeOUBIOrClause($)
{
	my ( $chgLogObject )	= @_;
	my $rc					= 0;

	return 0 if( !defined( $chgLogObject ) );
	if( defined( $CONFIG{workbook} ) )
	{
		my $or_clause = $chgLogObject->getOUBIOrClause();

		my $sheetName	= "OUBI_OR_CLAUSE";
		my $columnName	= "OR_CLAUSE";
		my $worksheet	= $CONFIG{workbook}->add_worksheet( $sheetName );
		$worksheet->write( 0, 0, $columnName );

		my $rindex	= 1;
		my @results	= split( /\n/, $or_clause );
		foreach my $row ( @results )
		{
			$worksheet->write( $rindex, 0, $row );
			
			$rindex++;
		}
		$worksheet->autofilter( 0, 0, 0, 0 );
		$worksheet->freeze_panes( 1, 0 );
	}
	else
	{
		logIt( "main::writeOUBIOrClause(): The workbook has not been created.\n" );
		return 1;
	}
	return $rc;
}
###############################################################################
#   writeInfo()
#
#   DESCRIPTION:
#       Write the execution information.
#
#   RETURN(S):
#       0 for success.
###############################################################################
sub writeInfo()
{
	my $rc					= 0;

	if( defined( $CONFIG{workbook} ) )
	{
		my $ostr		= "";

		my $sheetName	= "EXECUTION_INFO";
		my $columnName	= "EXECUTION_INFO";
		my $worksheet	= $CONFIG{workbook}->add_worksheet( $sheetName );
		$worksheet->write( 0, 0, $columnName );
		my $rindex	= 1;
		$ostr = "Todays date = $CONFIG{date}\n"; 
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "        Configuration file is: $CONFIG{config}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "               Query limit is: $CONFIG{limit}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "                       Env is: $CONFIG{env}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "                   CCB sid is: $CONFIG{ccb_sid}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "                  OUBI sid is: $CONFIG{oubi_sid}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "                  CCB view is: $CONFIG{ccb_view}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "                 OUBI view is: $CONFIG{oubi_view}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "                 DIFF view is: $CONFIG{diff_view}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "          CCB report table is: $CONFIG{ccb_table}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "         OUBI report table is: $CONFIG{oubi_table}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "         DIFF report table is: $CONFIG{diff_table}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "    CCB primary key column is: $CONFIG{ccb_pk_column}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "   OUBI primary key column is: $CONFIG{oubi_pk_column}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "                  Batch id is: $CONFIG{batch_id}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "              Batch number is: $CONFIG{batch_nbr}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "             Change log id is: $CONFIG{chg_log_id}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		if( defined( $CONFIG{search_columns} ) )
		{
			$ostr = "            Search columns is: $CONFIG{search_columns}\n";
			$worksheet->write( $rindex++, 0, $ostr );
		}
		if( defined( $CONFIG{return_columns} ) )
		{
			$ostr = "            Return columns is: $CONFIG{return_columns}\n";
			$worksheet->write( $rindex++, 0, $ostr );
		}
		$ostr = "               Output file is: $CONFIG{file}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "                  Email to is: $CONFIG{email_to}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "                Email from is: $CONFIG{email_from}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "                  Log file is: $CONFIG{log_file}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "     Email attachment type is: $CONFIG{email_attachment_type}\n";
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "               Stdout flag is: on\n"  if( $CONFIG{stdout} );
		$ostr = "               Stdout flag is: off\n" if( !$CONFIG{stdout} );
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "                Debug flag is: on\n"  if( $CONFIG{debug} );
		$ostr = "                Debug flag is: off\n"  if( !$CONFIG{debug} );
		$worksheet->write( $rindex++, 0, $ostr );
		$ostr = "\n";
		$worksheet->write( $rindex++, 0, $ostr );

		$worksheet->autofilter( 0, 0, 0, 0 );
		$worksheet->freeze_panes( 1, 0 );
	}
	else
	{
		logIt( "main::writeInfo(): The workbook has not been created.\n" );
		return 1;
	}
	return $rc;
}
###############################################################################
#   writeViewData()
#
#   DESCRIPTION:
#       Write the data
#
#   RETURN(S):
#       0 for success.
###############################################################################
sub writeViewData($$)
{
	my ( $dataObject, $viewName ) = @_;
	my $rc			= 0;

	return 0 if( !defined( $dataObject ) );
	if( defined( $dataObject ) )
	{
		if( defined( $CONFIG{workbook} ) )
		{
			my @results = $dataObject->getResults();
			my @columns = $dataObject->getColumnNames();

			my $sheetName	= basename( $viewName );
			my $worksheet	= $CONFIG{workbook}->add_worksheet( $sheetName );

			my $cindex	= 0;
			foreach my $col ( @columns )
			{
				$worksheet->write( 0, $cindex, $col );
				$cindex++;
			}
			$cindex	= 0;
			my $rindex = 1;
			foreach my $row ( @results )
			{
				foreach my $col ( @{$row} )
				{
					$col = "UNDEFINED" if( !defined( $col ) || $col eq "" );
					$worksheet->write( $rindex, $cindex, $col );
					$cindex++;
				}
				$cindex = 0;
				$rindex++;
			}
			$worksheet->autofilter( 0, 0, 0, scalar( @columns ) - 1 );
			$worksheet->freeze_panes( 1, 0 );
		}
		else
		{
			logIt( "main::writeViewData(): The workbook has not been created.\n" );
			return 1;
		}
	}
	return $rc;
}
###############################################################################
#   getSearchColumnsHash()
#
#   DESCRIPTION:
#       Get the search column hash.
#
#   RETURN(S):
#       $href.
###############################################################################
sub getSearchColumnsHash()
{
	my $columnsString	= $CONFIG{search_columns};
	if( !defined( $columnsString) || $columnsString eq "" )
	{
		return undef;
	}
	my @tokens			= split( /\|/, $columnsString );
	my %h;
	foreach my $token ( @tokens )
	{
		my( $columnName, $value ) = split( /=/, $token );
		$h{$columnName} = $value;
	}
	return \%h;
}
###############################################################################
#   getCCBReturnColumnsHash()
#
#   DESCRIPTION:
#       Get the return column hash.
#
#   RETURN(S):
#       $href.
###############################################################################
sub getCCBReturnColumnsHash()
{
	my $columnsString	= $CONFIG{ccb_return_columns};
	if( $columnsString eq "" )
	{
		return undef;
	}
	my @tokens			= split( /\|/, $columnsString );
	my %h;
	foreach my $token ( @tokens )
	{
		my( $columnName, $value ) = split( /=/, $token );
		$h{$columnName} = $value;
	}
	return \%h;
}
###############################################################################
#   getOUBIReturnColumnsHash()
#
#   DESCRIPTION:
#       Get the return column hash.
#
#   RETURN(S):
#       $href.
###############################################################################
sub getOUBIReturnColumnsHash()
{
	my $columnsString	= $CONFIG{oubi_return_columns};
	if( $columnsString eq "" )
	{
		return undef;
	}
	my @tokens			= split( /\|/, $columnsString );
	my %h;
	foreach my $token ( @tokens )
	{
		my( $columnName, $value ) = split( /=/, $token );
		$h{$columnName} = $value;
	}
	return \%h;
}
###############################################################################
#   getData()
#
#   DESCRIPTION:
#       Test
#
#   RETURN(S):
#       @results
###############################################################################
sub getData()
{
	my $rc = 0;

	my $sColumns	= getSearchColumnsHash();
	my $rCCBColumns	= getCCBReturnColumnsHash();
	my $rOUBIColumns= getOUBIReturnColumnsHash();
	$CONFIG{batch_nbr} = getBatchNbr();
	if( !defined( $CONFIG{batch_nbr} ) || $CONFIG{batch_nbr} eq "" )
	{
		logIt( "main::getData(): Failed to get the batch_nbr.  This usually indicates that there were no incremental loads completed.\n" );
		return 1;
	}
	my $chgLogObject = new perllib::RptChangeLog(
										env 			=> $CONFIG{env},
										batch_cd 		=> $CONFIG{batch_id},
										batch_nbr		=> $CONFIG{batch_nbr},
										search_columns	=> $sColumns,
										ccb_return_columns	=> $rCCBColumns,
										oubi_return_columns	=> $rOUBIColumns,
										chg_log_id		=> $CONFIG{chg_log_id},
										start_date		=> $CONFIG{start_date},
										ext_dir			=> $CONFIG{ext_dir},
										ccbObject		=> $CONFIG{ccbObject},
										rptObject		=> $CONFIG{rptObject},
										limit			=> $CONFIG{limit},
										funcs_object	=> $CONFIG{funcs}
	);
	if( !defined( $chgLogObject ) )
	{
		logIt( "main::getData(): Failed to instantiate perllib::CCBChgLog\n" );
		#return 1;
	}
	my $ccb_or_clause = $chgLogObject->getCCBOrClause();
	my $vcObject;
	if( defined( $ccb_or_clause ) && $ccb_or_clause ne "" )
	{
		$vcObject = new perllib::RptCheckView(
										env 			=> $CONFIG{env},
										view			=> $CONFIG{ccb_view},
										table			=> $CONFIG{ccb_table},
										#pk_name			=> $CONFIG{ccb_pk_column},
										#pk_val			=> $CONFIG{pk_val},
										start_date_column => $CONFIG{ccb_start_column},
										start_date		=> $CONFIG{start_date},
										end_date_column => $CONFIG{ccb_end_column},
										end_date		=> $CONFIG{end_date},
										or_clause		=> $ccb_or_clause,
										ext_dir			=> $CONFIG{ext_dir},
										view_dir		=> $CONFIG{sql_dir},
										dbObject		=> $CONFIG{ccbObject},
										rptObject		=> $CONFIG{rptObject},
										funcs_object	=> $CONFIG{funcs}
		);
		if( !defined( $vcObject ) )
		{
			logIt( "main::getData(): Failed to instantiate perllib::VCheckView for " . $CONFIG{ccb_view} . "\n" );
			#return 2;
		}
	}
	else
	{
		logIt( "main::getData(): No source keys found in " . $CONFIG{ccb_view} . "\n" );
	}
	my $oubi_or_clause = $chgLogObject->getOUBIOrClause();
	my $bcObject;
	if( defined( $oubi_or_clause ) && $oubi_or_clause ne "" )
	{
		$bcObject = new perllib::RptCheckView(
										env 			=> $CONFIG{env},
										view			=> $CONFIG{oubi_view},
										table			=> $CONFIG{oubi_table},
										#pk_name			=> $CONFIG{oubi_pk_column},
										#pk_val			=> $CONFIG{pk_val},
										start_date_column => $CONFIG{oubi_start_column},
										#start_date		=> $CONFIG{start_date},
										end_date_column => $CONFIG{oubi_end_column},
										#end_date		=> $CONFIG{end_date},
										or_clause		=> $oubi_or_clause,
										ext_dir			=> $CONFIG{ext_dir},
										view_dir		=> $CONFIG{sql_dir},
										dbObject		=> $CONFIG{oubiObject},
										rptObject		=> $CONFIG{rptObject},
										funcs_object	=> $CONFIG{funcs}
		);
		if( !defined( $bcObject ) )
		{
			logIt( "main::getData(): Failed to instantiate perllib::VCheckView for " . $CONFIG{oubi_view} . "\n" );
			#return 3;
		}
	}
	else
	{
		logIt( "main::getData(): No source keys found in " . $CONFIG{oubi_view} . "\n" );
	}

	my $diffObject;
	if( defined( $vcObject ) && defined( $bcObject ) )
	{
		$diffObject = new perllib::RptDiffView(
										env 			=> $CONFIG{env},
										view			=> $CONFIG{diff_view},
										table			=> $CONFIG{diff_table},
										vc_table		=> $CONFIG{ccb_table},
										vb_table		=> $CONFIG{oubi_table},
										ext_dir			=> $CONFIG{ext_dir},
										view_dir		=> $CONFIG{sql_dir},
										rptObject		=> $CONFIG{rptObject},
										funcs_object	=> $CONFIG{funcs}
		);
		if( !defined( $diffObject ) )
		{
			logIt( "main::getData(): Failed to instantiate perllib::RptDiffView for " . $CONFIG{diff_view} . "\n" );
			#return 4;
		}
	}
	else
	{
		logIt( "main::getData(): No source keys found in the ci_chg_log for " . $CONFIG{batch_id} . "\n" );
	}
	$CONFIG{workbook}	= Excel::Writer::XLSX->new( $CONFIG{file} );
	writeViewData( $diffObject, $CONFIG{diff_view} );
	writeChangeLogData( $chgLogObject );
	writeViewData( $vcObject, $CONFIG{ccb_view} );
	writeViewData( $bcObject, $CONFIG{oubi_view} );
	writeCCBOrClause( $chgLogObject );
	writeOUBIOrClause( $chgLogObject );
	writeQuery( $chgLogObject, "CHG_LOG_VW"  );
	writeQuery( $diffObject, "DIFF_VW"  );
	writeQuery( $vcObject, $CONFIG{ccb_view} );
	writeQuery( $bcObject, $CONFIG{oubi_view} );
	writeInfo();
	$CONFIG{workbook}->close() if( defined( $CONFIG{workbook} ) );

	return $rc;
}
###############################################################################
#   sendMail()
#
#   DESCRIPTION:
#       Send email attachment.
#
#   RETURN(S):
#       Nothing.
###############################################################################
sub sendMail()
{
	my $rc = 0;
	my $subject = $CONFIG{batch_id} . " change log validation.";
	my $message = "Change log validation for the " . $CONFIG{batch_id} . " " . $CONFIG{config};
	my $mailObject = new perllib::MyMimeEmail(
									from_address	=> $CONFIG{email_from},
									to_address		=> $CONFIG{email_to},
									subject			=> $subject,
									message			=> $message,
									attachment		=> $CONFIG{file},
									attach_type		=> $CONFIG{email_attachment_type},
									funcs_object	=> $CONFIG{funcs}
	);
	if( defined( $mailObject ) )
	{
		$mailObject->send();
	}
	else
	{
		logIt( "main::sendMail(): Failed to instantiate the perllib::MyMimeEmail object.\n" );
		return 1
	}
	return $rc;
}
###############################################################################
#   getBatchNbr()
#
#   DESCRIPTION:
#       Get the current batch_nbr from OUBI.
#
#   RETURN(S):
#       $batchNbr.
###############################################################################
sub getBatchNbr()
{
	my $batchNbr = "";
	#$CONFIG{oubiObject}->closeMe() if( defined( $CONFIG{oubiObject} ) );
	my $sql = "
	SELECT MAX(job_nbr),
	  batch_nbr,
	  batch_cd
	FROM dwadm.b1_etl_job_ctrl
	WHERE trim( batch_cd ) = '" . $CONFIG{batch_id} . "'
	AND batch_nbr  < 9999999
	GROUP BY BATCH_CD,
	  DATA_SOURCE_IND,
	  BATCH_NBR,
	  BATCH_THREAD_NBR,
	  JOB_STATUS_FLG,
	  START_DTTM,
	  END_DTTM,
	  DESCR,
	  VERSION,
	  DAT_REC_CNT,
	  LOAD_REC_CNT,
	  LOAD_ERROR_CNT,
	  LOAD_AUDIT_ID,
	  ETL_MAP_NAME
	";
	my @results = $CONFIG{oubiObject}->doQuery( "main::getBatchNbr():", $sql );
	foreach my $row ( @results )
	{
		$batchNbr = $row->[1];
	}
	return $batchNbr;

}
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

	$rc = dbConnect();
	$rc = getData() if( ! $rc );
	sendMail();

	return $rc;
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
	$CONFIG{rptObject}->closeMe() if( defined( $CONFIG{rptObject} ) );
	$CONFIG{ccbObject}->closeMe() if( defined( $CONFIG{ccbObject} ) );
	$CONFIG{oubiObject}->closeMe() if( defined( $CONFIG{oubiObject} ) );
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
	$CONFIG{connect}	= $myRef->{'connect'} if( defined( $myRef->{'connect'} ) );
	#$CONFIG{batch_id}	= $myRef->{'batch_id'} if( defined( $myRef->{'batch_id'} ) );
	$CONFIG{pk_val}		= $myRef->{'pk_val'} if( defined( $myRef->{'pk_val'} ) );
	$CONFIG{file}		= $myRef->{'file'} if( defined( $myRef->{'file'} ) );
	$CONFIG{limit}		= $myRef->{'limit'} if( defined( $myRef->{'limit'} ) );
	my $env				= basename( $CONFIG{connect} );
	my $what			= basename( $CONFIG{config} );
	$env				=~ s/\.cfg$//;
	$what				=~ s/\.cfg$//;
	$CONFIG{log_file}	=~ s/\.pl//;
	$CONFIG{log_file}	.= $env . "_" . $what . "_" . $CONFIG{file_date} . ".log";
	my $funcsObject	= new perllib::Funcs(
							'LOGFILE'		=> $CONFIG{log_file},
							'STDOUTFLAG'	=> $CONFIG{stdout},
							'DEBUG'			=> $CONFIG{debug} 
	);
	$CONFIG{funcs}			= $funcsObject;
	$CONFIG{connectObject}	= new perllib::MyConfig( file => $CONFIG{connect}, funcs_object => $CONFIG{funcs} );
	if( defined( $CONFIG{connectObject} ) )
	{
		if( defined( $myRef->{'env'} ) )
		{
			$CONFIG{env}		= $myRef->{'env'};
		}
		else
		{
			$CONFIG{env}		= $CONFIG{connectObject}->getValue( "ENV" );
		}
		if( !defined( $CONFIG{env} ) )
		{
			logIt( "main::resetInit(): env is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		else
		{
			my $file = $CONFIG{file};
			$file	=~ s/\.xlsx$//;
			$file	= $file . "_" . $CONFIG{env} . ".xlsx";
			$CONFIG{file} = $file;
		}
		if( defined( $myRef->{'rpt_sid'} ) )
		{
			$CONFIG{rpt_sid}		= $myRef->{'rpt_sid'};
		}
		else
		{
			$CONFIG{rpt_sid}		= $CONFIG{connectObject}->getValue( "RPT_DB_NAME" );
		}
		if( defined( $myRef->{'rpt_user'} ) )
		{
			$CONFIG{rpt_user}		= $myRef->{'rpt_user'};
		}
		else
		{
			$CONFIG{rpt_user}		= $CONFIG{connectObject}->getValue( "RPT_DB_USERNAME" );
		}
		if( defined( $myRef->{'rpt_pwd'} ) )
		{
			$CONFIG{rpt_pwd}		= $myRef->{'rpt_pwd'};
		}
		else
		{
			$CONFIG{rpt_pwd}		= $CONFIG{connectObject}->getValue( "RPT_DB_PASSWORD" );
		}
		if( !defined( $CONFIG{rpt_sid} ) )
		{
			logIt( "main::resetInit(): rpt_sid is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( !defined( $CONFIG{rpt_user} ) )
		{
			logIt( "main::resetInit(): rpt_user is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( !defined( $CONFIG{rpt_pwd} ) )
		{
			logIt( "main::resetInit(): rpt_pwd is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( defined( $myRef->{'ccb_sid'} ) )
		{
			$CONFIG{ccb_sid}		= $myRef->{'ccb_sid'};
		}
		else
		{
			$CONFIG{ccb_sid}		= $CONFIG{connectObject}->getValue( "CCB_DB_NAME" );
		}
		if( defined( $myRef->{'ccb_user'} ) )
		{
			$CONFIG{ccb_user}		= $myRef->{'ccb_user'};
		}
		else
		{
			$CONFIG{ccb_user}		= $CONFIG{connectObject}->getValue( "CCB_DB_USERNAME" );
		}
		if( defined( $myRef->{'ccb_pwd'} ) )
		{
			$CONFIG{ccb_pwd}		= $myRef->{'ccb_pwd'};
		}
		else
		{
			$CONFIG{ccb_pwd}		= $CONFIG{connectObject}->getValue( "CCB_DB_PASSWORD" );
		}
		if( !defined( $CONFIG{ccb_sid} ) )
		{
			logIt( "main::resetInit(): ccb_sid is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( !defined( $CONFIG{ccb_user} ) )
		{
			logIt( "main::resetInit(): ccb_user is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( !defined( $CONFIG{ccb_pwd} ) )
		{
			logIt( "main::resetInit(): ccb_pwd is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( defined( $myRef->{'oubi_sid'} ) )
		{
			$CONFIG{oubi_sid}		= $myRef->{'oubi_sid'};
		}
		else
		{
			$CONFIG{oubi_sid}		= $CONFIG{connectObject}->getValue( "OUBI_DB_NAME" );
		}
		if( defined( $myRef->{'oubi_user'} ) )
		{
			$CONFIG{oubi_user}		= $myRef->{'oubi_user'};
		}
		else
		{
			$CONFIG{oubi_user}		= $CONFIG{connectObject}->getValue( "OUBI_DB_USERNAME" );
		}
		if( defined( $myRef->{'oubi_pwd'} ) )
		{
			$CONFIG{oubi_pwd}		= $myRef->{'oubi_pwd'};
		}
		else
		{
			$CONFIG{oubi_pwd}		= $CONFIG{connectObject}->getValue( "OUBI_DB_PASSWORD" );
		}
		if( !defined( $CONFIG{oubi_sid} ) )
		{
			logIt( "main::resetInit(): oubi_sid is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( !defined( $CONFIG{oubi_user} ) )
		{
			logIt( "main::resetInit(): oubi_user is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( !defined( $CONFIG{oubi_pwd} ) )
		{
			logIt( "main::resetInit(): oubi_pwd is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( defined( $myRef->{'email_to'} ) )
		{
			$CONFIG{email_to}	= $myRef->{'email_to'};
		}
		else
		{
			my $email_to		= $CONFIG{connectObject}->getValue( "EMAIL_TO" );
			if( defined( $email_to ) && $email_to ne "" )
			{
				$email_to			=~ s/\|/ /g;
				$CONFIG{email_to}	= $email_to;
			}
			else
			{
				logIt( "main::resetInit(): email_to is not defined.\n" );
				cleanUp();
				exit( 1 );
			}
		}
		if( defined( $myRef->{'email_from'} ) )
		{
			$CONFIG{email_from}	= $myRef->{'email_from'};
		}
		else
		{
			my $email_from		= $CONFIG{connectObject}->getValue( "EMAIL_FROM" );
			if( defined( $email_from ) && $email_from ne "" )
			{
				$CONFIG{email_from}	= $email_from;
			}
			else
			{
				logIt( "main::resetInit(): email_from is not defined.\n" );
				cleanUp();
				exit( 1 );
			}
		}
		if( defined( $myRef->{'email_attachment_type'} ) )
		{
			$CONFIG{email_attachment_type}	= $myRef->{'email_attachment_type'};
		}
		else
		{
			my $email_attachment_type		= $CONFIG{connectObject}->getValue( "EMAIL_ATTACHMENT_TYPE" );
			if( defined( $email_attachment_type ) && $email_attachment_type ne "" )
			{
				$CONFIG{email_attachment_type}	= $email_attachment_type;
			}
			else
			{
				logIt( "main::resetInit(): email_attachment_type is not defined.\n" );
				cleanUp();
				exit( 1 );
			}
		}
	}
	else
	{
		logIt( "main::resetInit(): Unable to retrieve the ETL configuration object for " . $CONFIG{connect} . "\n" );
		cleanUp();
		exit( 1 );
	}
	$CONFIG{configObject}	= new perllib::MyConfig( file => $CONFIG{config}, funcs_object => $CONFIG{funcs} );
	if( defined( $CONFIG{configObject} ) )
	{
		if( defined( $myRef->{'batch_id'} ) )
		{
			$CONFIG{batch_id}		= $myRef->{'batch_id'};
		}
		else
		{
			$CONFIG{batch_id}		= $CONFIG{configObject}->getValue( "BATCH_CD" );
		}
		if( !defined( $CONFIG{batch_id} ) )
		{
			logIt( "main::resetInit(): batch_id is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( defined( $myRef->{'search_columns'} ) )
		{
			$CONFIG{search_columns}	= $myRef->{'search_columns'};
		}
		else
		{
			my $search_columns		= $CONFIG{configObject}->getValue( "SEARCH_COLUMNS" );
			if( defined( $search_columns ) && $search_columns ne "" )
			{
				$search_columns			=~ s/\,/=/g;
				$CONFIG{search_columns}	= $search_columns;
			}
			else
			{
				$CONFIG{search_columns}	= "";
			}
		}
		if( defined( $myRef->{'ccb_return_columns'} ) )
		{
			$CONFIG{ccb_return_columns}	= $myRef->{'ccb_return_columns'};
		}
		else
		{
			my $return_columns		= $CONFIG{configObject}->getValue( "CCB_RETURN_COLUMNS" );
			$return_columns			=~ s/\,/=/g;
			$CONFIG{ccb_return_columns}	= $return_columns;
		}
		if( !defined( $CONFIG{ccb_return_columns} ) )
		{
			logIt( "main::resetInit(): ccb_return_columns is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( defined( $myRef->{'oubi_return_columns'} ) )
		{
			$CONFIG{oubi_return_columns}	= $myRef->{'oubi_return_columns'};
		}
		else
		{
			my $return_columns		= $CONFIG{configObject}->getValue( "OUBI_RETURN_COLUMNS" );
			$return_columns			=~ s/\,/=/g;
			$CONFIG{oubi_return_columns}	= $return_columns;
		}
		if( !defined( $CONFIG{oubi_return_columns} ) )
		{
			logIt( "main::resetInit(): oubi_return_columns is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( !defined( $CONFIG{oubi_user} ) )
		{
			logIt( "main::resetInit(): oubi_user is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( !defined( $CONFIG{oubi_pwd} ) )
		{
			logIt( "main::resetInit(): oubi_pwd is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( defined( $myRef->{'ccb_view'} ) )
		{
			$CONFIG{ccb_view}		= $myRef->{'ccb_view'};
		}
		else
		{
			$CONFIG{ccb_view}		= $CONFIG{configObject}->getValue( "CCB_VIEW" );
		}
		if( !defined( $CONFIG{ccb_view} ) )
		{
			logIt( "main::resetInit(): ccb_view is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( defined( $myRef->{'ccb_table'} ) )
		{
			$CONFIG{ccb_table}		= $myRef->{'ccb_table'};
		}
		else
		{
			$CONFIG{ccb_table}		= $CONFIG{configObject}->getValue( "CCB_TABLE" );
		}
		if( !defined( $CONFIG{ccb_table} ) )
		{
			logIt( "main::resetInit(): ccb_table is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( defined( $myRef->{'ccb_pk_column'} ) )
		{
			$CONFIG{ccb_pk_column}		= $myRef->{'ccb_pk_column'};
		}
		else
		{
			$CONFIG{ccb_pk_column}		= $CONFIG{configObject}->getValue( "CCB_PK_COLUMN" );
		}
		if( !defined( $CONFIG{ccb_pk_column} ) )
		{
			$CONFIG{ccb_pk_column} = "";
		#	logIt( "main::resetInit(): ccb_pk_column is not defined.\n" );
		#	cleanUp();
		#	exit( 1 );
		}
		if( defined( $myRef->{'ccb_start_column'} ) )
		{
			$CONFIG{ccb_start_column}		= $myRef->{'ccb_start_column'};
		}
		else
		{
			$CONFIG{ccb_start_column}		= $CONFIG{configObject}->getValue( "CCB_START_COLUMN" );
		}
		if( !defined( $CONFIG{ccb_start_column} ) )
		{
			$CONFIG{ccb_start_column} = "";
		#	logIt( "main::resetInit(): ccb_start_column is not defined.\n" );
		#	cleanUp();
		#	exit( 1 );
		}
		if( defined( $myRef->{'ccb_end_column'} ) )
		{
			$CONFIG{ccb_end_column}		= $myRef->{'ccb_end_column'};
		}
		else
		{
			$CONFIG{ccb_end_column}		= $CONFIG{configObject}->getValue( "CCB_END_COLUMN" );
		}
		if( !defined( $CONFIG{ccb_end_column} ) )
		{
			$CONFIG{ccb_end_column} = "";
		#	logIt( "main::resetInit(): ccb_end_column is not defined.\n" );
		#	cleanUp();
		#	exit( 1 );
		}
		if( defined( $myRef->{'oubi_view'} ) )
		{
			$CONFIG{oubi_view}		= $myRef->{'oubi_view'};
		}
		else
		{
			$CONFIG{oubi_view}		= $CONFIG{configObject}->getValue( "OUBI_VIEW" );
		}
		if( !defined( $CONFIG{oubi_view} ) )
		{
			logIt( "main::resetInit(): oubi_view is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( defined( $myRef->{'oubi_table'} ) )
		{
			$CONFIG{oubi_table}		= $myRef->{'oubi_table'};
		}
		else
		{
			$CONFIG{oubi_table}		= $CONFIG{configObject}->getValue( "OUBI_TABLE" );
		}
		if( !defined( $CONFIG{oubi_table} ) )
		{
			logIt( "main::resetInit(): oubi_table is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( defined( $myRef->{'oubi_pk_column'} ) )
		{
			$CONFIG{oubi_pk_column}		= $myRef->{'oubi_pk_column'};
		}
		else
		{
			$CONFIG{oubi_pk_column}		= $CONFIG{configObject}->getValue( "OUBI_PK_COLUMN" );
		}
		if( !defined( $CONFIG{oubi_pk_column} ) )
		{
			$CONFIG{oubi_pk_column} = "";
		#	logIt( "main::resetInit(): oubi_pk_column is not defined.\n" );
		#	cleanUp();
		#	exit( 1 );
		}
		if( defined( $myRef->{'oubi_start_column'} ) )
		{
			$CONFIG{oubi_start_column}		= $myRef->{'oubi_start_column'};
		}
		else
		{
			$CONFIG{oubi_start_column}		= $CONFIG{configObject}->getValue( "OUBI_START_COLUMN" );
		}
		if( !defined( $CONFIG{oubi_start_column} ) )
		{
			$CONFIG{oubi_start_column} = "";
		#	logIt( "main::resetInit(): oubi_start_column is not defined.\n" );
		#	cleanUp();
		#	exit( 1 );
		}
		if( defined( $myRef->{'oubi_end_column'} ) )
		{
			$CONFIG{oubi_end_column}		= $myRef->{'oubi_end_column'};
		}
		else
		{
			$CONFIG{oubi_end_column}		= $CONFIG{configObject}->getValue( "OUBI_END_COLUMN" );
		}
		if( !defined( $CONFIG{oubi_end_column} ) )
		{
			$CONFIG{oubi_end_column} = "";
			#logIt( "main::resetInit(): oubi_end_column is not defined.\n" );
			#cleanUp();
			#exit( 1 );
		}
		if( defined( $myRef->{'diff_view'} ) )
		{
			$CONFIG{diff_view}		= $myRef->{'diff_view'};
		}
		else
		{
			$CONFIG{diff_view}		= $CONFIG{configObject}->getValue( "DIFF_VIEW" );
		}
		if( !defined( $CONFIG{diff_view} ) )
		{
			logIt( "main::resetInit(): diff_view is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( defined( $myRef->{'diff_table'} ) )
		{
			$CONFIG{diff_table}		= $myRef->{'diff_table'};
		}
		else
		{
			$CONFIG{diff_table}		= $CONFIG{configObject}->getValue( "DIFF_TABLE" );
		}
		if( !defined( $CONFIG{diff_table} ) )
		{
			logIt( "main::resetInit(): diff_table is not defined.\n" );
			cleanUp();
			exit( 1 );
		}
		if( $CONFIG{file} !~ m/$CONFIG{batch_id}/ )
		{
			my $file = $CONFIG{file};
			$file =~ s/\.xlsx$/_$CONFIG{batch_id}\.xlsx/;
			$CONFIG{file} = $file;
		}
	}
	else
	{
		logIt( "main::resetInit(): Unable to retrieve the ETL configuration object for " . $CONFIG{config} . "\n" );
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
		"\t[-connect]         -- Database connection file (required: default is $CONFIG{connect}).\n" .
		"\t[-config]          -- Configuration file (required: default is $CONFIG{config}).\n" .
		"\t[-file]            -- XLSX output file (optional: default is $CONFIG{file}).\n" .
		"\t[-limit]           -- limit on ci_chg_log query results(optional: default is $CONFIG{limit}).\n" .
		"\t[-batch_id]        -- Batch ID for search(optional: default is $CONFIG{batch_id}).\n" .
		"\t[-chg_log_id]      -- Change log ID for search(optional: default is $CONFIG{chg_log_id}).\n" .
		"\t[-search_columns]  -- Attribute/Value pairs of column names and values to query on, \"PK_VAL1=value1|PK_VAL2=value2\"(optional: default is $CONFIG{search_columns}).\n" .
		"\t[-ccb_return_columns]  -- List of columns for IN and OR clauses, \"SRC_SA_ID=PK_VAL1\"(optional: default is $CONFIG{ccb_return_columns}).\n" .
		"\t[-oubi_return_columns] -- List of columns for IN and OR clauses, \"SRC_SA_ID=PK_VAL1\"(optional: default is $CONFIG{oubi_return_columns}).\n" .
		"\t[-log_file]        -- full path name of log of archive directory (optional: default is $CONFIG{log_file}).\n" .
		"\t[-debug]           -- set debug option on.\n" . 
		"\t[-stdout]          -- set standard output flag option on.\n" . 
		"\t[-help]            -- displays the usage.\n" .
		"Example: template.pl -connect ./VC_ITST_ITST.cfg -config ./VC_SA.cfg -stdout\n"; 


	$rc = GetOptions(
				'connect=s'			=> \$href_opts->{'connect'},
				'config=s'			=> \$href_opts->{'config'},
				'limit=i'			=> \$href_opts->{'limit'},
				'file=s'			=> \$href_opts->{'file'},
				'batch_id=s'		=> \$href_opts->{'batch_id'},
				'chg_log_id=s'		=> \$href_opts->{'chg_log_id'},
				'search_columns=s'	=> \$href_opts->{'search_columns'},
				'ccb_return_columns=s'	=> \$href_opts->{'ccb_return_columns'},
				'oubi_return_columns=s'	=> \$href_opts->{'oubi_return_columns'},
				'log_file=s'		=> \$href_opts->{'log_file'},
				'debug'				=> \$href_opts->{'debug'},
				'stdout'			=> \$href_opts->{'stdout'},
				'help'				=> \$href_opts->{'help'}
			 );

	my @missing_opts;
	my %opt_display = (
			'connect'		=> 'connect',
			'config'		=> 'config',
			'limit'			=> 'limit',
			'file'			=> 'file',
			'batch_id'		=> 'batch_id',
			'chg_log_id'	=> 'chg_log_id',
			'search_columns'=> 'search_columns',
			'ccb_return_columns'=> 'ccb_return_columns',
			'outi_return_columns'=> 'outi_return_columns',
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
	foreach my $option (qw(connect config))
	{
		push (@missing_opts, $option) unless $href_opts->{$option};
	}

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
	$CONFIG{pk_val}			= "";
	$CONFIG{batch_id}		= "";
	$CONFIG{batch_nbr}		= "";
	$CONFIG{chg_log_id}		= "";
	$CONFIG{limit}			= "";
	$CONFIG{connect}		= "./VC_ITST_ITST.cfg";
	$CONFIG{config}			= "./VC_SA.cfg";
	my $osName = lc( $^O );
	if( $osName =~ m/mswin/ )
	{
		$CONFIG{sql_dir}		= "c:/app/ccb/CCBDEV/OUBI/scripts/ETL_Validation";
		$CONFIG{log_file}		= "c:/temp/" . basename($0);
		$CONFIG{file}			= "c:/temp/" . basename($0) . ".xlsx";
		$CONFIG{oubi_sid}    	= "OUBIDEV";
		$CONFIG{ext_dir}		= "c:/app/ccb/CCBDEV/OUBI/scripts/ETL_Validation/data";
	}
	elsif( $osName =~ m/cygwin/ )
	{
		$CONFIG{sql_dir}		= "c:/app/ccb/CCBDEV/OUBI/scripts/ETL_Validation";
		$CONFIG{log_file}		= "/cygdrive/c/temp/" . basename($0);
		$CONFIG{file}			= "/cygdrive/c/temp/" . basename($0) . ".xlsx";
		$CONFIG{oubi_sid}    	= "OUBIDEV";
		$CONFIG{ext_dir}		= "/cygdrive/c/app/ccb/CCBDEV/OUBI/scripts/ETL_Validation/data";
	}
	else
	{
		$CONFIG{sql_dir}		= "/oubi/work/scripts/ETL_Validation";
		$CONFIG{log_file}		= "/tmp/" . basename($0);
		$CONFIG{file}			= "/oubi/work/scripts/ETL_Validation/data/" . basename($0) . ".xlsx";
		$CONFIG{oubi_sid}    	= "OUBIETL";
		$CONFIG{ext_dir}		= "/oubi/work/scripts/ETL_Validation/data";
	}
	$CONFIG{log_file}		=~ s/\.pl//;
	$CONFIG{file}			=~ s/\.pl//;
	$CONFIG{search_columns}	= "";
	$CONFIG{ccb_return_columns}	= "";
	$CONFIG{oubi_return_columns}	= "";
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
	logIt( "     Database connect file is: $CONFIG{connect}\n" );
	logIt( "        Configuration file is: $CONFIG{config}\n" );
	logIt( "                     Limit is: $CONFIG{limit}\n" );
	logIt( "                       Env is: $CONFIG{env}\n" );
	logIt( "                   RPT sid is: $CONFIG{rpt_sid}\n" );
	logIt( "                   CCB sid is: $CONFIG{ccb_sid}\n" );
	logIt( "                  OUBI sid is: $CONFIG{oubi_sid}\n" );
	logIt( "                  CCB view is: $CONFIG{ccb_view}\n" );
	logIt( "                 OUBI view is: $CONFIG{oubi_view}\n" );
	logIt( "                 DIFF view is: $CONFIG{diff_view}\n" );
	logIt( "          CCB Report table is: $CONFIG{ccb_table}\n" );
	logIt( "         OUBI Report table is: $CONFIG{oubi_table}\n" );
	logIt( "         DIFF Report table is: $CONFIG{diff_table}\n" );
	logIt( "    CCB primary key column is: $CONFIG{ccb_pk_column}\n" );
	logIt( "   OUBI primary key column is: $CONFIG{oubi_pk_column}\n" );
	logIt( "                  Batch id is: $CONFIG{batch_id}\n" );
	logIt( "              Batch number is: $CONFIG{batch_nbr}\n" );
	logIt( "             Change log id is: $CONFIG{chg_log_id}\n" );
	logIt( "            Search columns is: $CONFIG{search_columns}\n" );
	logIt( "        CCB Return columns is: $CONFIG{ccb_return_columns}\n" );
	logIt( "       OUBI Return columns is: $CONFIG{oubi_return_columns}\n" );
	logIt( "             SQL directory is: $CONFIG{sql_dir}\n" );
	logIt( "  External table directory is: $CONFIG{ext_dir}\n" );
	logIt( "                Email from is: $CONFIG{email_from}\n" );
	logIt( "                  Email to is: $CONFIG{email_to}\n" );
	logIt( "     Email attachment type is: $CONFIG{email_attachment_type}\n" );
	logIt( "               Output file is: $CONFIG{file}\n" );
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
