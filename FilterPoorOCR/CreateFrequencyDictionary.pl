#!/usr/bin/perl
use strict;
use warnings;
use File::Slurp;
use File::Spec::Functions 'catfile';
use Sort::External;
use UTF8;

#############################################################################
# PERL Program "CreateFrequencyDictionary.pl"
#
# January 18, 2013
#
# This program accepts a directory name and puts all of the words in all of the files
# in all of the subdirectories into one file sorted and does a frequency count resorted by
# frequency.
# Output: Stdout: "Number of unique token and title number of tokens
#
# 
my $numargs = @ARGV;

if ( $numargs ne "3" ) {
	print "Usage:  $0  RootDirectory SortedByTokenFile SortedByCountFile\n";
	die;
	}
my $RootDirectory        = $ARGV[0];
my $SortedByTokenFile = $ARGV[1];
my $SortedByFreqCountFile = $ARGV[2];
my $SortTemp = "Sort.tmp.txt";
if ($SortTemp =~ /^([-\@\w.]+)$/) {
	$SortTemp = $1; 			# $data now untainted
   	} else {
	die "Security: Potentially Tainted data in '$SortTemp' , /, . eol, @, and - not allowed."; 	# log this somewhere
   	}
my $OutFileHandle;
open $OutFileHandle, ">", $SortTemp or          # Open the Output file
   	die "$0 Error: $SortTemp file cannot be opened.\n";
binmode ($OutFileHandle, ":utf8");
my $FilesProcessed;
NamesinFileContents ($RootDirectory);
close ($OutFileHandle);

print "Files Concatinated: $FilesProcessed\nBegin Sort.\n";
# OpenConcordance File for input
unless ( open( UNSORTEDFILEHANDLE, '<', $SortTemp ) ) {
	print "$0 Error: ", $SortTemp, "unsorted concordance cannot be opened.\n";
	die;
}
binmode (UNSORTEDFILEHANDLE, ":utf8");


# 1. Encode
my $sortex = Sort::External->new( mem_threshold => 1024**2 * 16 );
while (<UNSORTEDFILEHANDLE>) {
	$sortex->feed($_);
}
$sortex->finish;
# open the output file empty
if ($SortedByTokenFile =~ /^([-\@\w.]+)$/) {
	$SortedByTokenFile = $1; 			# $data now untainted
   	} else {
	die "Security: Potentially Tainted data in '$SortedByTokenFile' , /, . eol, @, and - not allowed."; 	# log this somewhere
   	}
unless (open(OUTFILE, ">$SortedByTokenFile")) {       # Open the output file - overwrite mode
	if (!(-w $SortedByTokenFile)) {
		die ("$0 Died -- No write permissions to $SortedByTokenFile.\n") ;
    } else {
       die ("$0 Died -- $SortedByTokenFile cannot be opened.\n");
       }
  }
binmode (OUTFILE, ":utf8");
# open the sorted file
print "Sort Complete. Beginning Count\n" ;
### Count the frequenct of each word
my @sortkeys;
my $thisword;
my $lastword;
my $count;
$thisword = $sortex->fetch;
$lastword = $thisword;
$count = 1;
my $lines = 0;
while ( defined( $thisword = $sortex->fetch ) ) {
    if ( $thisword eq $lastword) { # if it is the same word incrament the counter
       $count++;
    } else {
        printf (OUTFILE "%-10i%s\n", $count, $lastword);
        push @sortkeys, ( pack( 'N', $count ) . $lastword );
       $lastword = $thisword;
		$lines++;
       $count = 1;
    }
}       
close (OUTFILE) ;
if ($SortedByFreqCountFile =~ /^([-\@\w.]+)$/) {
	$SortedByFreqCountFile = $1; 			# $data now untainted
   	} else {
	die "Security: Potentially Tainted data in '$SortedByFreqCountFile' , /, . eol, @, and - not allowed."; 	# log this somewhere
   	}
unless (open(FREQOUTFILE, ">$SortedByFreqCountFile")) {       # Open the output file - overwrite mode
	if (!(-w $SortedByFreqCountFile)) {
		die ("$0 Died -- No write permissions to $SortedByFreqCountFile.\n") ;
    } else {
       die ("$0 Died -- $SortedByFreqCountFile cannot be opened.\n");
       }
  }
binmode (FREQOUTFILE, ":utf8");

print "Frequency Count Push complete. Beginning Frequency sort of $lines lines";
my $SortTextOnCount = Sort::External->new( mem_threshold => 2**24 );
$SortTextOnCount->feed(@sortkeys);
$SortTextOnCount->finish; 
my @WordList;
$count = 0;
while ( defined( $thisword = $SortTextOnCount->fetch ) ) {
	my $tempbuffer = $thisword;
	$count = unpack ("N", $thisword);
	$lastword = substr ( $tempbuffer, 4) ;
    printf (FREQOUTFILE "%-10i%s", $count, $lastword);
}
print "Lines = $lines : Count = $count\n";
close (UNSORTEDFILEHANDLE);
close (FREQOUTFILE);
exit;
#
########################
sub NamesinFileContents {
	my $SubDirName = shift;
	#my $SubOutFileHandle = shift;
	my $fn;
	my $FileWPath;
	my $line;
	my $lineNumber;
	my @WordList;
	my $Word1;
	local *DIRROOT;
	print "$SubDirName\n";
	opendir( DIRROOT, $SubDirName )
	  or die 'Cannot open directory ', *DIRROOT, $SubDirName, ": $!";

	while ( my $fn = readdir DIRROOT ) {
		$FileWPath = $SubDirName . '/' . $fn;

		#next unless -f $fn && $fn =~ /\.txt$/i;
		#print "This -d: ", $FileWPath, "\n" if -d $FileWPath;
		unless ( $fn =~ m/^\./ ) {    # if it begins with a "." do nothing
			if ( -d $FileWPath )
			{    # if it isa directory call the routine to open the DIRECTORY
				    #print "is a directory: ", $FileWPath, "\n";
				NamesinFileContents($FileWPath);
			}
			elsif ( $fn =~ /\.txt$/i ) {    # Only files ending in .txt
				#print "processing ", $FileWPath, "\n";
				    # Open the file
				local *FILESFILE;
				unless ( open( FILESFILE, '<', $FileWPath ) ) {
					print "$0 Error: ", $FileWPath,
					  "file of file names cannot be opened.\n";
					die;
				}
				$FilesProcessed++; 
				$lineNumber = 0;
				while ( $line = <FILESFILE> ) {  # While there are lines to read
					chop($line);                 # remove trailing marks
				    $line =~ tr/A-Z/a-z/; 	# translate to lower case 
				    #$line =~ s/\W//g;	# remove non-printing characters
				    @WordList = split(/\s+/, $line); 	# split the line on spaces into @WordList 
				    my $Word;
				    foreach $Word (@WordList) {           # Inspect each word 
 			          print $OutFileHandle $Word, "\n" ;
				    }
					$lineNumber++;					
				} # end lines in file while

				close(FILESFILE);
			}    # end if
		}    # end unless
	}
}    # end sub

