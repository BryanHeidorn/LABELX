#!/usr/bin/perl
# Convert LABELX XML FIles to CSV
# use module
use strict;
use warnings;

use XML::LibXML;
use Data::Dumper;
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

	my @nameSpaceArray = ( [
	"dwc:catalogNumber",
	"dwc:recordedBy",
	"dwc:recordNumber",
	"dwc:verbatimEventDate",
	"aocr:verbatimScientificName",
	"aocr:verbatimInstitution",
	"dwc:datasetName",
	"dwc:verbatimLocality",
	"dwc:country",
	"dwc:stateProvince",
	"dwc:county",
	"dwc:verbatimLatitude",
	"dwc:verbatimLongitude",
	"dwc:verbatimElevation",
	"dwc:eventDate",
	"dwc:scientificName",
	"dwc:decimalLatitude",
	"dwc:decimalLongitude",
	"dwc:fieldNotes",
	"dwc:sex",
	"dwc:dateIdentified",
	"dwc:identifiedBy"],
		
	["catalogNumber",
	"recordedBy",
	"recordNumber",
	"verbatimEventDate",
	"verbatimScientificName",
	"verbatimInstitution",
	"datasetName",
	"verbatimLocality",
	"country",
	"stateProvince",
	"county",
	"verbatimLatitude",
	"verbatimLongitude",
	"verbatimElevation",
	"eventDate",
	"scientificName",
	"decimalLatitude",
	"decimalLongitude",
	"fieldNotes",
	"sex",
	"dateIdentified",
	"identifiedBy"]
	
	);
# create object
#$xml = new XML::Simple;
my $parser = XML::LibXML->new();

my $file_name = "";
# read XML file
my $error_num = 0;
my $line;
my $CSVFileName;
$file_name = $XMLRootDirectory . "*";
print "Directory to open: $file_name\n";

#my @files = <herb/gold/HerbGoldXML/*>; # Rootdirectory
my @files = < $file_name >; # Rootdirectory
foreach my $filename (@files) {
	print "file=$filename\n";
	my $doc = $parser->parse_file($filename);
	
   	#open(DAT, $file) || die("Could not open file!");
   	#binmode(DAT, ":utf8");
   	#my @raw_data=<DAT>;
   	#foreach $line (@raw_data){
   	#$line = XMLSpecialChars($line);
	#print $line;
   	#}
   	foreach my $DWCElement ($doc->findnodes('/labeldata')) {
    my($title) = $book->findnodes('./title');
    print $title->to_literal, "\n" 
  }
   	
   eval{
      $data = $xml->XMLin($file);
      print Dumper($data);
   };
   if ($@) {
      print "error occurred:$@\n";
      $debug = ">>00debug.txt";
      open (DEFILE, $debug) || die("Could not open file!");
      print DEFILE "error occurred:$@\n";
      print DEFILE $line; 
      close(DEFILE);
      $error_num++;
   }
   
   my $a="";
   my $b="";
   my $first=1;
   while( my ($key, $value) = each %$data )
   {
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
