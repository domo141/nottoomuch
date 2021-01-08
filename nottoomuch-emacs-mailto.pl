#!/usr/bin/perl
# -*- mode: cperl; cperl-indent-level: 4 -*-
# $ nottoomuch-emacs-mailto.pl $
#
# Author: Tomi Ollila -- too ät iki piste fi
#
#	Copyright (c) 2014-2019 Tomi Ollila
#	    All rights reserved
#
# Created: Sun 29 Jun 2014 16:20:24 EEST too
# Last modified: Sat 09 Jan 2021 00:25:50 +0200 too

# Handle mailto: links with notmuch emacs client. In case of
# graphical display (the usual case), use emacs in server mode
# (with special server socket) and run emacsclient on it.
# On non-graphical terminal run emacs in terminal mode.
# For special use cases (e.g. for wrappers) there are some extra
# command line options (currently -nw and --from=<address>).

# There are some hacks involved to get things working, and may break in the
# future. However, my guess is that this will just work for years to come.

use 5.8.1;
use strict;
use warnings;
use Cwd;

# override "default" From: (by setting $from to non-empty string) if desired
my $from = '';

# fyi: default emacs server socket name is 'server' (in /tmp/emacs$UID/)...
my $socket_name = 'mailto-server';

#open O, '>', "/tmp/mmm.$$"; print O "@ARGV\n"; close O;

while (@ARGV) {
    $_ = $ARGV[0];
    delete $ENV{DISPLAY}, shift, next if $_ eq '-nw';
    $from=$1, shift, next if /^--from=(.*)/;
    $ENV{EMACS} = $ENV{EMACSCLIENT} = 'echo', shift, next if $_ eq '--dry-run';
    last;
}

die "Usage: $0 [-nw] [--from=address] mailto-url\n" unless @ARGV;

my $use_emacsclient = defined $ENV{'DISPLAY'} && $ENV{DISPLAY} ne '';

sub mail($$)
{
    my $rest;
    ($_, $rest) = split /\?/, $_[1], 2;
    warn("skipping '$_' (does not start with 'mailto:')\n"), return
	 unless s/^mailto://;  #s/\s+//g;
    my %hash = ( to => [], subject => [], cc => [], bcc => [],
		 'in-reply-to' => [], keywords => [], body => [] );
    push @{$hash{to}}, $_ if $_;
    if (defined $rest) {
	foreach (split /&/, $rest) {
	    my $hfname;
	    ($hfname, $_) = split /=/, $_, 2;
	    $hfname = lc $hfname;
	    next unless defined $hash{$hfname};
	    s/%([\da-fA-F][\da-fA-F])/chr(hex($1)) unless lc($1) eq '0d'/ge;
	    #s/%([\da-fA-F][\da-fA-F])/chr(hex($1))/ge;
	    s/(["\\])/\\$1/g;
	    push @{$hash{$hfname}}, $_;
	}
    }
    $" = ', ';
    sub liornil($) {
	no warnings; # maybe the warning is effective when %hash reassigned ?
	return @{$hash{$_[0]}}? "\"@{$hash{$_[0]}}\"": "nil";
    }
    my $to = liornil 'to';
    my $subject = liornil 'subject';
    my $other_hdrs = 'nil';
    if ($from) {
	$from =~ s/("|\\)/\\$1/g;
	$other_hdrs = "'((From . \"$from\")";
    }
    if (@{$hash{'in-reply-to'}}) {
     	my $m = "@{$hash{'in-reply-to'}}";
	$other_hdrs = "'(" if $other_hdrs eq 'nil';
	$other_hdrs .= "(In-Reply-to . \"$m\")";
    }
    $other_hdrs .= ')' if $other_hdrs ne 'nil';

    my @elisp = ( "(with-demoted-errors", " (require 'notmuch)",
		  " (notmuch-mua-mail",
		  "      $to",
		  "      $subject",
		  "      $other_hdrs",
		  "      (notmuch-mua-get-switch-function))" );
    sub ideffi($) {
	no warnings; # ditto, now with @elisp too...
	return unless @{$hash{$_[0]}};
	push @elisp, " (message-goto-$_[0]) (insert \"@{$hash{$_[0]}}\")";
    }
    ideffi 'cc';
    ideffi 'bcc';
    ideffi 'keywords';
    $" = "\n";

    if (@{$hash{body}}) {
	# hacking body addition just before signature setup (since message
	# setup hook, which is called later, may add e.g. MML header[s])
	splice @elisp, 2, 0, (
	  ' (let ((message-signature-setup-hook message-signature-setup-hook))',
	  "   (add-hook 'message-signature-setup-hook",
	qq'     (lambda () (message-goto-body) (insert "@{$hash{body}}")',
	  '                (if (/= (point) (line-beginning-position))',
	  '                  (newline))))' )
    }
    if ($use_emacsclient) {
	my $cwd = cwd(); $cwd =~ s/("|\\)/\\$1/g;
	push @elisp, qq' (cd "$cwd")';
    }
    my @cmdline;

    if ($use_emacsclient) {
	my $emacsclient = $ENV{EMACSCLIENT} || 'emacsclient';
	@cmdline = ( $emacsclient,
		     qw/-c --alternate-editor= --no-wait -s/, $socket_name );
	# code to stop emacs if all frames are closed, there are no
	# clients and no modified buffers which have file name
	splice @elisp, 2, 0, (
' (defun delete-mailto-frame-function (frame)
   (if (and (= (length server-clients) 0)
            (< (length (delq frame (frame-list))) 2)
            (not (memq t (mapcar (lambda (buf) (and (buffer-file-name buf)
                                                    (buffer-modified-p buf)))
                                 (buffer-list)))))
       (kill-emacs)))',
" (add-hook 'delete-frame-functions 'delete-mailto-frame-function)" );
    }
    else {
	my $emacs = $ENV{EMACS} || 'emacs';
	@cmdline = ( $emacs, '-nw' );
    }
    push @elisp, '))';
    push @cmdline, '--eval', "@elisp";

    #print "@cmdline\n"; exit 0;
    exec @cmdline unless $_[0];
    system @cmdline;
}

my $last = pop @ARGV;
mail 1, $_ foreach (@ARGV);
mail 0, $last;
