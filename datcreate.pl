use strict;
use warnings;
use Term::ProgressBar;
use Archive::Zip qw/:ERROR_CODES :CONSTANTS/;
use Digest::CRC qw(crc64 crc32 crc16 crcccitt crc crc8 crcopenpgparmor);
use Digest::MD5;
use Digest::SHA1  qw(sha1 sha1_hex sha1_base64);
use POSIX qw(strftime);

#init
my $datfile = "";
my $system = "";
my $discdirectory = "";
my $process = "";
my $substringh = "-h";
my $substringr = "-r";
my $substringn = "-n";
my $filebincue = "FALSE";
my $datbincue = "FALSE";
my $redump = "FALSE";
my $nointro = "FALSE";
my @linesdat;
my @linesgames;
my @linesmatch;
my @linesmiss;
my @alllinesout;

#check command line
foreach my $argument (@ARGV) {
  if ($argument =~ /\Q$substringh\E/) {
    print "datcreate v0.7 - Utility to compare No-Intro or Redump dat files to the -converted- rom or disc\n";
    print "                 collection (by name) and create an XML database of hashses (crc32, md5, sha1) from\n";
    print "                 the derivatives of original games hashes.\n";
  	print "\n";
	print "with datcreate [ options ] [dat file ...] [directory ...] [system] [process]\n";
	print "\n";
	print "Options:\n";
	print "  -r    Redump source dat\n";
	print "  -n    No-Intro source dat\n";
	print "\n";
	print "Example:\n";
	print '              datcreate -r "D:/Atari - 2600.dat" "D:/Atari - 2600/Games" "Atari - 2600" "maxcso_1_12_0"' . "\n";
	print "\n";
	print "Author:\n";
	print "   Discord - Romeo#3620\n";
	print "\n";
    exit;
  }
  if ($argument =~ /\Q$substringr\E/) {
    $redump = "TRUE";
  }
  if ($argument =~ /\Q$substringn\E/) {
    $nointro = "TRUE";
  }
}

#set paths and system variables
if (scalar(@ARGV) < 5 or scalar(@ARGV) > 5) {
  print "Invalid command line.. exit\n";
  print "use: datcreate -h\n";
  print "\n";
  exit;
}
$datfile = $ARGV[-4];
$discdirectory = $ARGV[-3];
$system = $ARGV[-2];
$process = $ARGV[-1];

#debug
print "dat file: $datfile\n";
print "game directory: $discdirectory\n";

#exit no parameters
if ($datfile eq "" or $process eq "" or $system eq "" or $discdirectory eq "") {
  print "Invalid command line.. exit\n";
  print "use: datcreate -h\n";
  print "\n";
  exit;
}

#read dat file
open(FILE, "<", $datfile) or die "Could not open $datfile\n";
while (my $readline = <FILE>) {
   push(@linesdat, $readline);
   if (index(lc $readline, ".cue") != -1)
   {
      $datbincue = "TRUE";
   }
}
my @sorteddatfile = @linesdat;
close (FILE);

#read games directory contents
my $dirname = $discdirectory;
opendir(DIR, $dirname) or die "Could not open $dirname\n";
while (my $filename = readdir(DIR)) {
  if (-d $dirname . "/" . $filename) {
    next;
  } else {
    push(@linesgames, $filename) unless $filename eq '.' or $filename eq '..';
	if (index(lc $filename, ".cue") != -1)
	{
       $filebincue = "TRUE";
	}
  }
}
closedir(DIR);

#init header
my $date = strftime "%Y-%m-%d %H-%M-%S", localtime;

#write XML header
open(FILE, '>', "$system ($date).dat") or die "Could not open file '$system ($date).dat' $!";
print FILE "<datafile>\n";
print FILE "    <header>\n";
print FILE "        <name>$system</name>\n";
print FILE "        <description>$datfile</description>\n";
print FILE "        <version>$date</version>\n";
print FILE "        <date>$date</date>\n";
print FILE "        <author>CRoSG</author>\n";
print FILE "    </header>\n";

my $romname = "";
my $gamename = "";
my $datsize = "";
my $datcrc = "";
my $datmd5 = "";
my $datsha1 = "";
my $resultromstart;
my $resultromend;
my $resultgamestart;
my $resultgameend;
my $extpos;
my $extlen;
my $quotepos;
my $match = 0;
my $filesize;
my $filecrc;
my $filemd5;
my $filesha1;
my $gamefileext;
my $datfileext;
my $cuedatline;
my $totalmatches = 0;
my $totalmisses = 0;
my $totalmissesfiles = 0;
my $totalextrafiles = 0;
my $totalfuzzymatches = 0;
my $any_matched;
my $length = 0;
my $i=0;
my $j=0;
my $p=0;
my $q=0;

