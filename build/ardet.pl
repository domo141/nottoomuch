#!/usr/bin/perl
# -*- mode: cperl; cperl-indent-level: 4 -*-
# $ ardet.pl $
#
# Author: Tomi Ollila -- too ät iki piste fi
#
#	Copyright (c) 2019 Tomi Ollila
#	    All rights reserved
#
# Created: Sun 17 Mar 2019 13:30:15 EET too
# Last modified: Sun 17 Mar 2019 18:16:00 +0200 too

# SPDX-License-Identifier: Artistic-2.0

use 5.8.1;
use strict;
use warnings;

my ($time, $uid, $gid) = (0,0,0);
($time, $uid, $gid) = ($1, $2, $3), shift
  if @ARGV and $ARGV[0] =~ /^(\d+)\s+(\d+)\s+(\d+)$/;

die "Usage: [istr] files...\n" unless @ARGV;

die "time $time > 9999999999 -- does not fit\n" if $time > 9999999999;
die "uid $uid > 99999 -- does not fit\n" if $uid > 99999;
die "gid $gid > 99999 -- does not fit\n" if $gid > 99999;

my $ri = sprintf "%-11d %-5d %-5d ", $time, $uid, $gid; # 24 octets
my $re = ' ' x 24;

my (@mfiles, $failed);

sub fwarn($) {
    warn $_[0] =~ /:$/ ? "$_[0] $!\n" : "$_[0]\n";
    $failed = 1;
}

# https://en.wikipedia.org/wiki/Ar_(Unix)

# scan files where changes required
foreach (@ARGV) {
    fwarn "Cannot open $_:",next unless open my $fh, '<', $_;
    my $f = $_;
    fwarn "Cannot read from $_:",next unless sysread $fh, $_, 8 || 0;
    fwarn "'$f' did not start with '!<arch>\\n",next unless $_ eq "!<arch>\n";
    while (1) {
	fwarn "Cannot read from $_:",next unless defined sysread $fh, $_, 60;
	last unless $_;
	fwarn "Could not read 60 bytes from $_\n",next unless length($_) == 60;
	my $fri = substr $_, 16, 24;
	if ($fri ne $ri and $fri ne $re) {
	    fwarn "'$f' is not writable" unless -w $f;
	    push @mfiles, $f;
	    last;
	}
	my $len = (substr $_, 48, 10) + 0;
	$len++ if $len & 1;
	sysseek $fh, $len, 1; # 1 == SEEK_SET (i expect de-facto portability...)
    }
}
die "Encountered problems -- no changes made\n" if $failed;

# do changes (duplicate code, but less work w/o refactoring)
foreach (@mfiles) {
    fwarn "Cannot open $_:",next unless open my $fh, '+<', $_;
    my $f = $_;
    fwarn "Cannot read from $_:",next unless sysread $fh, $_, 8 || 0;
    fwarn "'$f' did not start with '!<arch>\\n",next unless $_ eq "!<arch>\n";
    while (1) {
	fwarn "Cannot read from $_:",next unless defined sysread $fh, $_, 60;
	last unless $_;
	fwarn "Could not read 60 bytes from $_\n",next unless length($_) == 60;
	my $fri = substr $_, 16, 24;
	my $len = (substr $_, 48, 10) + 0;
	if ($fri ne $ri and $fri ne $re) {
	    sysseek $fh, -44, 1; # 1 == SEEK_SET (ditto)
	    syswrite $fh, $ri;
	    $len += 20 # 44 - 24
	}
	$len++ if $len & 1;
	sysseek $fh, $len, 1; # 1 == SEEK_SET (i expect de-facto portability...)
    }
}
die "Encountered problems -- some changes may have been done\n" if $failed;
