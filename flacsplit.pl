#!/usr/bin/perl
################################################################################
#  Script name : flacsplit.pl                                                  #
#  System      : Unix                                                          #
#  Author      : Steve Martin                                                  #
#  Date        : 04/01/2008                                                    #
#  Function    : Split out individual tracks from a flac encoded CD image      #
#                Requires a cue sheet for the CD                               #
#                Files written to artist/album/track in current directory      #
#  Parameters  : cuefile - including path                                      #
#  Syntax      : flacsplit [options] <cuefile>                                 #
#                Where <cuefile> includes the full pathname to the cuefile     #
#                Options:                                                      #
#                -f, --flac	Encode to flac at the highest compression level#
#                -o, --ogg      Encode to ogg at quality 10                    #
#                -m, --mp3      Encode to mp3 at high quality VBR              #
#                -v, --version  Version and copyright information              #
#                -h, --help     Usage message                                  #
#                    --force    Overwrite existing output files                #
#  Executed by : Command line                                                  #
#                                                                              #
# Copyright (C) 2008,2012,2017 Steve Martin                                    #
#                                                                              #
# This program is free software; you can redistribute it and/or modify         #
# it under the terms of the GNU General Public License as published by         #
# the Free Software Foundation; either version 2 of the License, or            #
# (at your option) any later version.                                          #
#                                                                              #
# This program is distributed in the hope that it will be useful,              #
# but WITHOUT ANY WARRANTY; without even the implied warranty of               #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                #
# GNU General Public License for more details.                                 #
#                                                                              #
# You should have received a copy of the GNU General Public License            #
# along with this program; if not, write to the Free Software                  #
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA    #
################################################################################

use strict;
use IO::File;
use File::Basename;
use Getopt::Long;
use POSIX qw(tmpnam);

###############################################################################
# main                                                                        #
###############################################################################
my $RELEASE = "1.11";

my ( $flac, $ogg, $mp3, $version, $help, $force );
GetOptions(
    "flac|f"    => \$flac,       # output flac files
    "ogg|o"     => \$ogg,        # output ogg files
    "mp3|m"     => \$mp3,        # output mp3 files
    "version|v" => \$version,    # version and copyright display
    "help|h"    => \$help,       # display usage
    "force"     => \$force       # overwrite existing output files
    );

Greetings() if ($version);
Usage()     if ($help);

# Check that the necessary tools are installed
CheckTools( $flac, $ogg, $mp3 );

# set default behaviour if necessary
my $ext;
if ($ogg) {
    $ext = "ogg";
}
elsif ($mp3) {
    $ext = "mp3";
}
else {
    $flac = 1;
    $ext  = "flac";
}

my $cuefile = shift;
Usage() unless defined $cuefile;

my $dir = dirname($cuefile);
$cuefile = basename($cuefile);

my $flacfile = ReadCueSheet();
open( my $InFile, '<', "$dir/$flacfile" )
    or die "Couldn't open $flacfile for reading: $! \n";
close($InFile) or die "Couldn't close $flacfile: $! \n";

print "Processing $flacfile with cue sheet $cuefile\n";
print "Encoding to $ext\n";

EmbedCueSheet();
ProcessCueSheet( $flac, $ogg, $mp3, $ext );
RemoveCueSheet();

###############################################################################
# level 1                                                                     #
###############################################################################

sub Greetings {
    print "flacsplit.pl Version $RELEASE, Copyright (C) 2008, 2012, 2017 Steve Martin\n";
    print "flacsplit.pl is free software; you can redistribute it and/or modify\n";
    print "it under the terms of the GNU General Public License as published by\n";
    print " the Free Software Foundation; either version 2 of the License, or\n";
    print "(at your option) any later version.\n\n";
    print "flacsplit.pl is distributed in the hope that it will be useful,\n";
    print "but WITHOUT ANY WARRANTY; without even the implied warranty of\n";
    print "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n";
    print "GNU General Public License for more details.\n\n";
    print "You should have received a copy of the GNU General Public License\n";
    print "along with this program; if not, write to the Free Software\n";
    print "Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA\n";
    exit;
}

