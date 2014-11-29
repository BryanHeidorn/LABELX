#!perl
use strict;
use warnings;

#use File::Slurp;
use Term::ReadKey;
use File::Spec::Functions 'catfile';
use Text::CSV_PP;
use feature "switch";
#use UTF8;
#use Switch;
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

if ( $numargs ne "2" ) {
	print
"Usage:  $0  OCRRootDirectory OutputFileName\n";
	die;
}
my $CSVRootDirectory       = $ARGV[0];
my $CSVMasterFileName 		= $ARGV[1];
my	@ColumnHeaders = (
		'ID',
		'InstitutionID',
       'dwc:datasetName',
       'dwc:catalogNumber',  
       'occurrenceRemarks',
       'dwc:recordNumber',
       'dwc:recordedBy',
       'dwc:sex',       
       'otherCatalogNumbers', 
       'dwc:associatedTaxa',
       'eventID',
        'dwc:eventDate',
       'year',
       'month',
       'day',
       'dwc:verbatimEventDate',
       'dwc:habitat',
       'fieldNumber',
       'dwc:fieldNotes',
       'dwc:country',
       'dwc:stateProvince',
       'dwc:county',
       'dwc:municipality',
       'locationID',
       'locality',
       'dwc:verbatimLocality',
       'dwc:verbatimElevation',
       'minimumElevationInMeters',
       'maximumElevationInMeters',
       'dwc:verbatimCoordinates',
       'dwc:verbatimLatitude',
       'dwc:verbatimLongitude',
       'dwc:substrate',
       'aocr:verbatimScientificName',
       'aocr:verbatimInstitution',
       'dwc:decimalLatitude',
       'dwc:decimalLongitude',
       'identificationID',
       'dwc:identifiedBy',
       'dwc:dateIdentified',
       'identificationRemarks',
       'identificationQualifier',
       'taxonID',
       'typeStatus',
       'dwc:scientificName',
       'family',
       'genus',
       'specificEpithet',
       'infraspecificEpithet',
       'taxonRank',
       'scientificNameAuthorship',
       'basisOfRecord',
		'occurrenceID'
	);

my $IDCounter;
my $OccurrenceIDCounter; 
my $EventIDCounter; 
my $TaxonIDCounter;  
my $IdentificationIDCounter;  
my $LocationIDCounter;  
#We really shoudl have commandline flags to set these.
$IDCounter = $IdentificationIDCounter = $LocationIDCounter = $TaxonIDCounter = $EventIDCounter = $OccurrenceIDCounter = 0;

#open ErrorLog
my @markFoundContents;
open( ERRORLOG, ">>ERRORCSV.log" )
	 || die "$! Could not Open ERRORCSV.log";
open( OUTPUT, ">$CSVMasterFileName" )
	 || die "$! Could not Open ERRORCSV.log";
my $Element;
my $Buffer = ""; 
my @ColumnHeaderConsumable = @ColumnHeaders;
foreach $Element (@ColumnHeaderConsumable) {
	$Element =~ s/dwc://; #The DwC names must not have namespace designators
	$Buffer = $Buffer .  '"' .$Element . '"' . ',';
}
$Buffer =~ s/,$/\n/; # replace trailing tab with newline
print OUTPUT "$Buffer";
print "$Buffer";
#print "@ColumnHeaders\n";


ReadAllCSVFiles($CSVRootDirectory);
close (ERRORLOG);
close (OUTPUT);
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
	my $OccurrenceIDString;
	my $LocationIDString;
	my $EventIDString;
	my $TaxonIDString;
	my $IdentificationIDString;
