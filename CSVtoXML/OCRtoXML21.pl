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
use PerlIO::encoding;

#$PerlIO::encoding::fallback = Encode::FB_DEFAULT;
use charnames ':full';
use English qw' -no_match_vars ';
use Text::PhraseDistance qw(pdistance);
use XML::Simple;

#use feature 'unicode_strings';
use List::Util qw[min max];
use XML::LibXML::Common;
use XML::LibXML::Common qw(:libxml);
use XML::LibXML::Common qw(:encoding);

#print "$OSNAME\n";
my $enc = 'utf-8';    # This script is stored as UTF-8
binmode(STDOUT, ":utf8");
#############################################################################
# PERL Program "CSVtoXML.pl"
#
# Jan. 14, 2013
# Bryan Heidorn & Steven Chong
# Heavily modified in July 8, 2014-August PBH
#
# This program reads OCR and CSV Directories for files. It is assumed that the file names are the
# same except for the file extensions differ (i.e. .txt and .CSV)

# Usage: CSVtoXML.pl OCRRootDirectory CSVRootDirectory XMLOutputRootDirectory
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
binmode STDOUT, ":encoding(UTF-8)";
#my $OCRRootDirectory;
#my $CSVRootDirectory;
#my $XMLOutputRootDirectory;
#$OCRRootDirectory       = "lichens/gold/ocr";
#$CSVRootDirectory       = "lichens/gold//parsed";
#$XMLOutputRootDirectory = "LichensGoldXML";

my $FilesProcessed;

my @markFoundContents;
open( ERRORLOG, ">>:encoding(utf8)", "ERRORLOG.txt" )
  || die "$! Could not Open ERRORLOG.txt";