sub CheckTools {
    my ( $flac, $ogg, $mp3 ) = @_;
    my @tools = ( "metaflac", "flac", "oggenc", "lame" );

    foreach my $tool (@tools) {
	my $ftool = `which $tool 2>/dev/null`;
	chomp($ftool);
	if ($ftool) {
	    if ( -e $ftool ) {
		if ( !-x $ftool ) {
		    warn "$tool exists but you do not have execution permissions!\n";
		    if ( $tool =~ /(metaflac|flac)/ ) {
			die "This is an essential item, please fix.\n";
		    }
		    if ( $tool =~ /oggenc/ ) {
			warn "This will prevent you from encoding to ogg format.\n";
			if ($ogg) {
			    die "Please select an alternate encoding, or fix.\n";
			}
		    }
		    if ( $tool =~ /lame/ ) {
			warn "This will prevent you from encoding to mp3 format.\n";
			if ($mp3) {
			    die "Please select an alternate encoding, or fix.\n";
			}
		    }
		}
	    }
	}
	else {
	    warn "$tool was not found in your path!\n";
	    if ( $tool =~ /(metaflac|flac)/ ) {
		die "This is an essential item, please install flac.\n";
	    }
	    if ( $tool =~ /oggenc/ ) {
		warn "This will prevent you from encoding to ogg format.\n";
		if ($ogg) {
		    die "Please select an alternate encoding, or install vorbis-tools.\n";
		}
	    }
	    if ( $tool =~ /lame/ ) {
		warn "This will prevent you from encoding to mp3 format.\n";
		if ($mp3) {
		    die "Please select an alternate encoding, or install lame.\n";
		}
	    }
	}
    }
}

sub Usage {
    print "Usage: flacsplit [options] <cuefile>\n";
    print "Where <cuefile> includes the full pathname to the cuefile.\n\n";
    print "OPTIONS:\n";
    print "-f, --flac\t\t\tEncode to flac (default) at the highest compression level\n";
    print "-o, --ogg\t\t\tEncode to ogg at quality 10\n";
    print "-m, --mp3\t\t\tEncode to mp3 at highest quality VBR\n";
    print "-v, --version\tVersion and copyright information\n";
    print "-h, --help\t\tThis message\n";
    print "    --force\t\tChange default behaviour to overwrite existing files\n";
    exit;
}