#	my $ColumnHeaders;
	local *DIRROOT;
	#print "$SubDirName\n";
	
	opendir( DIRROOT, $SubDirName )
	  or die 'Cannot open directory ', *DIRROOT, $SubDirName, ": $!";

	while ( my $fn = readdir DIRROOT ) {
		$FileWPath = $SubDirName . '\\' . $fn;    #slash for Windows
		$FileWPath = $SubDirName . '/' . $fn;     #slash for Macs

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
				print "Open $FileWPath\n";
				local *CSVFILESFILE;
				#unless ( open( CSVFILESFILE, "<:encoding(utf8)", $FileWPath ) ) {
				unless ( open( CSVFILESFILE, "<:encoding(ISO-8859-1)", $FileWPath ) ) {
					print "$0 Error: ", $FileWPath,
					  " CSV file of file names cannot be opened.\n";
					die;
				}
				#print "processing ", $FileWPath, "\n";
				#print "fn = $fn\n";
				#print "CSVRootDirectory = $CSVRootDirectory\n";
				#print "OCRRootDirectory = $OCRRootDirectory\n";
				#print "XMLRootDirectory = $XMLOutputRootDirectory\n";

				# Replace the most specific subdirectory name with the most
				# specific directory of the text directories
				my $RootofCSV;
				$RootofCSV = $CSVRootDirectory;
				$RootofCSV =~ s/\w+$//;
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


				my @DwCElementName;
				my @DwCContentFields;

				my $NumCSVColumns;
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
				else { die "Could not parse CSV First Line of \n"; }

				# Read through all remaining lines of the CSV
				# Every time we need to search a CSV line we need to restore the $UTF8OCRLine since it is "used up"
				my $OCRLineProtected;
				$OCRLineProtected = $UTF8OCRLine;
				# This is set up to do more than one line but for now will only deal with the line 2 which is primary labels in the herbarium collection
				#The occurrenceID shoudl be the same for all datalines in a file. We advance it once for each file.
				$OccurrenceIDString = "ark:/21547/Ff2_" . $OccurrenceIDCounter;
				$OccurrenceIDCounter++;
				$LocationIDString = "ark:/21547/Fh2_" . $LocationIDCounter;
				$LocationIDCounter++;
				#$IdentificationIDString = "ark:/21547/Fj2_" . $IdentificationIDCounter;
				#$IdentificationIDCounter++;
				#$TaxonIDString = "ark:/21547/Fi2_" . $TaxonIDCounter;
				#$TaxonIDCounter++;
				$EventIDString = "ark:/21547/Fg2_" . $EventIDCounter;
				$EventIDCounter++;
				while ( $line = <CSVFILESFILE> ) {
					chomp $line;
					$UTF8CSVLine = $line;
					#print Dumper( \$UTF8CSVLine );
					
					if ( $csv->parse($UTF8CSVLine) ) {
						@DwCContentFields = $csv->fields();
						$NumCSVColumns    = $#DwCElementName;
						my $i;
						#  there may be X columns but some contents may be empty. e.g. the 5th may have no key in the hash yet we try to assign a 5 to it.
						#Make a Hash where the Key is the Element name and the Value is the Contents
						my %DwCContentsHash;    # = @DwCContentFields;
						for ( $i = 0 ; $i < $NumCSVColumns ; $i++ ) {
							if ( $DwCContentFields[$i] ) {
								$DwCContentsHash{"$DwCElementName[$i]"} = $DwCContentFields[$i];    #assigns content strings as hash values
								#print "$i Value = $DwCContentFields[$i]; Key = $DwCElementName[$i]\n";
							} 
						}
						if (exists $DwCContentsHash{"aocr:regionType"} and ($DwCContentsHash{"aocr:regionType"} eq "barcode" or $DwCContentsHash{"aocr:regionType"} eq "curatorial")) {
							print "****** Found a barcode or curitorial line line. Skip it " . $DwCContentsHash{"aocr:regionType"} . " *******\n"
						}
						else {
							# Output a row
							#print Dumper(\%DwCContentsHash);
							# to do: set verbatimScientific name into Scientific Name if that is not already filled
							# to do: set the verbatimInstitution to InstitutionCode, unless it is already filled
							# to do: incrament the IdentificationID if verbatimScientificName or Scientific Name are set.
							$IDCounter = $IDCounter +1;
							my $MasterOut = "";
							my @ColumnHeaderConsumable = @ColumnHeaders;
							# if the scientif Name is empty copy the verbatim name there
							if (exists $DwCContentsHash{"aocr:verbatimScientificName"} and !exists $DwCContentsHash{"dwc:ScientificName"}) {
								$DwCContentsHash{"dwc:ScientificName"} = $DwCContentsHash{"aocr:verbatimScientificName"};
							}
							my $j=0;
							while ($j<=$#ColumnHeaderConsumable) {
    							#print $j,$ColumnHeaderConsumable[$j],"; ";
 								if ($DwCContentsHash{$ColumnHeaderConsumable[$j]}) {
 									# If there is a scientific name incrament the Identification and TaxonIDs
 									if ($ColumnHeaderConsumable[$j] eq "aocr:verbatimScientificName") {
 										#incrament the IdentificationID and the TaxonID.
 										$TaxonIDCounter++;	
 										$IdentificationIDCounter++;									
 									}
 									my $QuotedMatch = $DwCContentsHash{$ColumnHeaderConsumable[$j]};
 									$QuotedMatch =~ s/"/""/g;
 									$QuotedMatch = "\"$QuotedMatch\"";
									$MasterOut =  $MasterOut . $QuotedMatch . ",";
								} 
								else {
									# if it is an ID field add the QUID else just comma
									given ($ColumnHeaderConsumable[$j]) {
										when ("occurrenceID") { $MasterOut =  $MasterOut . $OccurrenceIDString . ","; }
										when ("ID") { $MasterOut =  $MasterOut . $IDCounter . ","; }
										when ("taxonID") { # Taxon ID chenges with each label not each specimen
											$TaxonIDString = "ark:/21547/Fi2_" . $TaxonIDCounter;
											$MasterOut =  $MasterOut . $TaxonIDString . ","; 
										}
										when ("eventID") { $MasterOut =  $MasterOut . $EventIDString . ","; }
										when ("identificationID") { 
											$IdentificationIDString = "ark:/21547/Fj2_" . $IdentificationIDCounter;
											$MasterOut =  $MasterOut . $IdentificationIDString . ","; }
										when ("locationID") { $MasterOut =  $MasterOut . $LocationIDString . ","; }
										when ("basisOfRecord") { $MasterOut =  $MasterOut . "PreservedSpecimen,"; }
										default {$MasterOut =  $MasterOut . ",";}
									} # end switch
								} # end else
	    						$j++;
							} # End While columns
							$MasterOut =~ s/,$/\n/;
							print OUTPUT $MasterOut;
							print "\n$MasterOut\n ";
						}
						}    # else
					else {
						print ERRORLOG  "Could not parse CSV First Line in file $FileWPath\n";
					}
				}


		close(CSVFILESFILE);
		#Scan through the markFound array printing any elements that we not set to -1
		#print Dumper( \@markFoundContents);
		print ERRORLOG $FileWPath . "\n";
			}    # end elseif
		}  # end unless
		   #closedir DIRROOT or die 'Cannot close directory ', *DIRROOT, ": $!";
	}    # End while files to process
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

