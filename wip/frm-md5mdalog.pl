#!/usr/bin/env perl

# Created: Fri Aug 19 16:53:45 2011 +0300 too
# Last Modified: Fri 15 Apr 2016 18:44:06 +0300 too

# This program examines the log files md5mda.sh has written to
# $HOME/mail/log directory (XXX hardcoded internally to this script)
# and prints the from & subject lines from those.
# The -u (update) option marks all currently viewed files read and
# don't read those again (trusting file name ordering and those files
# not truncating).
# The -v (verbose?) option causes the mail filenames to be printed
# so that those can be e.g. removed ahead-of-time.
#
# ( cd $HOME/bin; ln -s path/to/frm-md5mdalog.pl frm ) may be useful...

# elegance is not a strong point in this program; hacked on the need basis...
# maybe when the desired set of features is known this will be polished.

#use 5.014; # for tr///r
use 5.10.1; # for \K
use strict;
use warnings;

use MIME::Base64 'decode_base64';
use MIME::QuotedPrint 'decode_qp';
use Encode qw/encode_utf8 find_encoding _utf8_on/;

no warnings 'utf8'; # do not warn on malformed utf8 data in input...

binmode STDOUT, ':utf8';

sub usage () { die "Usage: $0 [-uvdfqw] [re...]\n"; }

my ($updateloc, $filenames, $filesonly, $showdels, $fromnew, $wideout) =
    (0, 0, 0, 0, 0, 0);
my $quieter = 0;
if (@ARGV > 0 and ord($ARGV[0]) == ord('-')) {
    my $arg = $ARGV[0];
    $fromnew = $1 if $arg =~ s/^-\K(\d+)$//;
    $showdels = 1 if $arg =~ s/-\w*\Kd//;
    $updateloc = 1 if $arg =~ s/-\w*\Ku//;
    $filenames = 1 if $arg =~ s/-\w*\Kv//;
    $filesonly = 1 if $arg =~ s/-\w*\Kf//;
    $quieter = 1 if $arg =~ s/-\w*\Kq//;
    $wideout = 1 if $arg =~ s/-\w*\Kw//;
    usage unless $arg eq '-';
    shift @ARGV;
}

my @relist = map { qr/$_/i } @ARGV;

$_ = $0; s|.*/||;

my $md = $ENV{'HOME'} . '/mail';

chdir $md or die;

my ($mdlf, $mio);
if (open I, '<', 'log/md5mda-frmloc') {
    my $fl = -s I;
    if ($fl > 100) {
	seek I, -50, 2 or die $!; # seek-end
    }
    $mdlf = $_ while (<I>);
    if (defined $mdlf) {
	$mdlf =~ s/^.*\s+(\S+)\s+(\d+)\s*$/$1/;
	$mio = (defined $2)? $2: undef;
    }
    close I;
}

my @logfiles;

if (defined $mio) {
    $mdlf = 'log/' . $mdlf;
    my @alf = <log/md5mda-[0-9]*.log>;
    my $last;
    while (@alf) {
	$last = shift @alf;
	@logfiles = ( $last ), last if $last eq $mdlf;
    }
    push @logfiles, $_ foreach (@alf);

    unless (@logfiles and defined $last) {
	$mio = '0';
	@logfiles = ( $last );
    }
}
else {
    # last file, 0 loc.
    $mdlf = $_ foreach (<log/md5mda-[0-9]*.log>);
    $mio = '0';
    @logfiles = ( $mdlf ) if defined $mdlf;
}

die "No log files to dig mail files from...\n" unless @logfiles;

my $frmllnk = readlink 'log/md5mda-frmlast';
my ($frmlast, $frmloff);
if (defined $frmllnk && $frmllnk) {
    ($frmlast = $frmllnk) =~ s/^(\d+),(\d+)$/log\/md5mda-$1.log/;
    $frmloff = $2 if defined $2;
}
#print $frmlast, ',', $frmloff, "\n";

my $cols = int(qx{stty -a | sed -n 's/.*columns //; T; s/;.*//p'} + 0);
$cols = 80 unless ($cols);  #print "Columns: $cols.\n";
my $fw = int ($cols / 3 - 1);  my $sw = int ($cols / 3 * 2 - 1);

my $hdrline;
sub init_next_hdr()
{
    $hdrline = <I>; $. = 0;
}
sub get_next_hdr()
{
    return 0 if $hdrline =~ /^$/;
    while (<I>) {
	chomp $hdrline, $hdrline = $hdrline . $_, next if s/^[ \t]+/ /;
	($_, $hdrline) = ($hdrline, $_);
	return 1;
    }
    $_ = $hdrline; $hdrline = ''; $.++;
    return 1;
}

sub decode_data() {
    local $_ = $1;
    if (s/^utf-8\?(q|b)\?//i) {
	return (lc $1 eq 'q')? (tr/_/ /, decode_qp($_)): decode_base64($_);
    }
    if (s/^([\w-]+)\?(q|b)\?//i) {
	my $t = lc $2;
	my $o = find_encoding($1);
	if (ref $o) {
	    my $s = ($t eq 'q')? (tr/_/ /, decode_qp($_)): decode_base64($_);
	    # Encode(3p) is fuzzy whether encode_utf8 is needed...
	    return encode_utf8($o->decode($s));
	}
    }
    return "=?$_?=";
}

my ($mails, $smails, $odate) = (0, 0, '');