sub ReadCueSheet {
    my ( $filename, @line );
    
    open( my $InFile, '<', "$dir/$cuefile" )
	or die "Couldn't open $cuefile for reading: $! \n";
    while (<$InFile>) {
	chomp;
	if (/^FILE/) {
	    @line     = split(/"/);
	    $filename = $line[1];
	    last;
	}
    }
    close($InFile) or die "Couldn't close $cuefile: $! \n";
    
    return $filename;
}

sub EmbedCueSheet {
    print "Embedding cuesheet $cuefile\n";
    system( "metaflac", "--import-cuesheet-from=$dir/$cuefile",
	    "$dir/$flacfile" );
}

sub RemoveCueSheet {
    print "Removing cuesheet from $flacfile\n";
    system( "metaflac", "--remove", "--block-type=CUESHEET", "$dir/$flacfile" );
}

sub ProcessCueSheet {
    my ( $flac, $ogg, $mp3, $ext ) = @_;
    my (
	$album, $artist, $tracknum, $track, $genre,
	$date,  $count,  $next,     @line
	);

    $count = 0;
    $genre = "";

    open( my $InFile, "<", "$dir/$cuefile" )
	or die "Couldn't open $cuefile for reading: $! \n";
    while (<$InFile>) {
	chomp;
	if (/^REM/) {
	    @line = split;
	    if ( $line[1] =~ /GENRE/ ) {
		undef $genre;
		for ( my $i = 2 ; $i < @line ; $i++ ) {
		    if ( defined $genre ) {
			$genre .= " " . $line[$i];
		    }
		    else {
			$genre = $line[$i];
		    }
		}
		$genre =~ s/\"//g;
	    }
	    
	    $date = $line[2] if ( $line[1] =~ /DATE/ );
	    next;
	}
	
	if ( !defined $album ) {
	    @line   = split(/"/);
	    $artist = $line[1] if (/^PERFORMER/);
	    $album  = $line[1] if (/^TITLE/);
	    
	    if ( defined $album ) {
		my $tartist = FixName($artist);
		my $talbum  = FixName($album);
		system( "mkdir", "-p", "$tartist/$talbum" );
	    }
	}
	else {
	    if (/^.*TRACK/) {
		@line     = split;
		$tracknum = $line[1];
	    }
	    
	    if (/^.*TITLE/) {
		@line  = split(/"/);
		$track = $line[1];
	    }
	}
	
	if ( defined $track ) {
	    $count++;
	    $next = $count + 1;
	    
	    my $outfile =
		CreateFileName( $tracknum, $album, $track, $artist, $ext );
	    
	    if ( -e $outfile & !$force ) {
		print "$outfile exists: skipping.\n";
	    }
	    else {
		my $tfile = GetTempFile();
		
		ExtractTrack( $dir, $track, $count, $next, $tfile );
		
		print "Encoding $outfile\n";
		EncodeFlac( $tracknum, $genre, $album, $tfile, $date, $track,
			    $artist, $outfile )
		    if $flac;
		EncodeOgg( $tracknum, $genre, $album, $tfile, $date, $track,
			   $artist, $outfile )
		    if $ogg;
		EncodeMp3( $tracknum, $genre, $album, $tfile, $date, $track,
			   $artist, $outfile )
		    if $mp3;
	    }
	    undef $track;
	}
    }
    close($InFile) or die "Couldn't close $cuefile: $! \n";
}

###############################################################################
# level 2                                                                     #
###############################################################################

sub CreateFileName {
    my ( $tracknum, $album, $track, $artist, $ext ) = @_;
    my $name = "$tracknum $track";

    $artist = FixName($artist);
    $album  = FixName($album);
    $name   = FixName($name);
    $name   = "$name.$ext";
    
    return "$artist/$album/$name";
}

sub GetTempFile {
    my ( $name, $fh );
    
    do { $name = tmpnam(); $name = "$name.wav"; }
    until $fh = IO::File->new( $name, O_RDWR | O_CREAT | O_EXCL );
    
    close($fh) or die "Couldn't close $name: $! \n";
    
    return $name;
}

sub ExtractTrack {
    my ( $dir, $track, $count, $next, $tfile ) = @_;
    
    print "Extracting $track.wav\n";
    system(
	"flac",                   "--silent",
	"--decode",               "-f",
	"--cue=$count.1-$next.1", "--output-name=$tfile",
	"$dir/$flacfile"
	);
}

sub EncodeFlac {
    my ( $tracknum, $genre, $album, $tfile, $date, $track, $artist, $outfile ) =
	  @_;

    system(
	"flac",                "--silent",
	"-f",                  "-8",
	"--delete-input-file", "--tag=ARTIST=$artist",
	"--tag=ALBUM=$album",  "--tag=TRACKNUMBER=$tracknum",
	"--tag=TITLE=$track",  "--tag=GENRE=$genre",
	"--tag=DATE=$date",    "--output-name=$outfile",
	$tfile
	);
}

sub EncodeOgg {
    my ( $tracknum, $genre, $album, $tfile, $date, $track, $artist, $outfile ) =
	@_;

    system(
	"oggenc",            "--quiet",        "--quality=10",
	"--artist=$artist",  "--album=$album", "--tracknum=$tracknum",
	"--title=$track",    "--genre=$genre", "--date=$date",
	"--output=$outfile", $tfile
	);

    unlink $tfile or warn "Couldn't delete $tfile: $! \n";
}

sub EncodeMp3 {
    my ( $tracknum, $genre, $album, $tfile, $date, $track, $artist, $outfile ) =
	@_;

    system(
	"lame",
	"-V", "0",
	"--quiet", "--noreplaygain", "--ignore-tag-errors",
	"--ta", $artist,
	"--tl",	$album,
	"--tn", $tracknum,
	"--tt", $track,
	"--tg",	$genre,
	"--ty", $date,
	$tfile, "$outfile"
	);
    
    unlink $tfile or warn "Couldn't delete $tfile: $! \n";
}

###############################################################################
# level 3                                                                     #
###############################################################################

sub FixName {
    my ($name) = @_;
    
    $name =~ s|\\|-|g;
    $name =~ s|\/|-|g;
    $name =~ s/-[-]+/-/g;
    $name =~ s/\.$/_/g;
    $name =~ s/[\?*:|<>]/_/g;
    $name =~ s/[[:^print:]]/_/g;
    $name =~ s/_[_]+/_/g;
    
    return $name;
}