ReadAllCSVFiles($CSVRootDirectory);
close(ERRORLOG);
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

		#$FileWPath = $SubDirName . '\\' . $fn;    #slash for Windows
		$FileWPath = $SubDirName . '/' . $fn;    #slash for Macs

		unless ( $fn =~ m/^\./ )
		{ # if it begins with a "." do nothing    #get rid of second slash for Macs
			if ( -d $FileWPath )
			{    # if it isa directory call the routine to open the DIRECTORY
				    #print "is a directory: ", $FileWPath, "\n";
				ReadAllCSVFiles($FileWPath);
			}
			elsif ( $fn =~ /\.csv$/i ) {    # Only files ending in .csv
				                            # Open the file
				$/ = "\n";

				local *CSVFILESFILE;

=begin comment
			if ($FileWPath =~ /^([-\@\w.]+)$/) {
				$FileWPath = $1; 			# $data now untainted
    		} else {
				die "Tainted path in '$FileWPath'"; 	# log this somewhere
   		 	}
=end comment
=cut

				print "\n!!!File to open $FileWPath\n";

			    unless ( open( CSVFILESFILE, "<:encoding(utf8)", $FileWPath ) ) 
				#unless ( open( CSVFILESFILE, "<:encoding(ISO-8859-1)", $FileWPath ) )
				{
					print "$0 Error: ", $FileWPath,
					  " CSV file of file names cannot be opened.\n";
					die;
				}

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

				# open the raw OCR file
				my $OCRLine;
				if ( -e $TextFileName )
				{  # if it exits we'll open otherwise keep looking for CSV files
					$OCRLine = do {
						local $/ = undef;
						open my $OCRFILESFILE, "<:encoding(utf8)", $TextFileName    #opens up the OCR file
						#open my $OCRFILESFILE, "<:encoding(iso-8859-1)", $TextFileName    #opens up the OCR file iso-8859-1
						  or die "could not open $TextFileName: $!";
						<$OCRFILESFILE>;
					};

					print "OCRLINE=$OCRLine\n";
					#$OCRLine =~  s/\0//g;    # Remove  embedded null
					
					#$UTF8OCRLine =  decode( $enc, $OCRLine );    #Off when the file is opened in utf8 encoding above
					       #utf8::encode($UTF8OCRLine);
					$UTF8OCRLine = NormalizePunctuation($OCRLine);

					#$UTF8OCRLine = MapToUTF8($UTF8OCRLine);
					# replace XML special characters
					$UTF8OCRLine = XMLSpecialChars($UTF8OCRLine);

					#print "UTF8OCRLine=$UTF8OCRLine\n";
					## convert each character from the string into OCT code
					# DumpCharBytes($UTF8OCRLine);
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
				open( OUTPUT, ">:encoding(UTF-8)", $XMLFileName2 )
				  || die "$! Could not Open $XMLFileName2";

				# Read the Header line of the CSV
				$line = <CSVFILESFILE>;
				chomp $line;

				#DumpCharBytes($line);
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
				my $XMLOutLine = "";
				#utf8::encode($XMLOutLine);
				#$XMLOutLine = encode( $enc, $XMLOutLine );

# Every time we need to search a CSV line we need to restore the $UTF8OCRLine since it is "used up"
				my $OCRLineProtected;
				$OCRLineProtected = $UTF8OCRLine;

				#DumpCharBytes( $UTF8OCRLine );

				# This is set up to do more than one line 
				my %DwCContentsHash;    # = @DwCContentFields;
				while ( $line = <CSVFILESFILE> ) {
					chomp $line;
					## convert each character from the string into OCT
					#$UTF8CSVLine = decode( $enc, $line );
					$UTF8CSVLine = $line;
					print "UTF8CSVLine=\n$UTF8CSVLine\n";

					# replace XML special characters
					#print Dumper( \$UTF8CSVLine );
					$UTF8CSVLine = NormalizePunctuation($UTF8CSVLine);
					$UTF8CSVLine = XMLSpecialChars($UTF8CSVLine);
					#$UTF8CSVLine = MapToUTF8($UTF8CSVLine);
					#print "After normalize UTF8CSVLine=\n$UTF8CSVLine\n";

					#$UTF8OCRLine = $OCRLineProtected;
					#print Dumper( \$UTF8CSVLine );
					#DumpCharBytes($UTF8CSVLine);

					if ( $csv->parse($UTF8CSVLine) ) {
						@DwCContentFields = $csv->fields();
						$NumCSVColumns    = $#DwCContentFields;
						my $i;

						#  there may be X columns but some contents may be empty. e.g. the 5th may have no key in the hash yet we try to assign a 5 to it.
						for ( $i = 0 ; $i < $NumCSVColumns ; $i++ ) {
							if ( $DwCContentFields[$i] ) {
								#$DwCContentFields[$i] = decode($enc, $DwCContentFields[$i]); # this decode will fail if there are wide characters
								$DwCContentsHash{"$DwCContentFields[$i]"} = $i;    #assigns index numbers to hash values
								#print "$i: " . "$DwCContentFields[$i]" . "\n";
							}
						}
					}    # else
					else {
						die "Could not parse CSV after First Line\n";
					}
				}    # end while CSV Lines available

   #stores sorted keys by string length. We'll try to match longer strings first
				@SortedDwCContentsContents = (
					sort ( { length $b <=> length $a || $a cmp $b }	keys(%DwCContentsHash) ) );

				#print Dumper( \@SortedDwCContentsContents );

				#stores original indices for DwCContents
				for ( $j = 0 ; $j < @SortedDwCContentsContents ; $j++ ) {
					$SortedDwCContentsIndices[$j] =
					  $DwCContentsHash{"$SortedDwCContentsContents[$j]"};
					$markFoundContents[$j] = $j;
				}

				my $ElementLength;
				my $indexE;    #counter for columns
				my $LocInString;
				$UTF8OCRLine =~ s/^\s+//g;    # Remove leading spaces ***
				my $OCRLineLength = length($UTF8OCRLine);

				#my $DebugKillCount = 0;
				#print "Length of the OCRLine = " . $OCRLineLength . "\n";

				while ( $OCRLineLength > 0 ) {
					$indexE = 0;

					#$DebugKillCount++;
					#print "OCR: $UTF8OCRLine\n";
					while ($indexE < @SortedDwCContentsContents
						&& $OCRLineLength > 0 )
					{    # While there is something in the line to work on
						if ( $markFoundContents[$indexE] != -1 )
						{    # if it is not already done
							$LocInString =
							  index( lc($UTF8OCRLine),
								lc( $SortedDwCContentsContents[$indexE] ) );

=begin comment

						print $indexE . ": LocInString = " . $LocInString . " " . $DwCElementName[ $SortedDwCContentsIndices[$indexE] ]
						  . ":::"
						 . $SortedDwCContentsContents[$indexE]
						 . "\n";
=end comment
=cut

							# If the index is part of a word and not a whole word then this is not a good match
							# eg. "Boulder" should not match "Boulderdash"
							# if the character in the matched string after the final match term is not a space skip
							if ( 0 eq $LocInString
								and length($UTF8OCRLine) >
								length( $SortedDwCContentsContents[$indexE] ) )
							{
								my $finalChar = substr(
									$UTF8OCRLine,
									length(
										$SortedDwCContentsContents[$indexE]
									),
									1
								);

				   				#print "a=$finalChar; $SortedDwCContentsContents[$indexE]\n";
								if ( $finalChar =~ m/[a-zA-Z0-9]/ )
								{    #??? not working I think
									 #print "The character is a alphanum = $finalChar\n";
									$LocInString++;
								}
							}

							# if the location of a match is at the beginning
							if ( 0 eq $LocInString ) {
								$XMLOutLine =
								    $XMLOutLine . "<"
								  . $DwCElementName
								  [ $SortedDwCContentsIndices[$indexE] ] . ">"
								  . $SortedDwCContentsContents[$indexE] . "</"
								  . $DwCElementName
								  [ $SortedDwCContentsIndices[$indexE] ] . ">";
								print "<"
								  . $DwCElementName
								  [ $SortedDwCContentsIndices[$indexE] ] . ">"
								  . $SortedDwCContentsContents[$indexE] . "</"
								  . $DwCElementName
								  [ $SortedDwCContentsIndices[$indexE] ] . ">";
								$markFoundContents[$indexE] = -1
								  ; # check off this element as found. Later we'll print unmarked itmes to the error log
								$ElementLength =
								  length( $SortedDwCContentsContents[$indexE] );

								if ( $ElementLength > 0 ) {
									$UTF8OCRLine =
									  substr( $UTF8OCRLine, $ElementLength )
									  ;    # take end of line after match	***
								}
								if ($UTF8OCRLine) {
									$UTF8OCRLine =~
									  s/^\s+//g;    # Remove leading spaces ***
									$OCRLineLength = length($UTF8OCRLine);
								}
								else { $OCRLineLength = 0 }
								$indexE = 0;

								#print "newElementIndex = " . $indexE . "\n";
							}
							else { $indexE++; }
						}
						else {

	  #print "This item is already found $SortedDwCContentsIndices[$indexE] \n";
							$indexE++;
						}
					}

			 		# if we are here and there is line left, we did not find a match.
			  		# output the first word (and a space) as <ot>
					if ($OCRLineLength) {

						#print "In make the next word an ot. " . $indexE . "\n";
						$UTF8OCRLine =~ s/^\s+//g;   # Remove leading spaces ***
						@WordList = split( /\s+/, $UTF8OCRLine );

						my $FirstWord;
						my $FirstWordLength;

						$FirstWord = shift(@WordList);

					 	#print "Length of FirstWord: " . length($FirstWord) . "\n";
						$FirstWordLength = length($FirstWord);
						#$substring = substr ($UTF8OCRLine, $FirstWordLength);
						$XMLOutLine =
						  $XMLOutLine . "<ot>" . $FirstWord . " </ot>";

						#print "<ot>" . $FirstWord . " </ot>" . "\n";

						#This last word might end the OCRLine. Set length to 0 if so, else truncate OCRLine.
						if ( $OCRLineLength eq $FirstWordLength ) {
							$OCRLineLength = 0;
						}
						else {
							$UTF8OCRLine =
							  substr( $UTF8OCRLine, $FirstWordLength + 1 )
							  ;    # take end of line after match ***
							$UTF8OCRLine =~
							  s/^\s+//g;    # Remove leading spaces ***
							 #print "Remainder of line in other: $UTF8OCRLine" . "\n";
							$OCRLineLength = length($UTF8OCRLine);
						}
					}

				}    # While text is left in the line

				close(CSVFILESFILE);
	
   #Scan through the markFound array printing any elements that we not set to -1
   #print Dumper( \@markFoundContents);
   #print "\nDone Making $XMLOutLine\n";
   #print $XMLOutLine . "\n";
				print ERRORLOG $FileWPath . "\n";
				my $Element;
				#print "\nLooking for unfound elements from the parsed file\n";
				#print "There are  @markFoundContents elements\n";
				$indexE = 0;
				#print "\nBefore cleanup:$XMLOutLine\n";
				$XMLOutLine = CleanXML($XMLOutLine);
				#print "After cleanup:$XMLOutLine\n";
				
				#$XMLOutLine = encode($enc,$XMLOutLine);
				#$XMLOutLine = XMLSpecialChars($XMLOutLine);

				print ERRORLOG "<labeldata>" . $XMLOutLine . "<\/labeldata>" . "\n";
				my $xmlS = new XML::Simple;
				my $bracketedXML = "<labeldata>" . $XMLOutLine . "<\/labeldata>";
				my $FieldList = $xmlS->XMLin( $bracketedXML );
				
				print Dumper($FieldList);

 				#my $validChars = "abcdefghijklmnopqrstuvwxyz,.°'\"`";; # character vocabulary
 				#print "\n";
				my $matchedStringinXML;
				my $valueOfMaxMatch;
				my $threshholdMatch = .9;
				while ( $indexE < @SortedDwCContentsContents ) {
					$Element = shift(@markFoundContents);
					if (   $Element != -1
						&& $DwCElementName[ $SortedDwCContentsIndices[$indexE] ]
						ne "lbx:ot" )
					{

# print ERRORLOG $SortedDwCContentsContents[$Element] . "\n";
# The unfound item must be imbedded in one of the <ot> items but have a minor difference from the string embeded in the CVS
# If it is a long string with many words try a phrese match
# If it is short use Levenstein distance to find it
# Loop through <>ot> elements
# For each <ot> sting assign a phrase distance, pick the lowest distance and reassign the <ot> type to that matching element type.
						$valueOfMaxMatch = 0;
						foreach my $Field ( @{ $FieldList->{ot} } ) {
							#print "SortedContents:$SortedDwCContentsContents[$indexE]\n";
							#print "Field: $Field\n";
							#print "DwCELement:$DwCElementName[ $SortedDwCContentsIndices[$indexE] ]\n";
							# score each of the unknows aginst the <ot> codes
							# use the highest match above the threshold;
							my $matchValue =
							  simplePhraseDist(
								$SortedDwCContentsContents[$indexE], $Field );
							if (   $matchValue > $valueOfMaxMatch
								&& $matchValue > $threshholdMatch )
							{
								print "*****PhraseMatch $Field\n";
								$valueOfMaxMatch    = $matchValue;
								$matchedStringinXML = $Field;
							}
						}
						if ( $valueOfMaxMatch > 0 ) {

							#replace the
							my $newString = "<"
							  . $DwCElementName
							  [ $SortedDwCContentsIndices[$indexE] ] . ">"
							  . $SortedDwCContentsContents[$indexE] . "</"
							  . $DwCElementName
							  [ $SortedDwCContentsIndices[$indexE] ] . ">";
							$XMLOutLine =~
							  s/<ot>$matchedStringinXML<\/ot>/$newString/;
						}

					#$LocInString = index(lc($UTF8OCRLine), lc( $SortedDwCContentsContents[$indexE]));

					}
					$indexE++;
				}

=begin comment
				$XMLOutLine =~
				  s/<lbx:/</g;    # Remove name space dwc: to concat other
				$XMLOutLine =~ s/<\/lbx:/<\//g;
				$XMLOutLine =~
				  s/<dwc:/</g;    # Remove name space dwc: to concat other
				$XMLOutLine =~ s/<\/dwc:/<\//g;
				$XMLOutLine =~
				  s/<aocr:/</g;    # Remove name space aocr: to concat other
				$XMLOutLine =~ s/<\/aocr:/<\//g;
				$XMLOutLine =~
				  s/<\/ot><ot>/ /g;    # Remove tags <ot></ot> to concat other
				$XMLOutLine =~
				  s/<\/ot> <ot>/ /g;    # Remove tags <ot></ot> to concat other
				$XMLOutLine =~ s/  / /g;    # Remove double spaces
=end comment
=cut
				$XMLOutLine = RestoreXMLSpecialChar($XMLOutLine);
				#print "Befor cleanup 2:$XMLOutLine\n";
				$XMLOutLine = CleanXML($XMLOutLine);
				#print "After cleanup 2:$XMLOutLine\n";
				#print "XMLOutLine before RestoreSpacing\n$XMLOutLine\n";
				$XMLOutLine = RestoreOCRSpacing( $XMLOutLine, $OCRLine );

				print "\nAfter XMLOutLine reformat\n";
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
	}    # End while files to read
}    # end sub
########################
sub CleanXML {
	my ($XMLOutLine2) = @_;
	$XMLOutLine2 =~ s/<lbx:/</g;    # Remove name space dwc: to concat other
	$XMLOutLine2 =~ s/<\/lbx:/<\//g;
	$XMLOutLine2 =~ s/<dwc:/</g;    # Remove name space dwc: to concat other
	$XMLOutLine2 =~ s/<\/dwc:/<\//g;
	$XMLOutLine2 =~ s/<aocr:/</g;    # Remove name space aocr: to concat other
	$XMLOutLine2 =~ s/<\/aocr:/<\//g;
	$XMLOutLine2 =~ s/\t/ /g;    # replace tab with space
	$XMLOutLine2 =~ s/  / /g;    # Remove double spaces
	$XMLOutLine2 =~  s/<\/ot><ot>//g;    # Remove tags </ot><ot> to concat other
	$XMLOutLine2 =~  s/<\/ot> <ot>//g;    # Remove tags </ot> <ot> to concat other
	$XMLOutLine2 =~  s/<ot> <\/ot>//g;    # Remove tags <ot></ot> to concat other
	$XMLOutLine2 =~  s/<ot>\0 <\/ot>//g;    # Remove tags <ot></ot> to concat other tenn-00003 had an embedded null
	$XMLOutLine2 =~  s/<ot><\/ot>//g;     # Remove tags <ot></ot> to concat other
	return $XMLOutLine2;
}				

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

}    # end DumpCharBytes