my %lastfns;
sub mailfrm($)
{
    my ($sbj, $frm, $dte, $spam);
    init_next_hdr;
    while (get_next_hdr)
    {
	$sbj = $1 if (/^Subject:\s*(.*?)\s*$/i);
	$frm = $1 if (/^From:\s*(.*?)\s*$/i);
	$dte = $1 if (/^Date:\s*(.*?)\s*$/i);
	$spam = 1 if /^X-Bogosity:.*\bSpam\b/i;
    }

    $dte =~ s/ (\d\d\d\d).*/ $1/; $dte =~ s/\s(0|\s)/ /g;
    $odate = $dte, print "*** $dte\n"
	if $dte ne $odate and not $filesonly and not $quieter;

    $sbj = "<missing in $_[0] >" unless defined $sbj;
    #$frm = "<missing in $_[0] >" unless defined $frm;
    if ($spam) { $smails++; }
    else {
	# could split to $1, $2 & $3...
	$frm =~ s/\?=\s+=\?/\?==\?/g;
	$frm =~ s/=\?([^?]+\?.\?.+?)\?=/decode_data/ge;
	unless ($filesonly) {
	    $_ = $_[0]; s|.*/||;
	    $frm="!$frm" if defined $lastfns{$_};
	}
	$sbj =~ s/\?=\s+=\?/\?==\?/g;
	$sbj =~ s/=\?([^?]+\?.\?.+?)\?=/decode_data/ge;
	my $line;
	if ($wideout) { $line = $frm . '  ' . $sbj;
	} else {
	    _utf8_on($frm); _utf8_on($sbj); # for print widths...
	    $line = sprintf '%-*.*s  %-.*s', $fw, $fw, $frm, $sw, $sbj;
	}
	sub rechk ($) { foreach (@relist) { return 0 if ($_[0] =~ $_); } 1; }
	unless (@relist and rechk $line) {
	    print $line, "\n" unless $filesonly;
	    print  "    $md/$_[0]\n" if $filenames or $filesonly;
	    print "\n" if $filenames;
	}
    }
    $mails += 1;
}

# read filenames of last mails imported, from new-* files, to know whether
# taken by notmuch already (XXX 20140821 is this consistent XXX)

my @_i = ( 1 );
while (<log/new-*>) {
    $_i[$_i[0]++] = $_;
    $_i[0] = 1 if $_i[0] > ($fromnew || 3);
}

shift @_i;
foreach (@_i) {
    open L, '<', $_ or die "$_: $!\n";
    while (<L>) {
	if ($fromnew) {
	    # XXX so much duplicate w/ loop below
	    /\s(\/\S+)\s+$/ || next;
	    open I, '<', "$1" or do {
		print "    ** $1: deleted **\n" if $showdels; next;
	    };
	    my $f = $1;
	    mailfrm $1;
	    close I;
	}
	else {
	    $lastfns{$1} = 1 if /\/([a-z0-9]{9,})$/;
	}
    }
    close L;
}
undef @_i;
exit if $fromnew;

my $omio = $mio;
my ($cmio, $ltime);
foreach (@logfiles) {
    $mdlf = $_;
    print "Opening $mdlf... (offset $mio)\n" unless $filesonly or $quieter;
    open L, '<', $_ or die "Cannot open '$mdlf': $!\n";
    seek L, $mio, 0 if $mio > 0;

    while (<L>)
    {
	$mio += length;
	if (m|(\w\w\w. \d\d:\d\d).*'(.*)'\s*$|) {
	    $ltime = $1;
	    open I, '<', "$2" or do {
		print "    ** $2: deleted **\n" if $showdels; next;
	    };
	    my $f = $2;
	    mailfrm $f;
	    close I;
	}
    }
    close L;
    $cmio = $mio;
    $mio = 0;
}

if (defined $ltime and ! $filesonly and ! $quieter) {
    $ltime =~ tr/)//d;
    print "*** Last mail received: $ltime.\n";
}

if ($cmio != $omio or @logfiles > 1) {

    $mdlf =~ /md5mda-(\d+)/;
    my $newlink = "$1,$cmio";
    if (not defined $frmllnk or $newlink ne $frmllnk) {
	unlink 'log/md5mda-frmlast';
	symlink "$1,$cmio", 'log/md5mda-frmlast';
    }

    if ($updateloc) {
	my @lt = localtime;
	my @wds = qw/Sun Mon Tue Wed Thu Fri Sat Sun/;
	my $date = sprintf("%d-%02d-%02d (%s) %02d:%02d:%02d",
			   $lt[5] + 1900, $lt[4] + 1, $lt[3], $wds[$lt[6]],
			   $lt[2], $lt[1], $lt[0]);
	open O, '>>', 'log/md5mda-frmloc';
	$mdlf =~ s/log\///;
	syswrite O, "$date  $mdlf  $cmio\n";
	print "Offset updated to $mdlf: $cmio\n" unless $filesonly;
	close O;
    }
    elsif (not $filesonly and $showdels and defined $frmloff
	   and $mdlf eq $frmlast and $frmloff eq $cmio) {
	my @l = lstat 'log/md5mda-frmlast';
	@l = localtime $l[9];
	my @d = qw/Sun Mon Tue Wed Thu Fri Sat Sun/;
	my $time = sprintf '%02d:%02d', $l[2], $l[1];
	print "*** No new mail since last frm run ($d[$l[6]] $time).\n";
    }
}
