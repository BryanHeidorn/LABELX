#!/usr/bin/perl
# Convert LABELX XML FIles to CSV
# use module
use strict;
use warnings;

use XML::LibXML;
use XML::Simple;
use Data::Dump;
my $enc = 'utf-8'; # This script is stored as UTF-8
binmode(STDOUT, ":utf8");
use charnames ':full';
#############################################################################
# PERL Program "XMLtoCSV.pl"
#
# Oct 28, 2014
# Nov 5, 2014: Use LibXML instead of ML::Simple to allow element ordering.
# Bryan Heidorn
#
# This program reads XML Directories. It is assumed that the file names are the
# same except for the file extensions differ (i.e. .txt and .CSV)

# Usage: CSVtoXML.pl OCRRootDirectory CSVRootDirectory XMLOutputRootDirectory

#############################################################################

my $numargs = @ARGV;

if ( $numargs ne "2" ) {
	print
"Usage:  $0  XMLRootDirectory FullPathTOCSVRootDirectory\n";
	die;
}

my $XMLRootDirectory       = $ARGV[0];
my $CSVRootDirectory       = $ARGV[1];

# create object
my $xml = new XML::Simple;
my $file_name = "";
# read XML file
my $error_num = 0;
my $line;
my $CSVFileName;
my $data;
$file_name = $XMLRootDirectory . "*";
print "Directory to open: $file_name\n";


#my @files = <herb/gold/HerbGoldXML/*>; # Rootdirectory
my @files = < $file_name >; # Rootdirectory
foreach my $file (@files) {
	print "file=$file\n";
   open(DAT, $file) || die("Could not open file!");
   binmode(DAT, ":utf8");
   my @raw_data=<DAT>;
   #foreach $line (@raw_data){
   	#$line = XMLSpecialChars($line);
      #print $line;
   #}
   eval{
      $data = $xml->XMLin($file);
      print Dumper($data);
   };
   if ($@) {
      print "error occurred:$@\n";
      my $debug = ">>00debug.txt";
      open (DEFILE, $debug) || die("Could not open file!");
      print DEFILE "error occurred:$@\n";
      print DEFILE $data; 
      close(DEFILE);
      $error_num++;
   }
   
   my $a="";
   my $b="";
   my $first=1;
   while( my ($key, $value) = each %$data )
   {
   	$key = AddNameSpace($key);
     # removed because might be an array $value = "\"".$value."\"";   
      my $count;
      if (ref($value) eq 'ARRAY') 
      	{ $count = @$value; } 
      	else { 
      		$count=0; 
      	}
      print "count: $count ::: $key value:$value\n";
      	
      if($first==1){
         if($count==0){
            $a = $a.$key;
            $b = $b."\"".$value."\"";
         } else{
            foreach my $v (@$value) {
               $a = $a.$key;
               $b = $b.$v;
            }
         }
         $first = 0;
      }
      else {
         if($count==0) {
               $a = $a.",".$key;
               $b = $b.",\"".$value."\"";
            }
         else{
         	   $a = $a.",".$key;
               #$b = $b.",\"".shift(@$value)."\"";
               $b = $b.",\"".shift(@$value);
            foreach my $v (@$value){
               #$a = $a.",".$key;
               $b = $b.";".$v;
            }
            $b = $b."\"";
         }
      }
   }
   $CSVFileName = substr( $file, length($XMLRootDirectory) ); 
   $CSVFileName =~ s/xml$/csv/;
   $CSVFileName = $CSVRootDirectory . $CSVFileName;
   print "Output file=$CSVFileName\n";
   print "$a\n";
   print "$b\n";
	open( CSVOUTFILE, ">:encoding(UTF-8)", $CSVFileName )
				  || die "$! Could not Open $CSVFileName";
   print CSVOUTFILE $a."\n";
   print CSVOUTFILE $b;
   close (CSVOUTFILE); 
   #last;
}


print $error_num;
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
sub AddNameSpace {
	my ($input) = @_;
	my $output;
	my %nameSpaceHash = ( 
	'catalogNumber' => 'dwc:catalogNumber',
	'recordedBy' => 'dwc:recordedBy',
	'recordNumber' => 'dwc:recordNumber',
	'verbatimEventDate' => 'dwc:verbatimEventDate',
	'verbatimScientificName' => 'aocr:verbatimScientificName',
	'verbatimInstitution' => 'aocr:verbatimInstitution',
	'datasetName' => 'dwc:datasetName',
	'verbatimLocality' => 'dwc:verbatimLocality',
	'country' => 'dwc:country',
	'stateProvince' => 'dwc:stateProvince',
	'county' => 'dwc:county',
	'verbatimLatitude' => 'dwc:verbatimLatitude',
	'verbatimLongitude' => 'dwc:verbatimLongitude',
	'verbatimElevation' => 'dwc:verbatimElevation',
	'eventDate' => 'dwc:eventDate',
	'scientificName' => 'dwc:scientificName',
	'decimalLatitude' => 'dwc:decimalLatitude',
	'decimalLongitude' => 'dwc:decimalLongitude',
	'fieldNotes' => 'dwc:fieldNotes',
	'sex' => 'dwc:sex', 
	'dateIdentified' => 'dwc:dateIdentified',
	'identifiedBy' => 'dwc:identifiedBy'
);

	if (exists $nameSpaceHash{$input}) {
		$output = $nameSpaceHash{$input};
	} else {
		$output = $input;	
	}
	
	return($output);
}
#########################
