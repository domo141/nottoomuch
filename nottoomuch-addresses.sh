#!/bin/sh
# -*- cperl -*-

case $* in (''|--*) exec perl -x "$0" "$@" ;; (???*) ;; (*) exit 0 ;; esac
grep -aiF "$*" "${XDG_CONFIG_HOME:-$HOME/.config}/nottoomuch/addresses.active"
case $? in 0|1) exit 0; esac
exit $?

# $ nottoomuch-addresses.sh $
#
# Created: Thu 27 Oct 2011 17:38:46 EEST too
# Last modified: Mon 08 Feb 2016 15:28:55 +0200 too

# Add these lines to your notmuch elisp configuration file
# ;; (e.g to ~/.emacs.d/notmuch-config.el since notmuch 0.18):
#
# (require 'notmuch-address)
# (setq notmuch-address-command "/path/to/nottoomuch-addresses.sh")
# (notmuch-address-message-insinuate)

# Documentation at the end. Encoding: utf-8.

#!perl
# line 25
# - 25 -^

# HISTORY
#
# Version 2.4  2016-01-02 21:00:00 UTC
#   * Separated mail file list reading using notmuch(1) to reading through
#     the mail files so that notmuch database is locked for shorter time.
#   * Some internal utf8 handling (related output warnings went away).
#
# Version 2.3  2014-09-17 15:59:44 UTC
#   * 3 new command line options for --(re)build phase:
#     --since                     -- scan mails dated since YYYY-MM-DD
#     --exclude-path-re           -- regexps for directories to exclude
#     --name-conversion=lcf2flem  -- convert address-matching phrase names
#
#     See updated documentation (--help) for more information of these.
#
#   * Changed 'addresses' file header to format v5: Following lines contain
#     'since', 'exclude-path-re' and 'name-conversion' information (if any)
#     and new marker line '---' separates this configuration from gathered
#     addresses.
#
#   * The files this program writes (and then reads) are handled as containing
#     utf8 data. The mail files read are read as "raw" files as incorrect utf8
#     there could make this program abort. Malformed utf8 is (sometimes?)
#     considered as being encoded as latin1 (at some time of the processing).
#     This all is a bit hairy to me, but at least it is getting better...
#
#   * Slight option handling change: --update and --rebuild are now mutually
#     exclusive and update does not (auto) build if address cache is missing.
#
# Version 2.2  2014-03-29 15:12:14 UTC
#   * In case there is both {phrase} and (comment) in an email address,
#     append comment to the phrase. This will make more duplicates to be
#     removed. Now there can be:
#       <user@host>
#       "phrase" <user@host>
#       "phrase (comment)" <user@host>
#       <user@host> (comment)
#   * In case email address is in form "someuser@somehost" <someuser@somehost>
#     i.e. the phrase is exactly the same as <address>, phrase is dropped.
#
# Version 2.1  2012-02-22 14:58:58 UTC
#   * Fixed a bug where decoding matching but unknown or malformed =?...?=-
#     encoded parts in email addresses lead to infinite loop.
#
# Version 2.0  2012-01-14 03:45:00 UTC
#   * Added regexp-based ignores using /regexp/[i] syntax in ignore file.
#   * Changed addresses file header to v4; 'addresses' file now contains all
#     found addresses plus some metainformation added at the end of the file.
#     Filtered (by ignores) address list is now in new 'addresses.active'
#     file and the fgrep code at the beginning now uses this "active" file.
#     Addresses file with header v2 and v3 are supported for reading.
#   * Encoded address content is now recursively decoded.
#
# Version 1.6  2011-12-29 06:42:42 UTC
#   * Fixed 'encoded-text' recognition and concatenations, and underscore
#     to space replacements. Now quite RFC 2047 "compliant".
#
# Version 1.5  2011-12-22 20:20:32 UTC
#   * Changed search to exit with zero value (also) if no match found.
#   * Changed addresses file header (v3) to use \t as separator. Addresses
#     file containing previous version header (v2) can also be read.
#   * Removed outdated information about sorting in ASCII order.
#
# Version 1.4  2011-12-14 19:24:28 UTC
#   * Changed to run notmuch search --sort=newest-first --output=files ...
#     (instead of notmuch show ...) and read headers from files internally.
#   * Fixed away joining uninitialized $phrase value to address line.
#
# Version 1.3  2011-12-12 15:41:05 UTC
#   * Changed to store/show addresses in 'newest first' order.
#   * Changed addresses file header to force address file rebuild.
#
# Version 1.2  2011-12-06 18:00:00 UTC
#   * Changed search work case-insensitively -- grep(1) does it locale-aware.
#   * Changed this program execute from /bin/sh (wrapper).
#
# Version 1.1  2011-12-02 17:11:33 UTC
#   * Removed Naïve assumption that no-one runs update on 'dumb' terminal.
#   * Check address database file first line whether it is known to us.
#
#   Thanks to Bart Bunting for providing a good bug report.
#
# Version 1.0  2011-11-30 20:56:10 UTC
#   * Initial release.

