#!perl
use strict;
use warnings;
use List::Util qw[min max];

use Data::Dumper;
#use UTF8;

#########################

my $enc = 'utf-8'; # This script is stored as UTF-8

use Text::PhraseDistance qw(pdistance); 
my $s1 = "Lich Arctoi  90. I860. � Lecanora badiojusca Nyl . , Herb . Mus . Fenn . 110. 1859 - Acarospora boulderensis Magn . in Goteb . Kgl . Vet . Handl . F .6 ser . B ,6 , No . 7 : 16. 1956. � A asperata Magn . l .c . p . 17. � A cal- ifornica Zahlbr . ined . cf . Typus in herb Vienna No . 1026 , non Hasse descr . et Isotypus No . 1385 in Bryologist 17 : 62. 1914. � A . irregularis Magn . , Monogr . Acar . 229. 1929."; 
my $s2 = "COUNTRY :";
#my $s2 = "Lich Arctoi 90. I860. � Lecanora badiojusca Nyl . , Herb . Mus . Fenn . 110. 1859 - Acarospora boulderensis Magn . in Goteb . Kgl . Vet . Handl . F .6 ser . B ,6 , No . 7 : 16. 1956. � A asperata Magn . l .c . p . 17. � A cal- ifornica Zahlbr . ined . cf . Typus in herb Vienna No . 1026 , non Hasse descr . et Isotypus No . 1385 in Bryologist 17 : 62. 1914. � A . irregularis Magn . , Monogr . Acar . 229. 1929.";

print simplePhraseDist($s1, $s2);
exit;

#########################
sub simplePhraseDist {
	my ($baseString, $testString) = (@_);
	# ignore case
	my $distance = 0;
	$baseString = lc($baseString);
	$testString = lc($testString);
	my @baseArray = split ( /\s+/, $baseString );
	my @testArray = split ( /\s+/, $testString );
	# Make two loops. The outter over the baseString.
	# the inner multiple passes over the testString
	# For each word in the baseString find the closest matching word in the testString
	# Add the difference in locations (whcih may be 0) to the difference score
	# normalize the score by the length of the baseString
	
	#print "$#baseArray : $#testArray\n";
	for (my $i = 0; $i <= $#baseArray; $i++) {
		#print "comp\n$baseArray[$i]\n";
		my $minDist = $#baseArray;
		for (my $j = 0; $j <= $#testArray; $j++) {
			#print "$testArray[$j]\n";
			if ($baseArray[$i] eq $testArray[$j] ) {
				$minDist = min($minDist, abs($i - $j));
			}
		}
		#print "$minDist\n";
		$distance += $minDist;
	}
	return $distance/($#baseArray+1);
}

#########################