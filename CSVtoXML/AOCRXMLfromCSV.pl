## #!/usr/bin/perl
use strict;
use warnings;
#use File::Slurp;
use File::Spec::Functions 'catfile';
use Text::CSV_PP;
use UTF8;
#############################################################################
# PERL Program "AOCRXMLfromCSV.pl"
#
# Jan. 14, 2013
# Bryan Heidorn & Steven Chong
#
# This program reads OCR and CSF Directories for files. It is assumed that the file names are the
# same except for the file extensions differ (i.e. .txt and .CSV)

# Usage: AOCRXMLfromCSV.pl OCRRootDirectory CSVRootDirectory XMLOutputRootDirectory
# Process all files recursively in the directories
# see CSV Package at http://help-site.com/Programming/Languages/Perl/CPAN/String_Lang_Text_Proc/Text_Full/Text-CSV_PP/CSV_PP.pm/
$/ = "\r\n"
  ; # Change the builtin variable to require both an carrage return and line feed.
 # This allows multientry filed, fields with more than one valuse in a CSV to be seperated using just a bare \n""
my $numargs = @ARGV;

if ( $numargs ne "3" ) {
	print
	  "Usage:  $0  OCRRootDirectory CSVRootDirectory XMLOutputRootDirectory\n";
	die;
}
my $OCRRootDirectory       = $ARGV[0];
my $CSVRootDirectory       = $ARGV[1];
my $XMLOutputRootDirectory = $ARGV[2];

my $FilesProcessed;
#print "CSVRootDirectory = $CSVRootDirectory";
ReadAllCSVFiles($CSVRootDirectory);
exit;
########################
sub ReadAllCSVFiles {
	my ($SubDirName) = @_;
	my $fn;
	my $FileWPath;
	my $line;
	my $lineNumber;
	my $collectorNumber;
	my @WordList;
	my $CollectorName;
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
				ReadAllCSVFiles($FileWPath);
			}
			elsif ( $fn =~ /\.csv$/i ) {    # Only files ending in .txt
				# Open the file
				local *CSVFILESFILE;
				unless ( open( CSVFILESFILE, "<", $FileWPath ) ) {
					print "$0 Error: ", $FileWPath,
					  "file of file names cannot be opened.\n";
					die;
				}
				print "processing ", $FileWPath, "\n";
				print "fn = $fn\n";
				print "CSVRootDirectory = $CSVRootDirectory\n";
				print "OCRRootDirectory = $OCRRootDirectory\n";
				# Replace the most specific subdirectory name with the most 
				# specific directory of the text directories
				my $RootofCSV;
				$RootofCSV = $CSVRootDirectory;
				$RootofCSV =~ s/\w+$//;
				print "RootofCSV = $RootofCSV\n";
				my $NewFileName;								
				$NewFileName = substr($FileWPath, length($CSVRootDirectory));
				$NewFileName =~ s/\.csv$/\.txt/;
				print "NewFileName = $NewFileName\n";
				my $TextFileName;
				# $TextFileName = $RootofCSV . $OCRRootDirectory . '/' . $NewFileName;
				$TextFileName = $OCRRootDirectory . '/' . $NewFileName;
				print "The Final Text Name to open: $TextFileName\n";
				local *OCRFILESFILE;
				if (-e $TextFileName) { # if it exits we'll open otherwise keep looking for CSV files
					open( OCRFILESFILE, "<", $TextFileName );
				} else {
					print "$0 Error: ", $TextFileName,
					  "file of file names cannot be opened.\n";
					die;
				}
				
				my $csv;
				$csv = Text::CSV_PP->new( { binary => 1, sep_char => "," } );
				# Now open the associated OCR File which is a text file.
				my $line;
				my $collectorNameCount;
				$collectorNameCount = 0;
				my $RowNumber = 1;
				while ( $line = <CSVFILESFILE> ) {
					$collectorNameCount++;
					#chomp $line;
					if ( $csv->parse($line) ) {
						if ($RowNumber == 1) {
							my @DwCElementName = $csv->fields();
							print "@DwCElementName\n";
						}
						else {
							my @fields = $csv->fields();
							print "@fields\n";
						}
					}
					else {
						warn "Line could not be parsed: $line\n";
					} # end else
					$RowNumber++;
				} # end while
				close(CSVFILESFILE);

# $fn should be the name of the CSV file with the full path.
# Change the path for the path on the txt path provided by
# the user to add any subdirectories that may have been traversed by the recursive routine
# ? Maybe compare $CVSRootDirectory to $FileWPath and take the tail
# add the tail to the user supplied path for the OCR/txt file.
# change the file extension to .txt
# If the file open failed, do not process either file and go to the next CSV file
# If both the CSV and OCR file sopwn then open the output file. The path root path is
# provided by the user. concatinate the current path section.
# Read the CSV first and second line using the CSV_PP package to get two arrays of thrings.
# the first array will be the field names.
# The second array will be the values.
# Search the OCR files for matches of the value.
# wrap XML tags with the name of the same column around he OCR text.

			}    # end elseif
		}    # end unless
		#closedir DIRROOT or die 'Cannot close directory ', *DIRROOT, ": $!";
	} # End while
}    # end sub