use 5.8.1;
use strict;
use warnings;

use utf8;
use open ':utf8'; # do not use with autodie (?)
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

use File::Temp 'tempfile';

use Encode qw/decode_utf8 find_encoding _utf8_on/;
use MIME::Base64 'decode_base64';
use MIME::QuotedPrint 'decode_qp';

use Time::Local;

my $configdir = ($ENV{XDG_CONFIG_HOME}||$ENV{HOME}.'/.config').'/nottoomuch';
my $adbpath = $configdir . '/addresses';
my $ignpath = $configdir . '/addresses.ignore';
my $actpath = $configdir . '/addresses.active';

unless (@ARGV)
{
    require Pod::Usage;
    Pod::Usage::pod2usage( -verbose => 0, -exitval => 0 );
    exit 1;
}

my ($o_update, $o_rebuild, $o_ncm) = (0, 0, {});
my ($o_since, @o_exclude);
my $aref;
foreach (@ARGV) {
    if (defined $aref) {
	if (ref $aref eq 'ARRAY') {
	    push @{$aref}, $_;
	} else { ${$aref} = $_; }
	undef $aref;
	next;
    }
    $o_update = 1, next if $_ eq '--update';
    $o_rebuild = 1, next if $_ eq '--rebuild';
    $aref = \$o_ncm, next if $_ eq '--name-conversion';
    $o_ncm = $1, next if $_ =~ '^--name-conversion=(.*)';
    $aref = \$o_since, next if $_ eq '--since';
    $o_since = $1, next if $_ =~ /^--since=(.*)/;
    $aref = \@o_exclude, next if $_ eq '--exclude-path-re';
    push (@o_exclude, $1), next if $_ =~ '^--exclude-path-re=(.*)';

    if ($_ eq '--help') {
	$SIG{__DIE__} = sub {
	    $SIG{__DIE__} = 'DEFAULT';
	    require Pod::Usage;
	    Pod::Usage::pod2usage(-verbose => 2,-exitval => 0,-noperldoc => 1);
	    exit 1;
	};
	require Pod::Perldoc;
	$SIG{__DIE__} = 'DEFAULT';
	# in case PAGER is not set, perldoc runs /usr/bin/perl -isr ...
	if ( ($ENV{PAGER} || '') eq 'less') {
	    $ENV{LESS} .= 'R' if ($ENV{LESS} || '') !~ /[rR]/;
	}
	@ARGV = ( $0 );
	exit ( Pod::Perldoc->run() );
    }
    #s/-+//;
    die "$0: '$_': unknown option.\n";
}

die "$0: Value missing for option '$ARGV[$#ARGV]'\n" if defined $aref;

my @optlines;

