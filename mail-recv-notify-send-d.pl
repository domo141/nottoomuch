#!/usr/bin/env perl
# $Id; mail-recv-notify-send-d.pl $
#
# inotify grab: around Sat 17 Sep 2011 17:10:49 EEST too
# Created: Mon 05 Jan 2015 17:20:37 +0200 too
# Last modified: Thu 05 Nov 2015 17:29:47 +0200 too

# This program takes "lognameglob" as an argument and when this sees
# CLOSE_WRITE event on files (on current directory) that matches the
# pattern this will do notify-send(1) mail filename.

use strict;
use warnings;
use POSIX;
use Config;

# inotify stuff from Inotify.pm by Torsten Werner perl gpl/artistic licensed.

my %syscall_inotify_init = (
   alpha     => 444,
   arm       => 316,
   i386      => 291,
   i486      => 291,
   ia64      => 1277,
   powerpc   => 275,
   powerpc64 => 275,
   s390      => 284,
   sh        => 290,
   sparc     => 151,
   sparc_64  => 151,
   x86_64    => 253,
);

my ($arch) = ($Config{archname} =~ m{([^-]+)-});
my $syscall_inotify_base = $syscall_inotify_init{$arch};
die "unsupported architecture: $arch\n" unless defined $syscall_inotify_base;

sub syscall_inotify_init ()
{
   syscall $syscall_inotify_base
}

sub syscall_inotify_add_watch (@)
{
   syscall $syscall_inotify_base + 1, @_;
}

my $ino_rmsg_len; {
    my $foo = pack 'iIII', 0, 0, 0; $ino_rmsg_len = length $foo;
}

my %inotify = (
   ACCESS        => 0x00000001,
   MODIFY        => 0x00000002,
   ATTRIB        => 0x00000004,
   CLOSE_WRITE   => 0x00000008,
   CLOSE_NOWRITE => 0x00000010,
   OPEN          => 0x00000020,
   MOVED_FROM    => 0x00000040,
   MOVED_TO      => 0x00000080,
   CREATE        => 0x00000100,
   DELETE        => 0x00000200,
   DELETE_SELF   => 0x00000400,
   MOVE_SELF     => 0x00000800,

   UNMOUNT       => 0x00002000,
   Q_OVERFLOW    => 0x00004000,
   IGNORED       => 0x00008000,

   CLOSE         => 0x00000018,
   MOVE          => 0x000000c0,
   ALL_EVENTS    => 0x00000fff, # linux/inotify.h sets currently defined o

   ISDIR         => 0x40000000,
   ONESHOT       => 0x80000000,
);

#my @rinotify;

#while (my ($key, $value) = each %inotify) {
#    $rinotify[ (log $value) / (log 2) ] = $key;
#}

my %rinotify;

while (my ($key, $value) = each %inotify) {
    $rinotify{$value} = $key;
}

{
    my $bn0 = $0; $bn0 =~ s|.*/||;
    system "ps ax | grep '[(]$bn0\[)]'";
    die "$bn0 may already be running!\n" unless $?;
    $0 = '(' . $bn0 . ')';
}

die "\nUsage: $0 lognameglob.\n\n" unless @ARGV == 1;

die "'/'s in '$ARGV[0]'\n" if $ARGV[0] =~ /\//;

warn "Note: No '*'s nor '?'s in '$ARGV[0]'...\n" unless $ARGV[0] =~ /[*?]/;

#while (<$ARGV[0]>) { print $_, "\n";}
{
    my @l = <$ARGV[0]>;
    die "No matches for pattern '$ARGV[0]'\n" unless @l;
}

my $re = $ARGV[0];
$re =~ s/[.]/[.]/g; $re =~ tr/?/./; $re =~ s/[*]/.*/g;
$re = qr/$re/;

#print $re, "\n";

my $ifd = syscall_inotify_init;
die "inotify init: $!\n" if $ifd < 0;

my $dd = '.';
my $wd = syscall_inotify_add_watch($ifd, $dd, $inotify{CLOSE_WRITE});
die "inotify add watch: $!\n" if $wd < 0;

sub may_notify_send ($)
{
    return unless $_[0] =~ /$re/;
    system qw/notify-send mail/, $_[0];
}

exit if fork;

# child
open STDIN, '>/dev/null';
open STDOUT, '>/dev/null';
open STDERR, '>/dev/null';
POSIX::setsid();

#my $isdir_f = $inotify{ISDIR};
while (1) {
    my $raw_events;
    my $len = POSIX::read($ifd, $raw_events, 65536);
    warn "$!\n" unless defined $len;
    exit 1 if ($len < $ino_rmsg_len);
    do {
	my ($ewd, $emask, $ecookie, $elen) = unpack 'iIII', $raw_events;
	#my $isdir;
	#if ($emask & $isdir_f) {
	#    $isdir = "ISDIR ";
	#    $emask &= ~$isdir_f;
	#}
	#else { $isdir = ''; }
	my $emaskstr = $rinotify{$emask} || sprintf "%x", $emask;
	my $name = unpack 'Z*', substr $raw_events, $ino_rmsg_len, $elen;
	may_notify_send $name;
	#print "$ewd, $isdir$emaskstr, $ecookie, $elen '$name'\n";
	$raw_events = substr $raw_events, $ino_rmsg_len + $elen;
    } while length $raw_events >= $ino_rmsg_len;
}
