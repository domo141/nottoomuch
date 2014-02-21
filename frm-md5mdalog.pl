#!/usr/bin/env perl

# Created: Fri Aug 19 16:53:45 2011 +0300 too
# Last Modified: Fri 21 Feb 2014 21:44:37 +0200 too

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

use strict;
use warnings;

use MIME::Base64 'decode_base64';
use MIME::QuotedPrint 'decode_qp';
use Encode qw/encode_utf8 find_encoding _utf8_on/;

binmode STDOUT, ':utf8';

my ($updateloc, $filenames) = (0, 0);
if (@ARGV > 0) {
    $updateloc = 1 if $ARGV[0] eq '-u';
    $filenames = 1 if $ARGV[0] eq '-v';
    die "Usage: $0 [-uv]\n"
	if @ARGV > 1 or $updateloc == 0 and $filenames == 0;
}

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
	return (lc $1 eq 'q')? decode_qp($_): decode_base64($_);
    }
    if (s/^([\w-]+)\?(q|b)\?//i) {
	my $t = lc $2;
	my $o = find_encoding($1);
	if (ref $o) {
	    my $s = ($t eq 'q')? decode_qp($_): decode_base64($_);
	    # Encode(3p) is fuzzy whether encode_utf8 is needed...
	    return encode_utf8($o->decode($s));
	}
    }
    return "=?$_?=";
}

my ($mails, $smails, $odate) = (0, 0, '');

sub mailfrm($)
{
    my ($sbj, $frm, $dte, $spam);
    init_next_hdr;
    while (get_next_hdr)
    {
	$sbj = $1 if (/^Subject:\s+(.*)\s+$/i);
	$frm = $1 if (/^From:\s+(.*)\s+$/i);
	$dte = $1 if (/^Date:\s+(.*)\s+$/i);
	$spam = 1 if /^X-Bogosity:.*Spam/i;
    }

    $dte =~ s/ (\d\d\d\d).*/ $1/; $dte =~ s/\s(0|\s)/ /g;
    $odate = $dte, print "*** $dte\n" if $dte ne $odate;

    $sbj = "<missing in $_[0] >" unless defined $sbj;
    #$frm = "<missing in $_[0] >" unless defined $frm;
    if ($spam) { $smails++; }
    else {
	# could split to $1, $2 & $3...
	$frm =~ s/=\?([^?]+\?.\?.+?)\?=/decode_data/ge;
	$sbj =~ s/=\?([^?]+\?.\?.+?)\?=/decode_data/ge;
	_utf8_on($frm); _utf8_on($sbj); # for print widths...
	printf "%-*.*s  %-*.*s\n", $fw, $fw, $frm, $sw, $sw, $sbj;
	print  "    $md/$_[0]\n\n" if $filenames;
    }
    $mails += 1;
}


my $omio = $mio;
my $cmio;
foreach (@logfiles) {
    $mdlf = $_;
    print "Opening $mdlf... (offset $mio)\n";
    open L, '<', $_ or die "Cannot open '$mdlf': $!\n";
    seek L, $mio, 0 if $mio > 0;

    while (<L>)
    {
	$mio += length;
	if (m|'(.*)'\s*$|) {
	    open I, '<', "$1" or do { print " ** $1: deleted **\n"; next; };
	    my $f = $1;
	    mailfrm $f;
	    close I;
	}
    }
    close L;
    $cmio = $mio;
    $mio = 0;
}

if ($updateloc and ($cmio != $omio or @logfiles > 1)) {
    my @lt = localtime;
    my @wds = qw/Sun Mon Tue Wed Thu Fri Sat Sun/;
    my $date = sprintf("%d-%02d-%02d (%s) %02d:%02d:%02d",
		       $lt[5] + 1900, $lt[4] + 1, $lt[3], $wds[$lt[6]],
		       $lt[2], $lt[1], $lt[0]);
    open O, '>>', 'log/md5mda-frmloc';
    $mdlf =~ s/log\///;
    syswrite O, "$date  $mdlf  $cmio\n";
    close O;
}
