datcreate v0.5 - Utility to compare No-Intro or Redump dat files to the -converted- rom or disc
                 collection (by name) and create an XML database of hashses (crc32, md5, sha1) from
                 the derivatives of original games hashes.

with datcreate [ options ] [dat file ...] [directory ...] [system] [process]

Options:
  -r    Redump source dat
  -n    No-intro source dat

Example:
              datcreate -r "D:/Atari - 2600.dat" "D:/Atari - 2600/Games" "Atari - 2600" "maxcso_1_12_0"

Author:
   Discord - Romeo#3620