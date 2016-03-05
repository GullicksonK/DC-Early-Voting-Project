#!/usr/bin/env perl
#
# $Id: file.pl,v 1.2 1998/07/28 17:25:25 rvaughn Exp $
# $Author: rvaughn $
#
use warnings;
use Getopt::Long;
use Cwd;
#use Spreadsheet::WriteExcel;

$whoami = ($0 =~ m,([^/]*)$,) ? $1 : $0;
$dirname = ($0 =~ m,(.*)/[^/]+$,) ? $1 : ".";
#$dirname = abs_path($0);
warn("$whoami: dirname is: $dirname\n");
(undef,$min,$hour,$mday,$mon,$year,undef,undef,undef) = localtime(time);
$realYear = $year+1900;
$filePrefix = sprintf("$realYear%02d%02d.$hour$min",$mon+1,$mday);

warn("$whoami started at $filePrefix\n");


my($verbose,$dry_run,$help);
$verbose=0;
$dry_run=0;
$help=0;
$pollingPlaceFile="";
$summaryFile="";
$eventTarget="112012";
$mapBoxFile="112012";
@fileList = ();


Getopt::Long::Configure("bundling", "no_ignore_case_always");

if (!Getopt::Long::GetOptions
                ("v|verbose+"   => \$verbose,
                 "h|help+" => \&do_usage,
                 "p|polling=s" => \$pollingPlaceFile,
                 "s|summary=s" => \$summaryFile,
                 "e|event=s" => \$eventTarget,
                 "m|mapBoxFile=s" => \$mapBoxFile,
                 "nop" => \$dry_run,
                 "<>" => \&addFileOption))
{
   &do_usage(1);
}

sub addFileOption
{
   my($arg) = shift;
   push(@fileList,$arg);
}

if ($help) 
{
   &do_usage(0);
}

open(PPFD,"$pollingPlaceFile") || die "$whoami: unable to open $pollingPlaceFile: $!\n";
@pollingPlaceFile = <PPFD>;
close(PPFD);

foreach $ppline (@pollingPlaceFile)
{
   @ppdata = split(/,/,$ppline);
   $pollingPlace{$ppdata[3]} = "$ppdata[2],$ppdata[1]";
   warn("$ppdata[3]: $pollingPlace{$ppdata[3]}\n");
   #$pollingPlaceDescription{$ppdata[3]} = "$ppdata[5]:$ppdata[6]";
}
open(SFD,">$summaryFile") || die "$whoami: unable to open $summaryFile: $!\n";
open(MBFD,">$mapBoxFile") || die "$whoami: unable to open $mapBoxFile: $!\n";