my $sincetime;
if (defined $o_since) {
    die "Option '--since' value format: YYYY-MM-DD\n"
      unless $o_since =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/;
    $sincetime = timelocal(0, 0, 0, $3, $2 - 1, $1);
    die "Since dates before Jan 1-2, 1970 not supported.\n" if $sincetime < 0;
    push @optlines, "since: $o_since\n"; # not used, just for future reference
}
else {
    $sincetime = -1;
}

unless (ref $o_ncm) {
    die "The only name conversion method known is 'lcf2flem' (≠ '$o_ncm')\n"
      unless $o_ncm eq 'lcf2flem';
    push @optlines, "name-conversion: $o_ncm\n";
}

if ($o_rebuild) {
    die "Options '--update' and '--rebuild' are mutually exclusive.\n"
      if $o_update;
}
else {
    die "File '$adbpath' does not exist. Use --rebuild.\n"
      unless -s $adbpath;
    die "Option '--since' not applicable when not rebuilding.\n"
      if $sincetime >= 0;
    die "Option '--exclude-path-re' not applicable when not rebuilding.\n"
      if @o_exclude;
    die "Option '--name-conversion' not applicable when not rebuilding.\n"
      unless ref $o_ncm;
}

# all arg checks done before this line!
my @list;

sub mkdirs($);
sub mkdirs($) {
    die "'$_[0]': not a (writable) directory\n" if -e $_[0];
    return if mkdir $_[0]; # no mode: 0777 & ~umask used
    local $_ = $_[0];
    mkdirs $_ if s|/?[^/]+$|| and $_;
    mkdir $_[0] or die "Cannot create '$_[0]': $!\n";
}

mkdirs $configdir unless -d $configdir;

unlink $adbpath if $o_rebuild; # XXX replace later w/ atomic replacement.

my @exclude;
my ($sstr, $acount) = (0, 0);
if (-s $adbpath) {
    die "Cannot open '$adbpath': $!\n" unless open I, '<', $adbpath;
    read I, $_, 18;
    # new header: "v5/dd/dd/dd/dd/dd\n" where / == '\t' (but match also v2)
    if (/^v([2345])\s(\d\d)\s(\d\d)\s(\d\d)\s(\d\d)\s(\d\d)\n$/) {
	$sstr = "$2$3$4$5$6" - 86400 * 7; # one week extra to (re)look.
	$sstr = 0 if $sstr < 0;
	if ($1 == 5) {
	    while (<I>) {
		last if /^---/;
		push @optlines, $_;
		push(@exclude, $1), next if /^exclude-path-re:\s+(.*)/;
		$o_ncm = $1 if /^name-conversion:\s*(.*?)\s+$/
	    }
	}
    }
    close I if $sstr == 0;
}
if ($sstr > 0) {
    print "Updating '$adbpath', since $sstr.\n";
    $sstr .= '..';
}
else {
    print "Creating '$adbpath'. This may take some time...\n";
    push @exclude, split(/::/, $_) foreach (@o_exclude);
    push @optlines, "exclude-path-re: $_\n" foreach (@exclude);

    if ($sincetime >= 0) {
	print "Reading addresses from mails since $o_since.\n";
	$sstr = "$sincetime..",
    }
    else {  $sstr = '*'; }
}
undef @o_exclude;

if (ref $o_ncm) {
    $o_ncm = 0;
}
elsif ($o_ncm eq 'lcf2flem') {
    $o_ncm = 1;
}
else {
    warn "Unknown name conversion method '$o_ncm'. Ignored\n";
    $o_ncm = 0;
}

my (%ign_hash, @ign_relist);
if (-f $ignpath) {
    die "Cannot open '$ignpath': $!\n" unless open J, '<', $ignpath;
    while (<J>) {
	next if /^\s*#/;
	if (m|^/(.*)/(\w*)\s*$|) {
	    if ($2 eq 'i') {
		push @ign_relist, qr/$1/i;
	    }
	    else {
		push @ign_relist, qr/$1/;
	    }
	}
	else {
	    s/\s+$/\n/;
	    $ign_hash{$_} = 1;
	}
    }
    close J;
}

