#!/usr/bin/perl
use strict;
use warnings;
use File::Slurp;
use File::Spec::Functions 'catfile';

#############################################################################
# PERL Program "FilterLabelsonWordFreqV2.pl"
#
# July 4, 2012
#
# This program accepts word list to serve as the basis for matching. It is assumed that a high count indicated good OCR.
# It is planned but not necessary that this list is created by finding frequently appearning words in the OCR output from
# photographs of museum labels. The hope is to eliminate sperious "words" created via OCR errors.
# The program also accepts a list of files names in which the words will be counted.
# The Dictionary must be sorted by frequency in assending order. The frequenct followed by multiple spaces and then the word followed by new line
# Output: Stdout: "Filename #wordsmatched #tokens"
#
# Usage: FilterLabelsonWordFreq.pl DictionaryFile FilenameFile OutputFile
# Test for proper command line, exit if not

my %dictionary; # hash for the dictionary words
my $numargs;

$numargs = @ARGV;

if ($numargs ne "6" ) {
   print "Usage: ", $0, " MinWords MinDictionaryFrequency DictionaryFile DictinaryMinCount FilenameFile Outfile
   MinWords = number of words needed for a file to be acceptable.
   MinDictionaryFrequency = the minimum times a word must appear in the frequency dictionary before it is counted as a word.
   The DictionaryFile must be sorted by frequency in assending order. The frequenct followed by multiple spaces and then the 
   word followed by new line. The program CreateFrequencyDictionary.pl can do this.
   DictionaryMinCount must be a number. It is the minumum frequency that a word must appead in a collection before it is 
   counted as a countable word. The dictionary likley follows a Zipf distribution. Many OCR errors appear only once but make 
   up the majority of a dictionary.
   FilenameFile is where the file or directory to be tested. The system will recursively descend directory trees.
   OutputFile is where the results are stored.\n" ;
         die ;
}
my $MinWords = $ARGV[0];
my $MinDictionaryFrequency = $ARGV[1];
my $Dictfile = $ARGV[2];
my $DictinaryMinCount = $ARGV[3];
my $MyDirName = $ARGV[4] ;
our $outfile = $ARGV[5] ;

#print  $Dictfile, " ", $MyDirName, " ", $outfile, "\n";
#my *DICTFILE;
my $line;
my @WordList;
my $Word;
my $TempFile;
my $FilesProcessed = 0;
my $FilesRejected = 0;

unless (open(DICTFILE, "$Dictfile")) {         # Open the dictionary file
    print "$0 Error: $Dictfile dictionary file cannot be opened.\n" ;
    die;
}

  while ($line = <DICTFILE>) { # While there are lines to read..
    chop($line) ;	# remove trailing marks
    @WordList = split m'\s+', $line;
    #print @WordList, "\n";
    #$line =~ tr/A-Z/a-z/; 	# translate to lower case 
    #@WordList = split(/\s+/, $line); 	# split the line on spaces into @WordList 
   # $indexname= shift(@WordList) ; 
   if ($WordList[0] > $DictinaryMinCount) {
   		$dictionary{$WordList[1]} = $WordList[0];
   		print "$WordList[0] $WordList[1] ";
   }
=begin comment
    foreach $Word (@WordList) {           # Inspect each word 
        $Word =~ s/\W//g; 	# remove non-printing characters
        $Word =~ s/ +//g;       # remove spaces
        if ($Word ne "") { # Add to the hash
            $dictionary {$Word} = 1;
            #print $Word, "\n" ;
        }
    }
=end comment
=cut
  } # end while lines
close (DICTFILE);

$TempFile = "temp.tmp";
unless (open(TEMPFILEh, ">$TempFile")) {         # Open the output file for append
    print "$0 Error: $TempFile output file cannot be opened.\n" ;
    die;
}

countFileContents ($MyDirName);

close TEMPFILEh;

print "About to Sort\n";

system ("sort -g -t'\t' -k4 $TempFile > $outfile ");
system ("rm $TempFile");

print "Files Processed = ", $FilesProcessed, "\n";
print "Files Rejected = ", $FilesRejected, "\n";

## END ##

sub countFileContents {    
    my ($SubDirName) = @_;
    my $fn;
    my $FileWPath;
    my $WordCount;
    my $MatchCount;
    local *DIRROOT;
    opendir (DIRROOT, $SubDirName) or die 'Cannot open directory ', *DIRROOT, $SubDirName, ": $!";
    while(my $fn = readdir DIRROOT) {
        $FileWPath = $SubDirName. '/' . $fn;
        #next unless -f $fn && $fn =~ /\.txt$/i;
        #print "This -d: ", $FileWPath, "\n" if -d $FileWPath;
        unless ( $fn =~ m/^\./ ) { # if it begins with a "." do nothing
            if ( -d $FileWPath ) { # if it isa directory call the routine to open the DIRECTORY
                #print "is a directory: ", $FileWPath, "\n";
                countFileContents( $FileWPath );
            }
            elsif ( $fn =~ /\.txt$/i ) { # Only files ending in .txt
                $WordCount = 0;
                $MatchCount = 0;
        
                print "processing ", $FileWPath, "\n";
                # Open the file
                local *FILESFILE;
                unless (open(FILESFILE, '<', $FileWPath)) {     
                    print "$0 Error: ", $FileWPath, "file of file names cannot be opened.\n" ;
                    die;
                }
                while ($line = <FILESFILE>) { # While there are lines to read..
                    chop($line) ;	# remove trailing marks
                    $line =~ tr/A-Z/a-z/; 	# translate to lower case 
                    @WordList = split(/\s+/, $line); 	# split the line on spaces into @WordList 
            
                    foreach $Word (@WordList) {           # Inspect each word 
                        $WordCount++;
                        $Word =~ s/\W//g; 	# remove non-printing characters
                        $Word =~ s/ +//g;       # remove spaces
                        # count if it is in the dictionary
                        if ($dictionary {$Word} && $dictionary {$Word} > $MinDictionaryFrequency) { 
                            #print $Word, "\tMatched Dictionary\n" ;
                            $MatchCount++;
                        }
                    }
                } # end while lines in FILESFILE
                close (FILESFILE) ;
                if ($MatchCount > 0 && $MatchCount >= $MinWords) {
                    print TEMPFILEh $FileWPath, "\t", $WordCount, "\t", $MatchCount, "\t", $MatchCount/$WordCount, "\n";
                    $FilesProcessed++;
                } else {
                    print "Rejected for low count ", $FileWPath, "\t", $WordCount, "\t", $MatchCount, "\t", "\n";
                    $FilesRejected++;
                }
        
            } # end if
        } # end unless

        #closedir DIRROOT or die 'Cannot close directory ', *DIRROOT, ": $!";

    }
} # end sub