########################
sub NormalizePunctuation {
	my ($StringToNormalize) = @_;
	my $Stringbuffer = $StringToNormalize;
	$Stringbuffer =~ s/\r\n/ /g;
	$Stringbuffer =~ s/\n/ /g;
	$Stringbuffer =~ s/\t/ /g;
	$Stringbuffer =~ s/=/ = /g;
	$Stringbuffer =~ s/,/ , /g;     #put space around embedded commas
	$Stringbuffer =~ s/;/ ; /g;    #put space around embedded semicollen
	$Stringbuffer =~ s/:/ : /g;    #put space around embedded collen
	$Stringbuffer =~ s/^([A-Z])\.([A-Z])\./$1 . $2 . /g
	  ;    # normalize people's innitials where spaces may or may not exist
	$Stringbuffer =~ s/^([A-Z])\.([A-Z])\.([A-Z])\./$1 . $2 . $3 ./g
	  ;    # normalize people's innitials where spaces may or may not exist
	$Stringbuffer =~ s/(\D)\./$1 . /g;    #put space around embedded peroid
	$Stringbuffer =~ s/ +/ /g;           #remove double space

	return $Stringbuffer;
}    # end NormalizePunctuation()

#########################

=begin comment
NormalizedWithNormalizedPunct {
	my ($changeWord2, $originalWord2) = $_;
	my $normalizedOriginal = NormalizePuntuation($originalWord2);
	my @splitOriginalArray = split (/ /, $normalizedOriginal);
	if ($changeWord2 eq )
}
=end comment
=cut

