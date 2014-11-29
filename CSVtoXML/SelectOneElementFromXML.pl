#!perl
use strict;
use warnings;
use XML::LibXML::Common;
use XML::LibXML::Common qw(:libxml);
use XML::LibXML::Common qw(:encoding);
my $enc = 'utf-8'; # This script is stored as UTF-8
#############################################################################
# PERL Program "SelectOneElementFromXML.pl"
#
# July 23, 2014
# Bryan Heidorn

# This program reads XML Directories for files. 
# It leads each file into an XMLLib handler
# It selects the contents of one of the elements and pipes them to a file
# This will allow for later counting and clustering to assign new types to those elements
# the frequent items can be copied into the header of RelabelOtherinXML.pl

# Usage: SelectOneElementFromXML.pl XMLRootDirectory OutputFileName
# Process all files recursively in the directories
# 
$/ = "\r\n"
  ; # Change the builtin variable to require both an carrage return and line feed.
 # This allows multientry filed, fields with more than one valuse in a CSV to be seperated using just a bare \n""
binmode(STDOUT, ":utf8");

my $numargs = @ARGV;

if ( $numargs ne "2" ) {
	print
"Usage:  $0  SelectOneElementFromXML.pl XMLRootDirectory OutputFileName\n";
	die;
}
my $XMLRootDirectory = $ARGV[0];
my $OutputRootFile   = $ARGV[1];

open( ERRORLOG, ">>ERRORCSV.log" )
	 || die "$! Could not Open ERRORCSV.log";

ReadAllFiles($XMLRootDirectory);
close (ERRORLOG);
exit;

########################
sub ReadAllFiles {
	my ($SubDirName) = @_;
	my $fn;
	my $FileWPath;
	my $line;
	my $selectedElement;
	my @matchList;
		local *DIRROOT;
	#print "$SubDirName\n";
	opendir( DIRROOT, $SubDirName )
	  or die 'Cannot open directory ', *DIRROOT, $SubDirName, ": $!";

	
	my $matchListIndex = 0;
	while ( my $fn = readdir DIRROOT ) {
		#$FileWPath = $SubDirName . '\\' . $fn;    #slash for Windows
		$FileWPath = $SubDirName . '/' . $fn;     #slash for Macs

		#print "This -d: ", $FileWPath, "\n" if -d $FileWPath;
		unless ( $fn =~ m/^\./ ) 
			{ # if it begins with a "." do nothing    #get rid of second slash for Macs
			if ( -d $FileWPath )
				{    # if it isa directory call the routine to open the DIRECTORY
					#print "is a directory: ", $FileWPath, "\n";
					ReadAllFiles($FileWPath);
				}
			elsif ( $fn =~ /\.xml$/i ) {    # Only files ending in .xml
				                            # Open the file
				$/ = "\n";
				local *XMLFILESFILE;
   		 		#print "Open $FileWPath\n";
				unless ( open( XMLFILESFILE, "<:encoding(utf8)", $FileWPath ) ) {
				#unless ( open( XMLFILESFILE, "<", $FileWPath ) ) {
					print "$0 Error: ", $FileWPath,
				  	" XML file of file names cannot be opened.\n";
					die;				
				}
				while ( $line = <XMLFILESFILE> ) {
					chomp $line;
					# print "$line\n";
					$selectedElement = $line;
					while ($selectedElement =~ /(\<ot\>.+?\<\/ot\>)\<(\w+?)\>/g) {
						$matchList[$matchListIndex++] = "$1<$2>\' => \'$2Label";
						#print "$matchList[$matchListIndex-1]\n";
					}
				}
			}
		} # end unless
	} # end while
	my %dups; # http://stackoverflow.com/questions/3011888/whats-the-most-efficient-way-to-check-for-duplicates-in-an-array-of-data-using
	my $last;
	my @sortedMatches = sort @matchList;
	for my $entry (@sortedMatches) {
		$dups{$entry}++ if defined $last and $entry eq $last;
		$last = $entry;
	}
	open( OUTPUT, ">$OutputRootFile" ) || die "$! Could not Open $OutputRootFile";
	foreach (sort { ($dups{$a} <=> $dups{$b}) || ($a cmp $b) } keys %dups) 
	{
		print "'$_', # $dups{$_}\n";
	    print OUTPUT "'$_', # $dups{$_}\n";
	    
	}
	close(OUTPUT);
}
########################
