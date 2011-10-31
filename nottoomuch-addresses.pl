#!/usr/bin/perl
# -*- cperl -*-
# $ nottoomuch-addresses.pl $
#
# Created: Thu 27 Oct 2011 17:38:46 EEST too
# Last modified: Wed 30 Nov 2011 22:56:10 EET too

# Add this to your notmuch elisp configuration file:
#
# (require 'notmuch-address)
# (setq notmuch-address-command "/path/to/nottoomuch-addresses.pl")
# (notmuch-address-message-insinuate)

# Documentation at the end.

#BEGIN { system '/bin/sh', '-c', 'env > $HOME/na-ENV.$$'; }

my ($configdir, $adbpath);

# optimize search case -- no need to compile further in this case.
BEGIN {
    $configdir = ($ENV{XDG_CONFIG_HOME}||$ENV{HOME}.'/.config').'/nottoomuch';
    $adbpath = $configdir . '/addresses';

    if ($ENV{TERM} eq 'dumb' or @ARGV and $ARGV[0] !~ /^--/)
    {
	my $search_str = "@ARGV";
	exit 0 unless length $search_str >= 3; # more than 2 chars required...

	unless (open I, '<', $adbpath) {
	    print "Cannot open database, maybe not created yet.\n";
	    print "run $0 --update from command line first.\n";
	    exit 0;
	}
	print grep { index($_, $search_str) >= 0 } <I>;
	close I;
	exit 0;
    }
}

use 5.8.1;
use strict;
use warnings;

use Encode qw/encode_utf8 find_encoding/;
use MIME::Base64 'decode_base64';
use MIME::QuotedPrint 'decode_qp';

no encoding;

unless (@ARGV)
{
    require Pod::Usage;
    Pod::Usage::pod2usage( -verbose => 0, -exitval => 0 );
    exit 1;
}

if ($ARGV[0] eq '--help')
{
    $SIG{__DIE__} = sub {
     	$SIG{__DIE__} = 'DEFAULT';
     	require Pod::Usage;
     	Pod::Usage::pod2usage( -verbose => 2, -exitval => 0, -noperldoc => 1 );
     	exit 1;
    };
    require Pod::Perldoc;
    $SIG{__DIE__} = 'DEFAULT';
    # in case PAGER is not set, perldoc runs /usr/bin/perl -isr ...
    $ENV{LESS} .= 'R' if $ENV{PAGER} eq 'less' and $ENV{LESS} !~ /[rR]/;
    @ARGV = ( $0 );
    exit ( Pod::Perldoc->run() );
}

my $ignpath = $configdir . '/addresses.ignore';

my @list;

