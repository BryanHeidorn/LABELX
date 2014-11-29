LABELX
======

Label Annotation Through Biodiversity Enhanced Learning

This is part of a set of programs to take images of natural history museum 
labels and convert them into structured for mat for database ingest. 

CreateFrequencyDictionary.pl created a dictionary of all words in a set of OCR 
output that was stored in a a directory. The dictionary is sorted in order of 
frequency from least frequent to most frequent and in alphabetical order within
a given frequency. The output of this program is used as input to 
FilterLabelsonWordFreqV2.pl.

FilterLabelsonWordFreqV2.pl accepts a set of OCR files and decides which are of high enough quality for later processing. If there are too many rare words that do not normally appear in the total collection of OCR output it is rejected. Accepts a frequency dictionary where the frequency 
of a word within a collection is in the first column and the word itself is in 
the second. See CreateFrequencyDictionary.pl for details. It also accepts a 
directory that contains the files output by OCR where the words are conted.  

OCRtoXML.pl is a perl program that accepts a path to a set of human created CSV
files containing a parse or reorganization of contents into columns that 
represent Darwin Core fields. The column order is determined by the person doing
the data entry. The prgram reads these files and then searches
OCR output text files to find the string and then generates an ordered XML 
file with the same information but now with the original label order restored.

The XML is used to training a HMM for processing of new labels.
These XML files can also be used to quality accurence of the CSV files. When
people type the CSV files they sometimes change the contoent of the label.
For our purposes we need exact transcriptions of the contents of the OCR text
file without human interpretation. These changes are difficult to see but the 
computer notices any difference no matter how subtle. Any string that differs
from the OCR is coded as <ot> or "other" in the XML. It is relatively easy to
see these tags and go back to the CSV and make necessary edits to match the 
OCR exactly.