#########################

sub simplePhraseDist {
	my ( $baseString, $testString ) = (@_);

my $lengthTest = length($testString);
my $lengthBase = length($baseString);
my $sizeRatio = min($lengthBase, $lengthTest)/max($lengthBase,$lengthTest);
#print "%%%%% baseString: $baseString\n";
#print "%%%%% testString: $testString\n";
#print "Size difference = $sizeRatio\n";
#if the length difference is > 50% reject
if ($sizeRatio < .5) { return (0) }
	# ignore case
	my $distance = 0;
	$baseString = lc($baseString);
	$testString = lc($testString);
	$baseString =~ s/ [\.\,;:-] / /g;
	$testString =~ s/ [\.\,;:-] / /g;

	my @baseArray = split( /\s+/, $baseString );
	my @testArray = split( /\s+/, $testString );

	#Find the percentage of words that are different.

# Make two loops. The outter over the baseString.
# the inner multiple passes over the testString
# For each word in the baseString find the closest matching word in the testString
# Add the difference in locations (whcih may be 0) to the difference score
# normalize the score by the length of the baseString



	#print "$#baseArray : $#testArray\n";
	my $matches = 0;

	my $flagMatch = 0;
	for ( my $i = 0 ; $i <= $#baseArray ; $i++ ) {

		#print "COMP\n$baseArray[$i] ";
		my $minDist = max( $#baseArray + 1, $#testArray + 1 );
		$flagMatch = 0;
		for ( my $j = 0 ; $j <= $#testArray ; $j++ ) {
			if ( $baseArray[$i] eq $testArray[$j] ) {

				#print "$testArray[$j]\n";
				$minDist = min( $minDist, abs( $i - $j ) );
				#blank out matching items so they may not be reused.
				$testArray[$j] = "";
				#print "$testArray[$j]\n";
				$flagMatch++;
				$j = $#baseArray;
			}
		}
		if ( $flagMatch > 0 ) { $matches++ }

		#print "$minDist\n";
		$distance += $minDist;

		#print "dist=$distance\n";
	}

	#print $matches . "\n";
	my $weightedScore = ($matches * 2 ) / ( $#baseArray + $#testArray + 2);
	#if removing the first word returns a better score then return NO
	$testString =~ s/^\S+\s*//;
	if (length ($testString) > 1 and $weightedScore > simplePhraseDist ($baseString, $testString)) {
		return (0);
	}
	return ( $weightedScore );
}

#########################
sub MapToUTF8 {
	my ($StringToMap) = @_;
	my $Stringbuffer  = $StringToMap;
	my $Latin1Buffer  = "°";

return($Stringbuffer); # do nothing ???
	#my $UTF8DegreeSign = encode($enc, $Latin1Buffer);
	$Stringbuffer =~
	  s/(\d)(\x{fffd})/$1°/g;    # change latin1 degree sign to UTF-8
	$Stringbuffer =~ s/(\d)(\x{ef}\x{be}\x{b0})/$1°/g;    #
	$Stringbuffer =~
	  s/(\d)(\x{b0})/$1\x{c2}\x{b0}/g;    # change latin1 degree sign to UTF-8
	$Stringbuffer =~
	  s/(\d)(\x{fc})/$1\x{c2}\x{bc}/g;    # change latin1 u umlaut to UTF-8
	$Stringbuffer =~ s/(\x{e1})/\'/g;     # change latin1 u umlaut to UTF-8
	$Stringbuffer =~ s/(\x{ef}\x{be}\x{97})/---/g
	  ;    #(KATAKANA LETTER RA) UTF-8 character | UTF-8 Icons
	$Stringbuffer =~ s/(\x{e2}\x{80}\x{94})/--/g
	  ;    #(KATAKANA LETTER RA) UTF-8 character | UTF-8 Icons
	$Stringbuffer =~ s/(\x{ef}\x{bb}\x{bf})/--/g
	  ;    #(KATAKANA LETTER RA) UTF-8 character | UTF-8 Icons
	$Stringbuffer =~ s/(\x{ef}\x{be}\x{b0})/--/g
	  ;    #(KATAKANA LETTER RA) UTF-8 character | UTF-8 Icons

	$Stringbuffer =~
	  s/(\x{97})/-/g;    #(KATAKANA LETTER RA) UTF-8 character | UTF-8 Icons
	$Stringbuffer =~
	  s/(\x{00})//g;     #(KATAKANA LETTER RA) UTF-8 character | UTF-8 Icons

 #$Stringbuffer =~ s/(\d)(\x{fffd})/$1°/g; # change latin1 degree sign to UTF-8
	return $Stringbuffer;

}    # end MapToUTF8 ()
#########################
sub RemoveBOM { #depricated
	my ($inString) = @_;
	$inString =~ s/(\d)(\x{fffd})/$1°/g;   # change latin1 degree sign to UTF-8
	return $inString;
}
#########################
sub XMLSpecialChars {
	my ($fixThis) = @_;
	$fixThis =~ s/&/&amp;/g;
	$fixThis =~ s/</&lt;/g;
	$fixThis =~ s/>/&gt;/g;
	$fixThis =~ s/#/&#35;/g;
	return $fixThis;
}
#########################
sub RestoreXMLSpecialChar {
	my ($fixThis) = @_;
	$fixThis =~ s/&amp;/&/g;
	$fixThis =~ s/&lt;/</g;
	$fixThis =~ s/&gt;/>/g;
	$fixThis =~ s/&#35;/#/g;
	return $fixThis;
}
#########################
sub RestoreOCRSpacing {
	my ( $ChangeLine, $OriginalLine ) = @_;
	my $newChangeLine;

#DumpCharBytes($OriginalLine);
#Read through the words in each string one by one,
#If the $Changeline is an element tag skip it and read ahead
#If the two words to not match concatinate $OriginalLine with the next word and try again.
#If this fails error and end
# Else return the repaired string
	$ChangeLine =~ s/</ </g;    # add space before and after <>
	$ChangeLine =~ s/>/> /g;
	#$OriginalLine =~ s/<g>/\\<g\\> /g;
	#$OriginalLine = XMLSpecialChars($OriginalLine);
	#print "\nRestoreOCRSpacing:\n$ChangeLine\n";
	#print "original:$OriginalLine\n";
	my @ChangeArray   = split / /,      $ChangeLine;     # add split on "<"
	my @OriginalArray = split / |	|\n/, $OriginalLine;

	#print "@OriginalArray\n";
	my $changeWord;
	my $compoundChangeWord;
	my $originalWord;
	my $XMLContext; # indicated what XML element we are in now.
	while ( @ChangeArray and @OriginalArray ) {
		$originalWord = shift(@OriginalArray);
		while ( $originalWord eq "" ) { $originalWord = shift(@OriginalArray); }
		# if the original is more than one character and it has a trailing comma, pull it off and unshift it on the array
		if (length($originalWord) > 1 and substr ($originalWord, -1) eq ",") {
			unshift (@OriginalArray, ",");
			#print "Rewrote $originalWord\n";
			my $tempLength = length($originalWord) - 1;
			$originalWord = substr ($originalWord, 0, $tempLength);
			#print "Rewrote $originalWord length $tempLength\n";
		}
		$changeWord = shift(@ChangeArray);
		while ( $changeWord eq "" ) { $changeWord = shift(@ChangeArray); }
		print "Starting changeWord is:$changeWord||| OriginalWord = |||$originalWord|||\n";
		#DumpCharBytes($originalWord);
		#DumpCharBytes($changeWord);
		#
		if ($changeWord) {    # if the word is not empty
			if (lc ($changeWord) eq lc ($originalWord) ) {
				print "They are equal\n";
				$newChangeLine .= $changeWord . " ";				
			}
=begin comment
			elsif ( my $terminalChar = DiffIsThePunct( lc($changeWord), lc($originalWord), \@ChangeArray ) )
			{ # try adding the next word maybe punctuation to the changeword and see if it matches then
				 #there is a special case for a ":" at the end of a word. If it is in the orignal attached to a word but split on the XML leave the XML as is.
				$newChangeLine .= $originalWord . " ";
				#unshift( @OriginalArray, $terminalChar );
			}
=end comment
=cut
			elsif ( $changeWord =~ m/<(\/*\w+?)>/ )
				{    # if it is a xml element tag print it to output as is
				$XMLContext = $1;
				$newChangeLine .= $changeWord;
				unshift( @OriginalArray, $originalWord )
				  ;    #the loop will grab the first cell. We need to put it back
			}
			elsif ( my $lengthOfAbbreviation =
				AbbreviationMatch( $changeWord, $originalWord, @ChangeArray ) )
			{

	  			#print "Abbriation Detector said: $lengthOfAbbreviation; $originalWord\n";
				$newChangeLine .= $originalWord . " ";
				#print "newChangeLine=\n$newChangeLine\n";
				while ( $lengthOfAbbreviation-- ) { shift @ChangeArray; }

				#exit;
			}

#			elsif (my $normalizedPunctuationMatch = NormalizedWithNormalizedPunct($changeWord, $originalWord)){
#				$newChangeLine .= $originalWord . " ";
#			}
			elsif ( my $readAheadMatch =
				nextNonTag( $changeWord, $originalWord, \@ChangeArray, \@OriginalArray ) )
			{
				$newChangeLine .= $readAheadMatch;
				#print "??? Look-ahead match $readAheadMatch!!!!\nO|||$originalWord|||\nC|||$changeWord|||\nOriginal:@OriginalArray\n  XML:@ChangeArray\n";
				print ERRORLOG "??? Lookahead match!!!!\nO|||$originalWord|||\nC|||$changeWord|||\nOriginal:@OriginalArray\n  XML:@ChangeArray\n";
			}
=begin comment
			elsif ( my $distance =
				RepacementStringDistance( $originalWord, $changeWord ) < .3 )
			{

				#need to check for single character differences
				print "Short Distance Match=$distance; ($originalWord)=($changeWord)\n";
				$newChangeLine .= $changeWord . " ";
			}
=end comment
=cut
			
			elsif ( length($originalWord) == 1 and isPunctuation($originalWord) )
			{ #If it is a punctuation try saving just that punctuation as an <ot>
				$newChangeLine .= "<ot>" . $originalWord . "</ot> ";
				#print "<ot>" . $originalWord . "</ot>\n";
				unshift( @ChangeArray, $changeWord );
			}
			else {
				#print "Befor Compound Attempt:\nchangeWord=$changeWord\noriginalWord=$originalWord|||\nOriginal:@OriginalArray\n  XML:@ChangeArray\n";
				$compoundChangeWord = $changeWord . shift(@ChangeArray);
				#print "Made compound 1:$compoundChangeWord:$originalWord:\n";
				#DumpCharBytes($compoundChangeWord);
				#print "\n";
				#DumpCharBytes($originalWord);
				#print "\n";
				if ( $compoundChangeWord eq $originalWord ) {
					#print "Match $compoundChangeWord\n";
					$newChangeLine .= $originalWord . " ";
				}
				elsif (my $readAheadMatch = nextNonTag( $compoundChangeWord, $originalWord, \@ChangeArray, \@OriginalArray ) )
				{
					$newChangeLine .= $readAheadMatch;
					print "??? compound Look-ahead match $readAheadMatch!!!!\nO|||$originalWord|||\nC|||$changeWord|||\nOriginal:@OriginalArray\n  XML:@ChangeArray\n";
					print ERRORLOG "??? Lookahead match!!!!\nO|||$originalWord|||\nC|||$changeWord|||\nOriginal:@OriginalArray\n  XML:@ChangeArray\n";
				}
				else {
					$compoundChangeWord = $compoundChangeWord . shift(@ChangeArray);
					print "Made compound 2:$compoundChangeWord\n";
					if ( $compoundChangeWord eq $originalWord ) {
						#print "Match $compoundChangeWord\n";
						$newChangeLine .= $originalWord . " ";
					}
					elsif (index($originalWord, $compoundChangeWord) == 0 ) {
						#if the compound change word metches the beginning of the $original
						#print "Match beginning of compound change word\n";
						my $wordPartRemaining = substr ($originalWord, length($compoundChangeWord));
						#print "WordPart Remaining=$wordPartRemaining\n";
						unshift (@OriginalArray, $wordPartRemaining);
						$newChangeLine .= $compoundChangeWord . " ";
					}
					else {
						print "??? NO MATCH!!!!\nO|||$originalWord|||\nC|||$changeWord|||\nOriginal:@OriginalArray\n  XML:@ChangeArray\n";
						print ERRORLOG "??? NO MATCH!!!!\nO|||$originalWord|||\nC|||$changeWord|||\nOriginal:@OriginalArray\n  XML:@ChangeArray\n";
						$newChangeLine .= "<ot>" . $originalWord . "</ot> ";
						print "<ot>" . $originalWord . "</ot>\n";
						unshift( @ChangeArray, $changeWord );
						exit;
					}
				}
			}
		}
	}

	# remove extra spaces before the next XML element tag
	#print "newChanegLine before extra ot removal RestoreSpacing\n$newChangeLine\n";
	$newChangeLine =~ s/ </</g;
	$newChangeLine =~ s/<\/ot><ot>/ /g;  # Remove tags <ot></ot> to concat other
	#print "newChanegLine at end of RestoreSpacing\n$newChangeLine\n";
	return ($newChangeLine);

}
#########################
sub DiffIsThePunct {
	my ( $changeWord, $originalWord, $changeArray2 ) = @_;

# if the only difference between the two words is the ending punctuation return that punctuation else null
# USAGE: supply two strings to be compared. The longer right string should be the one with the possible punctuation
	my $terminalChar = substr( $originalWord, -1 );    # get the last character
	if ( isPunctuation($terminalChar) ) {
		my $frontString =
		  substr( $originalWord, 0, length($originalWord) - 1 );    # Get everything except the last character
		if ( $changeWord eq $frontString )
		{ # try adding the next word maybe punctuation to the changeword and see if it matches then
			
			#if the next thing on the change array is that punctuation... 
			my $tempNextChangeWord = getNextNonTag(@$changeArray2);
			if ($tempNextChangeWord eq $terminalChar) 
			{ 
				return ($terminalChar);
			}
			
		}
		#???elsif ( RepacementStringDistance( $frontString, $changeWord ) < .45 ) {
		#	return ($terminalChar);
		#}
	}
	return 0;
}
#########################
sub isPunctuation {
	my ($char) = @_;
	$char =~ /[,:;\.]/;
}    

#########################
sub nextNonTag {
	my ( $changeWord2, $originalWord2, $ChangeArray2, $OriginalArray2 ) = @_;

#if the next element is a tag skip it and merge $changeWord with the word after the tab.
	my $couldBeTag;
	my $nextChangeWord;
	my $wordAfterTag;
	#print "@$ChangeArray2\n";
	#print "Original=@$OriginalArray2\n";
	$couldBeTag = shift(@$ChangeArray2);
	while ( $couldBeTag eq "" ) { $couldBeTag = shift(@$ChangeArray2); }

	#print "Tag? $couldBeTag\n";
	if ( $couldBeTag =~ m/<\/*\w+?>/ ) {

		# eat the following tag too
		my $temp;
		$temp = shift(@$ChangeArray2);
		while ( $temp eq "" ) { $temp = shift(@$ChangeArray2); }
		$couldBeTag = $couldBeTag . $temp;
		#print "Seen as a tag\n";
		$wordAfterTag = shift(@$ChangeArray2);
		while ( $wordAfterTag eq "" ) { $wordAfterTag = shift(@$ChangeArray2); }
		$nextChangeWord = $changeWord2 . $wordAfterTag;
		#print "nextChangeWord=$nextChangeWord\n";

		if ( lc ($nextChangeWord) eq lc($originalWord2) ) {

			#make string to print to output
			my $Output = $changeWord2 . $couldBeTag . $wordAfterTag;
			return $Output;
		}
		elsif (index($originalWord2, $nextChangeWord) == 0 ) {
			#if the change word metches the beginning of the $original
			my $Output = $changeWord2 . $couldBeTag;
			#print "wordAfterTag=$wordAfterTag\n";
			unshift( @$ChangeArray2, $wordAfterTag );
			my $wordPartRemaining = substr ($originalWord2, length($changeWord2));
			#print "WordPart Remaining=$wordPartRemaining\n";
			unshift (@$OriginalArray2, $wordPartRemaining);
			return $Output;
		}
		else {
			unshift( @$ChangeArray2, $wordAfterTag );
			unshift( @$ChangeArray2, $couldBeTag );
			return 0;
		}
	}
	elsif (isPunctuation ($couldBeTag)) {
		$nextChangeWord = $changeWord2 . $couldBeTag . " ";
		#the next is a punctuation try putting together.
		if (lc ($nextChangeWord) eq lc($originalWord2)) {
			return $originalWord2;
		}		
	}

	unshift( @$ChangeArray2, $couldBeTag );
	return 0;
}
#########################
sub AbbreviationMatch {
	my ( $changeWord, $originalWord, @ChangeArray ) = @_;

# return the number of characters of an abbreviation match as in "U.S.A." = 6
# read through the original string char by char. Comp to the next array element. If it matches = length of the original string returnt he length of the string
#print "In AbbreviationMatch\n@ChangeArray\n\nchangeWord=$changeWord\noriginalWord=$originalWord\n";
# Find the number of periods in the originalWord
	my $num = $originalWord =~ tr/\.//;

	# if it is 0 return false
	my $newCompound;
	$newCompound = $changeWord;
	if ($num) {

# read the change array until we have $num periods or we hit the end or the concat no longer matches
		my $numofArrayRead = 0;
		foreach my $thisItem (@ChangeArray) {
			$numofArrayRead++;
			$newCompound .= $thisItem;
			if ( lc $newCompound eq lc $originalWord ) {
				return $numofArrayRead;
			}
			elsif ( length($newCompound) >= length($originalWord) ) {
				return 0;
			}
		}
	}
	return 0;
}
#########################
# distance increases for either substitutions or missing characters at the end.
# divide by the length of the shortest string. This leans diff could be greater than 100%
sub RepacementStringDistance {
	my ( $string1, $string2 ) = @_;

	#	$string1 = MapToUTF8($string1);
	#	$string2 = MapToUTF8($string2);

	my @array1 = split( //, $string1 );
	my @array2 = split( //, $string2 );
	my $shortest;
	$shortest = ( $#array1, $#array2 )[ $#array1 > $#array2 ];
	$shortest++;
	my $distance = 0;
	my $char2;
	foreach my $char1 (@array1) {
		if (@array2) {
			$char2 = shift(@array2);
			if ( $char1 ne $char2 ) {
				$distance++;
			}
		}
		else { $distance++ }

		#print "$char1:$char2:$distance\n";
	}

# if there is anything left in array 2 increase distance by the number of elements
	if (@array2) { $distance += @array2; }
	if ( $shortest == 0 ) { $shortest = .00001; }

#print "\nS1:$string1:S2:$string2:Shortest:$shortest:Dist=($distance/$shortest)\n";
	return $distance / $shortest;
}