foreach $f (@fileList)
{
   warn("Processing $f\n");

   open(PVD,"$f") || die "$whoami: Unable to open $f: $!\n";

   chomp(@fileData = <PVD>);
   close(PVD);

   $emitProgress = 0.05;
   $numLines = scalar(@fileData);
   $currentLine = 0;

   foreach $l (@fileData)
   {
      $l =~ s///g;
      if (($currentLine/$numLines) > $emitProgress)
      {
         $percent = $emitProgress*100;
         warn("Processed $currentLine of $numLines rows. $percent% complete.\n");
         $emitProgress += 0.05;
      }
      $currentLine++;
      if (!@header)
      {
         @header = split(/,/,$l);
         $idx=0;
         $precinctIdx = 9999999;
         foreach $h (@header)
         {
            if ($h eq "PRECINCT")
            {
               $precinctIdx = $idx;
            }
            if ($idx > $precinctIdx+3)
            {
               $eventIdx{$header[$idx]} = $idx;
            }
            $idx++;
         }
      }
      else
      {
         #$l =~ s/"(.*),(.*)"/$1$2/;
         @voterData = split(/,/,$l);
         if (length($voterData[$precinctIdx]) == 0)
         {
            warn("$whoami: found a blank precinct on row $currentLine\n");
         }
         if (!defined($precinctStarted{$voterData[$precinctIdx]}))
         {
            $precinctStarted{$voterData[$precinctIdx]}=1;
            foreach $key (keys{%eventIdx})
            {
               ${'E'}{$voterData[$precinctIdx]}{$key} = 0;
               ${'N'}{$voterData[$precinctIdx]}{$key} = 0;
               ${'V'}{$voterData[$precinctIdx]}{$key} = 0;
               ${'Y'}{$voterData[$precinctIdx]}{$key} = 0;
               ${'A'}{$voterData[$precinctIdx]}{$key} = 0;
               ${'Blank'}{$voterData[$precinctIdx]}{$key} = 0;
            }
         }
         foreach $key (keys{%eventIdx})
         {
            $type = $voterData[$eventIdx{$key}];
            if (length($type))
            {
               ${$type}{$voterData[$precinctIdx]}{$key}++;
            }
            else
            {
               ${'Blank'}{$voterData[$precinctIdx]}{$key}++;
            }
         }
      }
   }
   close(PVD);

   #$workbook = Spreadsheet::WriteExcel->new("$filePrefix.VotingByPrecinct.xls");
   print(SFD "Precinct,Vote Type,");
   foreach $event (sort(compareEvents keys(%eventIdx)))
   {
      print(SFD "$event,");
      print(SFD "$event %ofVotes,");
      print(SFD "$event %ofVoters,");
   }
   print(MBFD "Latitude, Longitude, Layer, Magnitude, Description\n");
   print(SFD "\n");
   $layer = 1;
   foreach $precinct (sort({$a <=> $b} keys(%precinctStarted)))
   {
      print(SFD "$precinct,Eligible,");
      foreach $event (sort(compareEvents keys(%eventIdx)))
      {
         if ($event =~ m/$eventTarget/)
         {
         print(MBFD "$pollingPlace{$precinct}, ");
         }
         $totalPrecinctVotes = ${'V'}{$precinct}{$event} + ${'Y'}{$precinct}{$event};
         $totalPrecinctVoters = ${'E'}{$precinct}{$event} + 
                                ${'N'}{$precinct}{$event} +
                                ${'V'}{$precinct}{$event} +
                                ${'Y'}{$precinct}{$event} +
                                ${'A'}{$precinct}{$event} +
                                ${'Blank'}{$precinct}{$event};
         print(SFD "${'E'}{$precinct}{$event},");
         if ($totalPrecinctVotes>0)
         {
            $percentOfVotes =  (${'E'}{$precinct}{$event}/$totalPrecinctVotes)*100;
         }
         else
         {
            $percentOfVotes = 0;
         }
         if ($totalPrecinctVoters>0)
         {
            $percentOfVoters = (${'E'}{$precinct}{$event}/$totalPrecinctVoters)*100;
         }
         else
         {
            $percentOfVoters = 0;
         }
         if ($event =~ m/$eventTarget/)
         {
            print(MBFD "1,$percentOfVoters,Eligible Voters did not Vote $precinct $event\n");
            $layer++;
         }
         printf(SFD "%2.0f,",$percentOfVotes);
         printf(SFD "%2.0f,",$percentOfVoters);
      }
      print(SFD "\n");
      print(SFD "$precinct,Ineligible,");
      foreach $event (sort(compareEvents keys(%eventIdx)))
      {
         if ($event =~ m/$eventTarget/)
         {
         print(MBFD "$pollingPlace{$precinct}, ");
         }
         $totalPrecinctVotes = ${'V'}{$precinct}{$event} + ${'Y'}{$precinct}{$event};
         $totalPrecinctVoters = ${'E'}{$precinct}{$event} + 
                                ${'N'}{$precinct}{$event} +
                                ${'V'}{$precinct}{$event} +
                                ${'Y'}{$precinct}{$event} +
                                ${'A'}{$precinct}{$event} +
                                ${'Blank'}{$precinct}{$event};
         print(SFD "${'N'}{$precinct}{$event},");
         if ($totalPrecinctVotes>0)
         {
            $percentOfVotes =  (${'N'}{$precinct}{$event}/$totalPrecinctVotes)*100;
         }
         else
         {
            $percentOfVotes = 0;
         }
         if ($totalPrecinctVoters>0)
         {
            $percentOfVoters = (${'N'}{$precinct}{$event}/$totalPrecinctVoters)*100;
         }
         else
         {
            $percentOfVoters = 0;
         }
         if ($event =~ m/$eventTarget/)
         {
            print(MBFD "2,$percentOfVoters,Ineligible Voters $precinct $event\n");
            $layer++;
         }
         print(SFD "%2.0f,",$percentOfVotes);
         print(SFD "%2.0f,",$percentOfVoters);
      }
      print(SFD "\n");
      print(SFD "$precinct,InPersonVote,");
      foreach $event (sort(compareEvents keys(%eventIdx)))
      {
         if ($event =~ m/$eventTarget/)
         {
         print(MBFD "$pollingPlace{$precinct}, ");
         }
         $totalPrecinctVotes = ${'V'}{$precinct}{$event} + ${'Y'}{$precinct}{$event};
         $totalPrecinctVoters = ${'E'}{$precinct}{$event} + 
                                ${'N'}{$precinct}{$event} +
                                ${'V'}{$precinct}{$event} +
                                ${'Y'}{$precinct}{$event} +
                                ${'A'}{$precinct}{$event} +
                                ${'Blank'}{$precinct}{$event};
         print(SFD "${'V'}{$precinct}{$event},");
         if ($totalPrecinctVotes>0)
         {
            $percentOfVotes =  (${'V'}{$precinct}{$event}/$totalPrecinctVotes)*100;
         }
         else
         {
            $percentOfVotes = 0;
         }
         if ($totalPrecinctVoters>0)
         {
            $percentOfVoters = (${'V'}{$precinct}{$event}/$totalPrecinctVoters)*100;
         }
         else
         {
            $percentOfVoters = 0;
         }
         if ($event =~ m/$eventTarget/)
         {
            print(MBFD "3,$percentOfVoters,InPerson Voters $precinct $event\n");
            $layer++;
         }
         print(SFD "%2.0f,",$percentOfVotes);
         print(SFD "%2.0f,",$percentOfVoters);
      }
      print(SFD "\n");
      print(SFD "$precinct,EarlyVoter,");
      foreach $event (sort(compareEvents keys(%eventIdx)))
      {
         if ($event =~ m/$eventTarget/)
         {
         print(MBFD "$pollingPlace{$precinct}, ");
         }
         $totalPrecinctVotes = ${'V'}{$precinct}{$event} + ${'Y'}{$precinct}{$event};
         $totalPrecinctVoters = ${'E'}{$precinct}{$event} + 
                                ${'N'}{$precinct}{$event} +
                                ${'V'}{$precinct}{$event} +
                                ${'Y'}{$precinct}{$event} +
                                ${'A'}{$precinct}{$event} +
                                ${'Blank'}{$precinct}{$event};
         print(SFD "${'Y'}{$precinct}{$event},");
         if ($totalPrecinctVotes>0)
         {
            $percentOfVotes =  (${'Y'}{$precinct}{$event}/$totalPrecinctVotes)*100;
         }
         else
         {
            $percentOfVotes = 0;
         }
         if ($totalPrecinctVoters>0)
         {
            $percentOfVoters = (${'Y'}{$precinct}{$event}/$totalPrecinctVoters)*100;
         }
         else
         {
            $percentOfVoters = 0;
         }
         if ($event =~ m/$eventTarget/)
         {
            print(MBFD "4,$percentOfVoters,Early Voters $precinct $event\n");
            $layer++;
         }
         print(SFD "%2.0f,",$percentOfVotes);
         print(SFD "%2.0f,",$percentOfVoters);
      }
      print(SFD "\n");
      print(SFD "$precinct,Absentee,");
      foreach $event (sort(compareEvents keys(%eventIdx)))
      {
         if ($event =~ m/$eventTarget/)
         {
         print(MBFD "$pollingPlace{$precinct}, ");
         }
         $totalPrecinctVotes = ${'V'}{$precinct}{$event} + ${'Y'}{$precinct}{$event};
         $totalPrecinctVoters = ${'E'}{$precinct}{$event} + 
                                ${'N'}{$precinct}{$event} +
                                ${'V'}{$precinct}{$event} +
                                ${'Y'}{$precinct}{$event} +
                                ${'A'}{$precinct}{$event} +
                                ${'Blank'}{$precinct}{$event};
         print(SFD "${'A'}{$precinct}{$event},");
         if ($totalPrecinctVotes>0)
         {
            $percentOfVotes =  (${'A'}{$precinct}{$event}/$totalPrecinctVotes)*100;
         }
         else
         {
            $percentOfVotes = 0;
         }
         if ($totalPrecinctVoters>0)
         {
            $percentOfVoters = (${'A'}{$precinct}{$event}/$totalPrecinctVoters)*100;
         }
         else
         {
            $percentOfVoters = 0;
         }
         if ($event =~ m/$eventTarget/)
         {
            print(MBFD "5,$percentOfVoters,Absentee Voters $precinct $event\n");
            $layer++;
         }
         print(SFD "%2.0f,",$percentOfVotes);
         print(SFD "%2.0f,",$percentOfVoters);
      }
      print(SFD "\n");
      print(SFD "$precinct,NotRegistered,");
      foreach $event (sort(compareEvents keys(%eventIdx)))
      {
         $totalPrecinctVotes = ${'V'}{$precinct}{$event} + ${'Y'}{$precinct}{$event};
         $totalPrecinctVoters = ${'E'}{$precinct}{$event} + 
                                ${'N'}{$precinct}{$event} +
                                ${'V'}{$precinct}{$event} +
                                ${'Y'}{$precinct}{$event} +
                                ${'A'}{$precinct}{$event} +
                                ${'Blank'}{$precinct}{$event};
         print(SFD "${'Blank'}{$precinct}{$event},");
         if ($totalPrecinctVotes>0)
         {
            $percentOfVotes =  (${'Blank'}{$precinct}{$event}/$totalPrecinctVotes)*100;
         }
         else
         {
            $percentOfVotes = 0;
         }
         if ($totalPrecinctVoters>0)
         {
            $percentOfVoters = (${'Blank'}{$precinct}{$event}/$totalPrecinctVoters)*100;
         }
         else
         {
            $percentOfVoters = 0;
         }
         print(SFD "%2.0f,",$percentOfVotes);
         print(SFD "%2.0f,",$percentOfVoters);
      }
      print(SFD "\n");
   }
}

sub do_usage
{
   local($exit_val) = shift;
   if (!defined($exit_val))
   {
      $exit_val = 2;
   }
   warn<<EO_USAGE;

Usage:  $whoami [options] [files]

Description:
                 "h|help+" => \&do_usage,
                 "p|polling=s" => \$pollingPlaceFile,
                 "s|summary=s" => \$summaryFile,
                 "e|event=s" => \$eventTarget,
                 "m|mapBoxFile=s" => \$mapBoxFile,

Options:

EO_USAGE

   exit $exit_val;
}

sub compareEvents
{
   $aY = substr($a,4,2);
   if ($aY < 50)
   {
      $aY =  "20$aY";
   }
   else
   {
      $aY =  "19$aY";
   }
   $aM = substr($a,2,2);
   $aD = substr($a,0,2);

   $bY = substr($b,4,2);
   if ($bY < 50)
   {
      $bY =  "20$bY";
   }
   else
   {
      $bY =  "19$bY";
   }
   $bM = substr($b,2,2);
   $bD = substr($b,0,2);

   $aN = "$aY$aM$aD";
   $bN = "$bY$bM$bD";

   return($bN cmp $aN);
}