if ($ARGV[0] eq '--update')
{
    sub mkdirs($);
    sub mkdirs($) {
	die "'$_[0]': not a (writable) directory\n" if -e $_[0];
	return if mkdir $_[0]; # no mode: 0777 & ~umask used
	local $_ = $_[0];
	mkdirs $_ if s|/?[^/]+$|| and $_;
	mkdir $_[0] or die "Cannot create '$_[0]': $!\n";
    }

    mkdirs $configdir unless -d $configdir;

    unlink $adbpath if defined $ARGV[1] and $ARGV[1] eq "--rebuild";

    my ($sstr, $acount);
    my $stime = time;
    if (-f $adbpath) {
	die "Cannot open '$adbpath': $!\n" unless open I, '<', $adbpath;
	$sstr = <I>;
	$sstr -= 86400 * 7; # one week extra to (re)look.
	print "Updating '$adbpath', since $sstr.\n";
	$sstr .= '..';
	@list = grep { chomp; length; } <I>;
	close I;
	$acount = scalar @list;
    }
    else {
	print "Creating '$adbpath'. This may take some time...\n";
	$sstr = '*';
	$acount = 0;
    }
    my %hash = map { $_ => 1 } @list;
    if (-f $ignpath) {
	die "Cannot open '$ignpath': $!\n" unless open I, '<', $ignpath;
	while (<I>) {
	    chomp;
	    $hash{$_} = 1;
	}
	close I;
    }

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

    my $ptime = $stime + 5;
    $| = 1;
    open I, '-|', qw/notmuch show/, $sstr;
    while (<I>) {
	next unless /^From:\s/i or /^To:\s/i or /^Cc:\s/i;
	s/\s+$//;
	s/^.*?:\s+//;

	if (time > $ptime) {
	    my $c = qw(/ - \ |)[int ($ptime / 5) % 4];
	    print "$c new addresses gathered: ", scalar @list - $acount, "\r";
	    $ptime += 5;
	}

	# The parse function from Email::Address heavily modified
	# to fit ok in this particular purpose. New bugs are mine!
	# --8<----8<----8<----8<----8<----8<----8<----8<----8<----8<----8<--

	s/[ \t]+/ /g;
	my (@mailboxes) = (/$mailbox/go);
	foreach (@mailboxes) {
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

	    sub decode_data () {
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

	    my @phrase       = /($display_name)/o;
	    $phrase[0] =~ s/=\?(.+?)\?=/decode_data/ge if @phrase;

	    for ( @phrase, $host, $user, @comments ) {
		next unless defined $_;
		s/^[\s'"]+//; ## additions 20111123 too
		s/[\s'"]+$//; ## additions 20111123 too
		$_ = undef unless length $_;
	    }
	    # here we want to have email address always // 20111123 too
	    next unless defined $user and defined $host;

	    for (@phrase) { # to get the only one aliased to $_
		next unless defined $_; # previous loop may undefine this.
		# if it's encoded -- rjbs, 2007-02-28
		unless (/\A=\?.+\?=\z/) {
		    #s/\A"(.+)"\z/$1/;
		    tr/\\//d; ## 20111124 too
		    tr/_/ / unless /@/;  ## 20111130 too
		    s/\"/\\"/g;
		    $_ = '"'.$_.'"';
		}
	    }
	    my $userhost = lc "<$user\@$host>";
	    #my $userhost = "<$user\@$host>";
	    @comments = grep { defined or return 0;
			       s/=\?(.+?)\?=/decode_data/ge;
			       tr/_/ / unless /@/; 1; } @comments;
	    #@comments = grep {	defined } @comments;

	    $_ = join ' ', @phrase, $userhost, @comments;
	    next if defined $hash{$_};
	    push @list, $_;
	    $hash{$_} = 1;
	}
	# --8<----8<----8<----8<----8<----8<----8<----8<----8<----8<----8<--
    }
    undef %hash;
    undef %seen;
    my $etime = time;
    open O, '>', $adbpath or die;
    print O $etime, "\n";
    print O join("\n", sort @list), "\n";
    close O;
    my $ecount = scalar @list;
    my $count =  $ecount - $acount;
    $etime -= $stime;
    print "Added $count addresses in $etime seconds. ";
    print "Total number of addresses: $ecount.\n";
    exit 0;
}

die "$0: '$ARGV[0]': unknown option.\n";

__END__

=encoding utf8

=head1 NAME

nottoomuch-addresses.pl -- address completion/matching (for notmuch)

=head1 SYNOPSIS

nottoomuch-addresses.pl ( --update [--rebuild] | <search string> )

B<nottoomuch-addresses.pl --help>  for more help

=head1 VERSION

1.0 (2011-11-30)

=head1 OPTIONS

=head2 B<--update>

This option is used to initially create the "address database" for
searches to be done, and then incrementally update it with new
addresses that are available in mails received since last update.

In case you want to rebuild the database from scratch, add
B<--rebuild> after --update on command line. This is necessary if some
of the new emails received have Date: header point too much in the
past (one week before last update). Update used emails Date:
information to go through new emails to be checked for new addresses
with one week's overlap. Other reason for rebuild could be
enhancements in new versions of this program which change the email
format in database.

=head2 <SEARCH STRING>

In case no option argument is given on command line, the command line
arguments are used as fixed search string. Search goes through all
email addresses in database and outputs every address (separated by
newline) where a substring match with the given search string is
found. No wildcard of regular expression matching is used. Output is
sorted in ASCII order.

Search is not done unless there is at least 3 octets in search string.

=head1 IGNORE FILE

Some of the addresses collected may be valid but those still seems to
be noisy junk. One may additionally want to just hide some email
addresses.

When running B<--update> the output shows the path of address database
file (usually C<$HOME/.config/nottoomuch/addresses>). If there is file
C<addresses.ignore> in the same directory that file is read as
newline-separated list of addresses which are not to be included in
address database file.

Use your text editor to open both of these files. Then move address
lines to be ignored from B<addresses> to B<addresses.ignore>. After
saving these 2 files the moved addresses will not reappear in
B<addresses> file again.

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

=head1 ACKNOWLEDGEMENTS

This program uses code from Email::Address, Copyright (c) by Casey West
and maintained by Ricardo Signes. Thank you. All new bugs are mine,
though.
