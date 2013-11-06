#!perl
use strict;
use warnings;

#use File::Slurp;
use Term::ReadKey;
use File::Spec::Functions 'catfile';
use Text::CSV_PP;
#use UTF8;
use Data::Dumper;
use Encode qw(encode decode);
use charnames ':full';
use English qw' -no_match_vars ';
print "$OSNAME\n";
my $enc = 'utf-8'; # This script is stored as UTF-8
use feature 'unicode_strings';
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
"Usage:  $0  OCRRootDirectory FullPathTOCSVRootDirectory XMLOutputRootDirectory\n";
	die;
}
my $OCRRootDirectory       = $ARGV[0];
my $CSVRootDirectory       = $ARGV[1];
my $XMLOutputRootDirectory = $ARGV[2];

my $FilesProcessed;

#print "CSVRootDirectory = $CSVRootDirectory";
#open ErrorLog
my @markFoundContents;
open( ERRORLOG, ">>ERRORCSV.log" )
	 || die "$! Could not Open ERRORCSV.log";

ReadAllCSVFiles($CSVRootDirectory);
close (ERRORLOG);
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
	my $OCRLine;
	my $UTF8OCRLine;
	my $DwCHeaders;
	my $DwCFieldElements;

	local *DIRROOT;
	#print "$SubDirName\n";
	opendir( DIRROOT, $SubDirName )
	  or die 'Cannot open directory ', *DIRROOT, $SubDirName, ": $!";

	while ( my $fn = readdir DIRROOT ) {
		$FileWPath = $SubDirName . '\\' . $fn;    #slash for Windows
		$FileWPath = $SubDirName . '/' . $fn;     #slash for Macs

		#next unless -f $fn && $fn =~ /\.txt$/i;
		#print "This -d: ", $FileWPath, "\n" if -d $FileWPath;
		unless ( $fn =~ m/^\./ )
		{ # if it begins with a "." do nothing    #get rid of second slash for Macs
			if ( -d $FileWPath )
			{    # if it isa directory call the routine to open the DIRECTORY
				print "is a directory: ", $FileWPath, "\n";
				ReadAllCSVFiles($FileWPath);
			}
			elsif ( $fn =~ /\.csv$/i ) {    # Only files ending in .csv
				                            # Open the file
				$/ = "\n";

				local *CSVFILESFILE;
				#unless ( open( CSVFILESFILE, "<:encoding(utf8)", $FileWPath ) ) {
				unless ( open( CSVFILESFILE, "<:encoding(ISO-8859-1)", $FileWPath ) ) {
					print "$0 Error: ", $FileWPath,
					  " CSV file of file names cannot be opened.\n";
					die;
				}
				print "processing ", $FileWPath, "\n";

				#print "fn = $fn\n";
				#print "CSVRootDirectory = $CSVRootDirectory\n";
				#print "OCRRootDirectory = $OCRRootDirectory\n";
				#print "XMLRootDirectory = $XMLOutputRootDirectory\n";

				# Replace the most specific subdirectory name with the most
				# specific directory of the text directories
				my $RootofCSV;
				$RootofCSV = $CSVRootDirectory;
				$RootofCSV =~ s/\w+$//;
				#print "RootofCSV = $RootofCSV\n";
				my $NewFileName;
				$NewFileName = substr( $FileWPath, length($CSVRootDirectory) );
				$NewFileName =~ s/\.csv$/\.txt/;
				my $TextFileName;
				$TextFileName = $OCRRootDirectory . $NewFileName;
				#print "The OCR file to open: $TextFileName\n";
				#local *OCRFILESFILE; # declared below in ""open My" clause... I hope that is Local only
				# open the raw OCR file
				my $OCRLine;
				if ( -e $TextFileName )
				{ # if it exits we'll open otherwise keep looking for CSV files
					$OCRLine = do {
						local $/ = undef;
						#open my $OCRFILESFILE, "<", $TextFileName    #opens up the OCR file
						#open my $OCRFILESFILE, "<:encoding(utf8)", $TextFileName    #opens up the OCR file 
						open my $OCRFILESFILE, "<:encoding(iso-8859-1)", $TextFileName    #opens up the OCR file iso-8859-1
						  or die "could not open $TextFileName: $!";
						<$OCRFILESFILE>;
					};
					#$UTF8OCRLine = decode($enc, $OCRLine); #Off when the file is opened in utf8 encoding above
					$UTF8OCRLine = NormalizePunctuation($OCRLine);
					#print $UTF8OCRLine . "\n";
					## convert each character from the string into OCT code
					DumpCharBytes($UTF8OCRLine);
				} 
				else {
						die "$0 Error: ", $TextFileName,
						  " Text file of file names cannot be opened.\n";
					}

				my $csv;

				$csv = Text::CSV_PP->new(
					{
						binary             => 1,
						allow_whitespace   => 1,
						allow_loose_quotes => 1,
						sep_char           => ','
					}
				);    #allow_whitespace removes space in xml tags

				# Now open the associated OCR File which is a text file.
				my $line;
				my $UTF8CSVLine;
				my $columnCount = 0;
				my $outputLine;

				#Create file directory for XML output files
				$RootofCSV = $CSVRootDirectory;
				$RootofCSV =~ s/\w+$//;

				my $NewXMLFileName2;    #for XML output file
				$NewXMLFileName2 =
				  substr( $FileWPath, length($CSVRootDirectory) );
				$NewXMLFileName2 =~ s/\.csv$/\.xml/;
				my $XMLFileName2;
				$XMLFileName2 =
				  $RootofCSV . $XMLOutputRootDirectory . $NewXMLFileName2;

				my @DwCElementName;
				my @DwCContentFields;

				#print "\nThe XML file to output: $XMLFileName2\n";
				my $NumCSVColumns;
=begin comment
				Open XML output file
				my $safe_file_name;
				if ($XMLFileName2 =~ /^([-\@\w.]+)$/) {
				if ($XMLFileName2 =~ /^([-\@\w.\/]+)$/) {
					$XMLFileName2 = $1; 			# $data now untainted

                    die "$1";

			   	} else {

				die "Security: Potentially Tainted XML File Name in '$XMLFileName2' , /, . eol, @, and - not allowed."; 	# log this somewhere

			   	} }
=end comment
=cut
				#print "This is the XMLFileName2: $XMLFileName2\n";
				open( OUTPUT, ">>$XMLFileName2" )
				  || die "$! Could not Open $XMLFileName2";

				# Read the Header line of the CSV
				$line = <CSVFILESFILE>;
				chomp $line;
				DumpCharBytes($line);
				$DwCElementName[0] = "";
				if ( $csv->parse($line) ) {
					@DwCElementName = $csv->fields();
					#print "These are the elements in the DwCElementName array:\n" . "@DwCElementName .\n";
					#print "There are " . "$#DwCElementName " . " ElementNames.\n";
				}
				else { die "Could not parse CSV First Line\n"; }

				# Read through all remaining lines of the CSV
				my $j;
				my @SortedDwCContentsContents;
				my @SortedDwCContentsIndices;
				my $XMLOutLine    = "";
				$XMLOutLine = encode($enc,$XMLOutLine);
				# Every time we need to search a CSV line we need to restore the $UTF8OCRLine since it is "used up"
				my $OCRLineProtected;
				$OCRLineProtected = $UTF8OCRLine;
				# This is set up to do more than one line but for now will only deal with the line 2 which is primary labels in the herbarium collection
				my %DwCContentsHash;    # = @DwCContentFields;
				while ( $line = <CSVFILESFILE> ) {
					chomp $line;
					## convert each character from the string into OCT 
					#$UTF8CSVLine = decode($enc, $line);
					$UTF8CSVLine = $line;
					print Dumper( \$UTF8CSVLine );
					
					$UTF8CSVLine = NormalizePunctuation($UTF8CSVLine);
					#$UTF8CSVLine = MapToUTF8($UTF8CSVLine);
					#$UTF8OCRLine = $OCRLineProtected;
					#print Dumper( \$UTF8CSVLine );
					DumpCharBytes($UTF8CSVLine);
					
					if ( $csv->parse($UTF8CSVLine) ) {
						@DwCContentFields = $csv->fields();
						$NumCSVColumns    = $#DwCContentFields;
						my $i;
						#  there may be X columns but some contents may be empty. e.g. the 5th may have no key in the hash yet we try to assign a 5 to it.
						for ( $i = 0 ; $i < $NumCSVColumns ; $i++ ) {
							if ( $DwCContentFields[$i] ) {
								#$DwCContentFields[$i] = decode($enc, $DwCContentFields[$i]); # this decode will fail if there are wide characters
								$DwCContentsHash{"$DwCContentFields[$i]"} = $i;    #assigns index numbers to hash values
								 print "$i =" . "$DwCContentFields[$i]" . "\n";
							}
						}
					}    # else
					else {
						die "Could not parse CSV First Line\n";
					}
				} # end while CSV Lines available
				#print Dumper( \%DwCContentsHash );

				#stores sorted keys by string length. We'll try to match longer strings first
				@SortedDwCContentsContents = (sort ( {length $b <=> length $a || $a cmp $b} keys(%DwCContentsHash)));
				#print Dumper( \@SortedDwCContentsContents );

				#stores original indices for DwCContents
				for ( $j = 0 ; $j < @SortedDwCContentsContents ; $j++ )
				{
					$SortedDwCContentsIndices[$j] =
						 $DwCContentsHash{
						"$SortedDwCContentsContents[$j]"};
					$markFoundContents[$j] = $j;
				}
					
				my $ElementLength;
				my $indexE;    #counter for columns
				my $LocInString;
				my $OCRLineLength = length($UTF8OCRLine);
				#my $DebugKillCount = 0;
				#print "Length of the OCRLine = " . $OCRLineLength . "\n";

				while ( $OCRLineLength > 0 ) {
					$indexE = 0;
					#$DebugKillCount++;
					#if ($DebugKillCount > 50) { die "End 100 chars"; }
					while ($indexE < @SortedDwCContentsContents && $OCRLineLength > 0 )
					{  # While there is something in the line to work on
						$LocInString = index(
							#$UTF8OCRLine,
							#$SortedDwCContentsContents[$indexE]);
							lc($UTF8OCRLine),
							lc( $SortedDwCContentsContents[$indexE]));
=begin comment

						print $indexE . ": LocInString = " . $LocInString . " " . $DwCElementName[ $SortedDwCContentsIndices[$indexE] ]
						  . ":::"
						 . $SortedDwCContentsContents[$indexE]
						 . "\n";
=end comment
=cut

						# if the location of a match is at the beginning
						if ( 0 eq $LocInString ) {
							$XMLOutLine = 
							    $XMLOutLine . "<"
							  . $DwCElementName
							  [ $SortedDwCContentsIndices[$indexE] ]
							  . ">"
							  . $SortedDwCContentsContents[$indexE]
							  . "</"
							  . $DwCElementName
							  [ $SortedDwCContentsIndices[$indexE] ]
							  . ">";
							print "<" . $DwCElementName[ $SortedDwCContentsIndices[$indexE] ] . ">"
							  . $SortedDwCContentsContents[$indexE]
							  . "</" . $DwCElementName[ $SortedDwCContentsIndices[$indexE] ] . ">";
							  $markFoundContents[$indexE] = -1; # check off this element as found. Later we'll print unmarked itmes to the error log
							$ElementLength =
							  length($SortedDwCContentsContents[$indexE] );
							
  							if ($ElementLength > 0) {
  								#$UTF8OCRLine =  substr( $UTF8OCRLine, $ElementLength + 1 );   # take end of line after match	***
  								$UTF8OCRLine =  substr( $UTF8OCRLine, $ElementLength );   # take end of line after match	***
  							}
							if ($UTF8OCRLine) { 
								$UTF8OCRLine =~ s/^\s+//g; # Remove leading spaces ***
								$OCRLineLength = length($UTF8OCRLine);
							} else { $OCRLineLength = 0}
							$indexE = 0;
							#print "newElementIndex = " . $indexE . "\n";
						} else {$indexE++;}
				}

		 # if we are here and there is line left, we did not find a match.
		  # output the first word (and a space) as <ot>
				if ($OCRLineLength) {
					#print "In make the next word an ot. " . $indexE . "\n";
					@WordList = split( /\s+/, $UTF8OCRLine );

					my $FirstWord;
					my $FirstWordLength;

					$FirstWord = shift(@WordList);

					#$FirstWord = shift(@WordList) . " "; #added space to first word ***
					$FirstWordLength = length($FirstWord);

				  #$substring = substr ($UTF8OCRLine, $FirstWordLength);

					$XMLOutLine = $XMLOutLine . "<lbx:ot>" . $FirstWord . " </lbx:ot>";
					#print "<lbx:ot>" . $FirstWord . " </lbx:ot>" . "\n";

					#This last word might end the OCRLine. Set length to 0 if so, else truncate OCRLine.
					if ($OCRLineLength eq $FirstWordLength) {
						$OCRLineLength = 0;
					} else {
						$UTF8OCRLine = substr( $UTF8OCRLine, $FirstWordLength + 1 );    # take end of line after match ***
						$UTF8OCRLine =~s/^\s+//g;    # Remove leading spaces ***
						#print "Remainder of line in other: $UTF8OCRLine" . "\n";
=begin comment
					my $OctStr;
					$OctStr = $UTF8OCRLine;
					$OctStr =~ s/(.)/sprintf("%x ",ord($1))/eg;
					print "$OctStr\n";
					$OctStr = $UTF8OCRLine;
					$OctStr =~ s/(.)/sprintf(" %s ",$1)/eg;
					print "$OctStr\n";
=end comment
=cut						
						$OCRLineLength = length($UTF8OCRLine);
					}
				}

			}    # While text is left in the line

		close(CSVFILESFILE);
		#Scan through the markFound array printing any elements that we not set to -1
		#print Dumper( \@markFoundContents);
		print ERRORLOG $FileWPath . "\n";
		my $Element;
		while($Element = shift(@markFoundContents))
		{
			if ($Element != -1) {
				print ERRORLOG $SortedDwCContentsContents[$Element] . "\n";
			}
		}
		$XMLOutLine =~ s/<\/lbx:ot><lbx:ot>//g;    # Remove tags <ot></ot> to concat other
		$XMLOutLine = encode($enc,$XMLOutLine);
		$XMLOutLine =~ s/(\d)Â°/$1°/g; #UTF degree back to internal encoding
		print $XMLOutLine;
						
				open( OUTPUT, ">$XMLFileName2" )
				  || die "$! Could not Open $XMLFileName2";
=begin comment
				print OUTPUT '<?xml version="1.0" encoding="UTF-8"?>'
				  . "\n"
				  . '<?xml-model href="http://herbis.arl.arizona.edu/DarwinsBiSciCol.rng" type="application/xml" schematypens="http://relaxng.org/ns/structure/1.0"?>';
=end comment
=cut
				print OUTPUT "<labeldata>" . "\n";
				print OUTPUT $XMLOutLine;
				print OUTPUT "\n" . "<\/labeldata>" . "\n";
				close(OUTPUT);

			}    # end elseif
		}  # end unless
		   #closedir DIRROOT or die 'Cannot close directory ', *DIRROOT, ": $!";
	}    # End while
}    # end sub
########################
sub DumpCharBytes {
	my ($DumpString) = @_;
	my $OctStr;
	$OctStr = $DumpString;
	$OctStr =~ s/(.)/sprintf("%x ",ord($1))/eg;
	print "$OctStr\n";
	$OctStr = $DumpString;
	$OctStr =~ s/(.)/sprintf(" %s ",$1)/eg;
	print "$OctStr\n";
	
} # end DumpCharBytes
########################
sub NormalizePunctuation {
	my ($StringToNormalize) = @_;
	my $Stringbuffer = $StringToNormalize;
	$Stringbuffer =~ s/\r\n/ /g;
	$Stringbuffer =~ s/\n/ /g;
	$Stringbuffer =~ s/\t/ /g;
	$Stringbuffer =~ s/=/ = /g;
    $Stringbuffer =~ s/,/ ,/g; #put space around embedded commas
   	$Stringbuffer =~ s/;/ ; /g; #put space around embedded semicollen
   	$Stringbuffer =~ s/:/ : /g; #put space around embedded semicollen
    $Stringbuffer =~ s/^([A-Z])\.([A-Z])./$1 . $2 . /g; # normalize people's innitials where spaces may or may not exist
    $Stringbuffer =~ s/(\D)\./$1 ./g; #put space around embedded peroid
    $Stringbuffer =~ s/ +/ /g; 
    
return $Stringbuffer;
} # end NormalizePunctuation()
#########################
sub MapToUTF8 {
	my ($StringToMap) = @_;
	my $Stringbuffer = $StringToMap;
   	my $Latin1Buffer = "°";
    my $UTF8DegreeSign = encode($enc, $Latin1Buffer);
   	$Stringbuffer =~ s/(\d)(\x{fffd})/$1$UTF8DegreeSign/g; # change latin1 degree sign to UTF-8
   	$Stringbuffer =~ s/(\d)(\x{b0})/$1\x{c2}\x{b0}/g; # change latin1 degree sign to UTF-8
   	$Stringbuffer =~ s/(\d)(\x{fc})/$1\x{c2}\x{bc}/g; # change latin1 u umlaut to UTF-8
   	#$Stringbuffer =~ s/(\d)(\x{fffd})/$1°/g; # change latin1 degree sign to UTF-8
return $Stringbuffer;

} # end MapToUTF8 ()