my @matches;
my @extrafiles;
my @sortedromenames;
my $max = scalar(@linesgames);
my $progress = Term::ProgressBar->new({name => 'progress', count => $max});

#loop though each filename
OUTER: foreach my $gameline (@linesgames)
{
   $progress->update($_);
   $p++;
   
   #parse game name
   if (index(lc $gameline, ".m3u") == -1)
   {
      $match = 0;
      my $length = length($gameline);
      my $rightdot = rindex($gameline, ".");
      my $suffixlength = $length - $rightdot;
      $gamefileext = substr($gameline, $rightdot, $suffixlength);
      $gamename  = substr($gameline, 0, $length - $suffixlength);

      #calculate size
      $filesize = (stat $discdirectory . "/" . $gameline)[7];
      
	  #calculate crc	
      open (my $fh, '<:raw', $discdirectory . "/" . $gameline) or die $!;
	  my $ctx = Digest::CRC->new( type => 'crc32' );
      $ctx->addfile(*$fh);
      close $fh;
      $filecrc = lc $ctx->hexdigest;
	  
	  #calculate md5
      open ($fh, '<:raw', $discdirectory . "/" . $gameline) or die $!;
	  $ctx = Digest::MD5->new;
      $ctx->addfile(*$fh);
      close $fh;
      $filemd5 = lc $ctx->hexdigest;
	  
	  #calculate sha1
      open ($fh, '<:raw', $discdirectory . "/" . $gameline) or die $!;
	  $ctx = Digest::SHA1->new;
      $ctx->addfile(*$fh);
      close $fh;
      $filesha1 = lc $ctx->hexdigest;
	  
	  $match = 0;
	  foreach my $datline (@sorteddatfile) 
      {
         if (index(lc $datline, "<rom name=") != -1)
         {
	        if ($datbincue eq "FALSE")
            {	  
		       #parse rom name
               $resultromstart = index($datline, '<rom name="');
               $resultromend = index($datline, 'size="');
               $extpos = rindex $datline, ".";  
               $quotepos = rindex $datline, '"', $resultromend;
               my $length = ($resultromend)  - ($resultromstart + 12);
               $datfileext = substr($datline, $extpos, $quotepos - $extpos);
               $romname  = substr($datline, $resultromstart + 11, $length - ($quotepos - $extpos + 1));
               $romname =~ s/amp;//g; #clean '&' in the dat file

		       #parse size
		       $resultromstart = index($datline, 'size="');
		       $resultromend = index($datline, 'crc="');
		       $length = ($resultromend)  - ($resultromstart + 7);
		       $datsize = substr($datline, $resultromstart + 6, $length - 1);
         
		       #parse crc
		       $resultromstart = index($datline, 'crc="');
		       $resultromend = index($datline, 'md5="');
		       $length = ($resultromend)  - ($resultromstart + 6);
		       $datcrc = substr($datline, $resultromstart + 5, $length - 1);

		       #parse md5
		       $resultromstart = index($datline, 'md5="');
		       $resultromend = index($datline, 'sha1="');
		       $length = ($resultromend)  - ($resultromstart + 6);
		       $datmd5 = substr($datline, $resultromstart + 5, $length - 1);

		       #parse sha1
		       $resultromstart = index($datline, 'sha1="');
		       $resultromend = index($datline, '"/>');
		       $length = ($resultromend)  - ($resultromstart + 7);
		       $datsha1 = substr($datline, $resultromstart + 6, $length + 1);        

               #check for exact match between dat filename and disc filename
               if (lc $romname eq lc $gamename)
               {
				  $match = 1;
                  $totalmatches++;
                  push(@linesmatch, [$romname, $datcrc, $datmd5, $datsha1]);
				  push(@alllinesout, ["MATCHED: ", "$gamename$gamefileext"]);
				  
				  my $tempsource = "";
				  if ($redump eq "TRUE")
				  {
                     $tempsource = "Redump";
                  } elsif ($nointro eq "TRUE") {
                     $tempsource = "No-Intro";
				  }
				  
                  print FILE '    <game name="' . $romname . '">' . "\n";
                  print FILE '        <description>' . $romname . '</description>' . "\n";
                  print FILE '        <source name="' . $romname . $datfileext . '" type="' . $tempsource . '" size="' . $datsize . '" crc="' . $datcrc . '" md5="' . $datmd5 . '" sha1="' . $datsha1 . '"/>' . "\n";
                  print FILE '        <rom name="' . $gamename . $gamefileext . '" type="' . $process . '" size="' . $filesize . '" crc="' . $filecrc . '" md5="' . $filemd5 . '" sha1="' . $filesha1 . '"/>' . "\n";
                  print FILE '    </game>' . "\n";	  
                  next OUTER;
               }
			}
         }
      }
      
	  $match = 0;
      foreach my $datline (@sorteddatfile)
      {
         if (index(lc $datline, "<rom name=") != -1)
         {
	        if ($datbincue eq "TRUE")
            {
			   #clean '&' in the dat file
			   $datline =~ s/amp;//g; #clean '&' in the dat file
				
	           #parse rom name
               $resultromstart = index($datline, '<rom name="');
               $resultromend = index($datline, 'size="');
               $extpos = rindex $datline, ".";  
               $quotepos = rindex $datline, '"', $resultromend;
               my $length = ($resultromend)  - ($resultromstart + 12);
               $datfileext = substr($datline, $extpos, $quotepos - $extpos);
               $romname  = substr($datline, $resultromstart + 11, $length - ($quotepos - $extpos + 1));
               $romname =~ s/amp;//g; #clean '&' in the dat file

               #parse size
		       $resultromstart = index($datline, 'size="');
		       $resultromend = index($datline, 'crc="');
		       $length = ($resultromend)  - ($resultromstart + 7);
		       $datsize = substr($datline, $resultromstart + 6, $length - 1);
         
		       #parse crc
		       $resultromstart = index($datline, 'crc="');
		       $resultromend = index($datline, 'md5="');
		       $length = ($resultromend)  - ($resultromstart + 6);
		       $datcrc = substr($datline, $resultromstart + 5, $length - 1);

               #parse md5
		       $resultromstart = index($datline, 'md5="');
		       $resultromend = index($datline, 'sha1="');
		       $length = ($resultromend)  - ($resultromstart + 6);
		       $datmd5 = substr($datline, $resultromstart + 5, $length - 1);

               #parse sha1
		       $resultromstart = index($datline, 'sha1="');
		       $resultromend = index($datline, '"/>');
		       $length = ($resultromend)  - ($resultromstart + 7);
		       $datsha1 = substr($datline, $resultromstart + 6, $length + 1); 

		       #check for .cue substring and write to dat
               if (index(lc $datline, lc $gamename . ".cue") != -1)
               {
                  $totalmatches++;
			      push(@alllinesout, ["MATCHED: ", "$gamename$gamefileext"]);
		       
			      #write dat entry up to cue name
		          my $tempsource = "";
		          if ($redump eq "TRUE")
		          {
                     $tempsource = "Redump";
                  } elsif ($nointro eq "TRUE") {
                     $tempsource = "No-Intro";
                  }        
		          print FILE '    <game name="' . $romname . '">' . "\n";
                  print FILE '        <description>' . $romname . '</description>' . "\n";
               }

               #check for substring match between dat romname and gamename 
               if (index(lc $datline, lc $gamename) != -1)
               {
				  my $tempsource = "";
		          if ($redump eq "TRUE")
		          {
                     $tempsource = "Redump";
                  } elsif ($nointro eq "TRUE") {
                     $tempsource = "No-Intro";
                  } 
                  print FILE '        <source name="' . $romname . $datfileext . '" type="' . $tempsource . '" size="' . $datsize . '" crc="' . $datcrc . '" md5="' . $datmd5 . '" sha1="' . $datsha1 . '"/>' . "\n";
               }
			}
		 }
      }
      print FILE '        <rom name="' . $gamename . $gamefileext . '" type="' . $process . '" size="' . $filesize . '" crc="' . $filecrc . '" md5="' . $filemd5 . '" sha1="' . $filesha1 . '"/>' . "\n";
      print FILE '    </game>' . "\n";		  
   }
}

print FILE '</datafile>' . "\n";
close FILE;

#print total have
my $totalnames = 0;
$totalnames = $p;
print "\ntotal matches: $totalmatches of $totalnames\n";

#open log file and print all sorted output
open(LOG, ">", "$system ($date).txt") or die "Could not open $system ($date).txt\n";
print LOG "total matches: $totalmatches of $totalnames\n";
print LOG "---------------------------------------\n";
my @sortedalllinesout = sort{$a->[1] cmp $b->[1]} @alllinesout;
for($i=0; $i<=$#sortedalllinesout; $i++)
{
  for($j=0; $j<2; $j++)
  {
    print LOG "$sortedalllinesout[$i][$j] ";
  }
  print LOG "\n";
}
close (LOG);

#print log filename
print "log file: $system ($date).txt\n";
print "XML dat file: $system ($date).dat\n";
exit;