my $sometime = time;
die "Cannot open '$adbpath.new': $!\n" unless open O, '>', $adbpath.'.new';
die "Cannot open '$actpath.new': $!\n" unless open A, '>', $actpath.'.new';
$_ = $sometime; s/(..)\B/$1\t/g; # FYI: s/..\B\K/\t/g requires perl 5.10.
print O "v5\t$_\n";
print O $_ foreach (@optlines);
print O "---\n";
undef @optlines;

# The following code block is from Email::Address, almost verbatim.
# The reasons to snip code I instead of just 'use Email::Address' are:
#  1) Some systems ship Mail::Address instead of Email::Address
#  2) Every user doesn't have ability to install Email::Address
# --8<----8<----8<----8<----8<----8<----8<----8<----8<----8<----8<--

## no critic RequireUseWarnings
# support pre-5.6

#$VERSION             = '1.889';
my $COMMENT_NEST_LEVEL = 2;

my $CTL            = q{\x00-\x1F\x7F};
my $special        = q{()<>\\[\\]:;@\\\\,."};

my $text           = qr/[^\x0A\x0D]/;

my $quoted_pair    = qr/\\$text/;

my $ctext          = qr/(?>[^()\\]+)/;
my ($ccontent, $comment) = (q{})x2;
for (1 .. $COMMENT_NEST_LEVEL) {
    $ccontent = qr/$ctext|$quoted_pair|$comment/;
    $comment  = qr/\s*\((?:\s*$ccontent)*\s*\)\s*/;
}
my $cfws           = qr/$comment|\s+/;

my $atext          = qq/[^$CTL$special\\s]/;
my $atom           = qr/$cfws*$atext+$cfws*/;
my $dot_atom_text  = qr/$atext+(?:\.$atext+)*/;
my $dot_atom       = qr/$cfws*$dot_atom_text$cfws*/;

my $qtext          = qr/[^\\"]/;
my $qcontent       = qr/$qtext|$quoted_pair/;
my $quoted_string  = qr/$cfws*"$qcontent+"$cfws*/;

my $word           = qr/$atom|$quoted_string/;

# XXX: This ($phrase) used to just be: my $phrase = qr/$word+/; It was changed
# to resolve bug 22991, creating a significant slowdown.  Given current speed
# problems.  Once 16320 is resolved, this section should be dealt with.
# -- rjbs, 2006-11-11
    #my $obs_phrase     = qr/$word(?:$word|\.|$cfws)*/;

# XXX: ...and the above solution caused endless problems (never returned) when
# examining this address, now in a test:
#   admin+=E6=96=B0=E5=8A=A0=E5=9D=A1_Weblog-- ATAT --test.socialtext.com
# So we disallow the hateful CFWS in this context for now.  Of modern mail
# agents, only Apple Web Mail 2.0 is known to produce obs-phrase.
# -- rjbs, 2006-11-19
my $simple_word    = qr/$atom|\.|\s*"$qcontent+"\s*/;
my $obs_phrase     = qr/$simple_word+/;

my $phrase         = qr/$obs_phrase|(?:$word+)/;

my $local_part     = qr/$dot_atom|$quoted_string/;
my $dtext          = qr/[^\[\]\\]/;
my $dcontent       = qr/$dtext|$quoted_pair/;
my $domain_literal = qr/$cfws*\[(?:\s*$dcontent)*\s*\]$cfws*/;
my $domain         = qr/$dot_atom|$domain_literal/;

my $display_name   = $phrase;

my $addr_spec  = qr/$local_part\@$domain/;
my $angle_addr = qr/$cfws*<$addr_spec>$cfws*/;
my $name_addr  = qr/$display_name?$angle_addr/;
my $mailbox    = qr/(?:$name_addr|$addr_spec)$comment*/;

# --8<----8<----8<----8<----8<----8<----8<----8<----8<----8<----8<--

# In this particular purpose the cache code used in...
my %seen; # ...Email::Address is "replaced" by %seen & %hash.
my %hash;

my $database_path = qx/notmuch config get database.path/;
chomp $database_path;
my @exclude_re = map qr(^$database_path/$_), @exclude;
print((join "\n", map "Excluding '^$database_path/$_'", @exclude), "\n")
  if @exclude and $o_rebuild;
undef $database_path;
undef @exclude;

my $ptime = $sometime + 5;
my $addrcount = 0;
$| = 1;
my $efn = tempfile(DIR => $configdir);
open P, '-|', qw/notmuch search --sort=newest-first --output=files/, $sstr;
X: while (<P>) {
    foreach my $re (@exclude_re) { next X if /$re/; }
    print $efn $_;
}
close P;
seek $efn, 0, 0;

while (<$efn>) {
    chomp;
    # open in raw mode to avoid fatal utf8 problems. does some conversion
    # heuristics like latin1 -> utf8 there... -- _utf8_on used on need basis.
    open M, '<:raw', $_ or next;
    while (<M>) {
	last if /^\s*$/;
	next unless s/^(From|To|Cc|Bcc):\s+//i;
	s/\s+$//;
	my @a = ( $_ );
	while (<M>) {
	    # XXX leaks to body in case empty line is found in this loop...
	    # XXX Note that older code leaked to mail body always...
	    if (s/^\s+// or s/^(From|To|Cc|Bcc):\s+/,/i) {
		s/\s+$//;
		push @a, $_;
		next;
	    }
	    last;
	}
	$_ = join ' ', @a;

	if (time > $ptime) {
	    my $c = qw(/ - \ |)[int ($ptime / 5) % 4];
	    print $c, ' active addresses gathered: ', $addrcount, "\r";
	    $ptime += 5;
	}

	# The parse function from Email::Address heavily modified
	# to fit ok in this particular purpose. New bugs are mine!
	# --8<----8<----8<----8<----8<----8<----8<----8<----8<----8<----8<--

	s/[ \t]+/ /g; # this line did fail fatally on malformed utf-8 data...
	s/\?= =\?/\?==\?/g;
	my (@mailboxes) = (/$mailbox/go);
      L: foreach (@mailboxes) {
	    next if $seen{$_};
	    $seen{$_} = 1;

	    my @comments = /($comment)/go;
	    s/$comment//go if @comments;

	    my ($user, $host);
	    ($user, $host) = ($1, $2) if s/<($local_part)\@($domain)>//o;
	    if (! defined($user) || ! defined($host)) {
		s/($local_part)\@($domain)//o;
		($user, $host) = ($1, $2);
	    }

	    sub decode_substring ($) {
		my $t = lc $2;
		my $s;
		if ($t eq 'b') { $s = decode_base64($3); }
		elsif ($t eq 'q') { $s = decode_qp($3);	}
		else {
		    $_[0] = 0;
		    return "=?$1?$2?$3?=";
		}
		$s =~ tr/_/ /;

		return decode_utf8($s) if lc $1 eq 'utf-8';

		my $o = find_encoding($1);
		$_[0] = 0, return "=?$1?$2?$3?=" unless ref $o;
		return $o->decode($s);
	    }
	    sub decode_data () {
		my $loopmax = 5;
		while ( s{ =\?([^?]+)\?(\w)\?(.*?)\?= }
			 { decode_substring($loopmax) }gex ) {
		    last if --$loopmax <= 0;
		};
	    }

	    my @phrase       = /($display_name)/o;
	    decode_data foreach (@phrase);

	    for ( @phrase, $host, $user, @comments ) {
		next unless defined $_;
		s/^[\s'"]+//; ## additions 20111123 too
		s/[\s'"]+$//; ## additions 20111123 too
		$_ = undef unless length $_;
	    }
	    # here we want to have email address always // 20111123 too
	    next unless defined $user and defined $host;

	    my $userhost = lc "<$user\@$host>";
	    #my $userhost = "<$user\@$host>";

	    @comments = grep { defined or return 0; decode_data; 1; } @comments;

	    # "trim" phrase, if equals to user@host after trimming, drop it.
	    if (defined $phrase[0]) {
		#$phrase[0] =~s/\A"(.+)"\z/$1/;
		$phrase[0] =~ tr/\\//d; ## 20111124 too
		$phrase[0] =~ s/\"/\\"/g;
		@phrase = () if lc "<$phrase[0]>" eq $userhost;
	    }

	    # In case we would have {phrase} <user@host> (comment),
	    # make that "{phrase} (comment)" <user@host> ...
	    if (defined $phrase[0])
	    {
		if ($o_ncm and $phrase[0] =~ /^(.*)\s*,\s*(.*)$/) {
		    # Try to change "Last, First" to "First Last"
		    # The heuristics: If either 'Last' or 'First' is having
		    # the same length in name and address and case-insensitive
		    # comparison where characters not matching a-z ignored.
		    my ($mlast, $mfirst) = ($1, $2);
		    if ($userhost =~ /^<?([^.]+)[.]([^@]+)@/) {
			my ($afirst, $alast) = ($1, $2);
			#print "$mlast - $mfirst / $afirst, $alast\n";
			if    (_utf8_on($mlast),
			       length $mlast == length $alast) {
			    my $re = $mlast; $re =~ tr/A-Za-z/./c;
			    $phrase[0] = "$mfirst $mlast" if $alast =~ /$re/i;
			}
			elsif (_utf8_on($mfirst),
			       length $mfirst == length $afirst) {
			    my $re = $mfirst; $re =~ tr/A-Za-z/./c;
			    $phrase[0] = "$mfirst $mlast" if $afirst =~ /$re/i;
			}
		    }
		}

		if (@comments) {
		    $phrase[0] = qq/"$phrase[0] / . join(' ', @comments) . '"';
		    @comments = ();
		}
		else {
		    $phrase[0] = qq/"$phrase[0]"/;
		}
	    }
	    else {
		@phrase = ();
	    }
	    $_ = join(' ', @phrase, $userhost, @comments) . "\n";
	    next if defined $hash{$_};
	    print O $_;
	    $hash{$_} = 1;
	    next if defined $ign_hash{$_};
	    foreach my $re (@ign_relist) {
		next L if $_ =~ $re;
	    }
	    print A $_;
	    $addrcount++;
	}
	# --8<----8<----8<----8<----8<----8<----8<----8<----8<----8<----8<--
    }
    close M;
}
undef %seen;
close $efn;
my $oldaddrcount = 0;
if (defined fileno I) {
    $sstr = '*'; # XXX, to be fixed...
  L: while (<I>) {
	last if /^---/;
	next if defined $hash{$_};
	print O $_;
	next if defined $ign_hash{$_};
	foreach my $re (@ign_relist) {
	    next L if $_ =~ $re;
	}
	print A $_;
	$addrcount++;
    }
    while (<I>) {
	$oldaddrcount = ($1 + 0), next if /^active:\s+(\d+)\s*$/;
    }
    close I;
}
print O "---\n";
print O "active: ", $addrcount, "\n";
close O;
close A;
undef %hash;
#link $adbpath, $adbpath . '.' . $sometime;
rename $adbpath . '.new', $adbpath or
  die "Cannot rename '$adbpath.new' to '$adbpath': $!\n";
rename $actpath . '.new', $actpath or
  die "Cannot rename '$actpath.new' to '$actpath': $!\n";
if ($oldaddrcount or $sstr eq '*') {
    $sometime = time - $sometime;
    my $new = $addrcount - $oldaddrcount;
    print "Added $new active addresses in $sometime seconds.\n";
}
print "Total number of active addresses: $addrcount.\n";
exit 0;

__END__

=encoding utf8

=head1 NAME

nottoomuch-addresses.sh -- address completion/matching (for notmuch)

=head1 SYNOPSIS

nottoomuch-addresses.sh (--update | --rebuild [opts] | <search string>)

B<nottoomuch-addresses.sh --help>  for more help

=head1 VERSION

2.3 (2014-09-17)

=head1 <SEARCH STRING>

In case no option argument is given on command line, the command line
arguments are used as fixed search string. Search goes through all
email addresses in cache and outputs every address (separated by
newline) where a substring match with the given search string is
found. No wildcard of regular expression matching is used.

Search is not done unless there is at least 3 octets in search string.

=head1 OPTIONS

=head2 B<--update>

This option is used to incrementally update the "address cache" with
new addresses that are available in mails received since last update.

=head2 B<--rebuild>

With this option the address cache is created (or rebuilt from scratch).

In addition to initial creation this option is useful when some build options
(which affect to all addresses) are desired to be changed.

Sometimes some of the new emails received may have Date: header point too
much in the past (one week before last update). Update uses email Date:
information to go through new emails to be checked for new addresses
with one week's overlap, and only rebuild will catch these emails (albeit
the rebuild option is quite heavy option to solve such a problem).

=head3 B<--rebuild> options:

When (re)building the address cache, there are a few options to affect
the operation (and future additions).

=over 2

=item B<--since>=YYYY-MM-DD

Start email gathering from mails dated YYYY-MM-DD. I.e. skip older.

=item B<--exclude-path-re>=path-regexp

Regular expression(s) of directory paths to exclude when scanning mail files.
This option can be given multiple times on the command line.

Given regexps are anchored to the start of the string (based on the email
directory notmuch is configured with), but not to the end (for example to
match anywhere prefix regexp with '.*', or conversely, to anchor end suffix
regexp with '$').

=item B<--name-conversion>=lcf2flem

With name conversion method 'lcf2flem' (the only method known) email addresses
in format "Last, First <first.last@example.org>" are converted to
"First Last <first.last@example.org>". For this conversion to succeed either
"First" or "Last" needs to match the corresponding string in email address.
If there are non-us-ascii characters in the names those are ignored in
comparisons (i.e. matches any character).

This method name is modeled from
"Last-comma-First-to-First-Last-either-matches".

=back

=head1 IGNORE FILE

Some of the addresses collected may be valid but those still seems to
be noisy junk. One may additionally want to just hide some email
addresses.

When running B<--update> the output shows the path of address cache
file (usually C<$HOME/.config/nottoomuch/addresses>). If there is file
C<addresses.ignore> in the same directory that file is read as
newline-separated list of addresses which are not to be included in
address cache file.

Use your text editor to open both of these files. Then move address
lines to be ignored from B<addresses> to B<addresses.ignore>. After
saving these 2 files the moved addresses will not reappear in
B<addresses> file again.

Version 2.0 of nottoomuch-addresses.sh supports regular expressions in
ignore file. Lines in format I</regexp/> or I</regexp/i> defines (perl)
I<regexp>s which are used to match email addresses for ignoring. The
I</i> format makes regular expression case-insensitive -- although this
is only applied to characters in ranges I<A-Z> and I<a-z>. Remember that
I</^.*regexp.*$/> and I</regexp/> provides same set of matching lines.

=head1 LICENSE

This program uses code from Email::Address perl module. Inclusion of
that makes it easy to define license for the whole of this code base:

Terms of Perl itself

a) the GNU General Public License as published by the Free
   Software Foundation; either version 1, or (at your option) any
   later version, or

b) the "Artistic License"

=head1 SEE ALSO

L<notmuch>, L<Email::Address>

=head1 AUTHOR

Tomi Ollila -- too ät iki piste fi

=head1 ACKNOWLEDGMENTS

This program uses code from Email::Address, Copyright (c) by Casey West
and maintained by Ricardo Signes. Thank you. All new bugs are mine,
though.
