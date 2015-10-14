#!/usr/bin/perl
# -*- mode: cperl; cperl-indent-level: 4 -*-
# $ nottoomuch-emacs-mailto.pl $
#
# Author: Tomi Ollila -- too ät iki piste fi
#
#	Copyright (c) 2014 Tomi Ollila
#	    All rights reserved
#
# Created: Sun 29 Jun 2014 16:20:24 EEST too
# Last modified: Wed 14 Oct 2015 22:53:39 +0300 too

use 5.8.1;
use strict;
use warnings;
use Cwd;

#
# set these to your liking
#

# use "default" From: unless $from set to non-empty string
my $from = '';

my $use_emacsclient = 0;

# next 2 applicable when $use_emacsclient = 1
my $create_frame = 0;
# auto_daemon implies create_frame
my $auto_daemon = 0;

# note: in case of *not* using emacsclient, emacs itself is killed
my $save_buffer_kill_terminal_after_send = 0;

die "Usage: $0 mailto-url\n" unless @ARGV;

sub mail($$)
{
    my $rest;
    ($_, $rest) = split /\?/, $_[1], 2;
    s/^mailto://; #s/\s+//g;
    my %hash = ( to => [], subject => [], cc => [], bcc => [],
		 keywords => [], body => [] );
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
    $" = ", ";
    sub liornil($) {
	no warnings; # maybe the warning is effective when %hash reassigned ?
	return @{$hash{$_[0]}}? "\"@{$hash{$_[0]}}\"": "nil";
	use warnings;
    }
    my $to = liornil 'to';
    my $subject = liornil 'subject';
    #my $from = liornil 'from';
    if ($from) {
	$from =~ s/("|\\)/\\$1/g;
	$from = "'((From . \"$from\"))";
    }
    else { $from = 'nil'; }

    my @elisp = ( "(progn (require 'notmuch)",
		  " (notmuch-mua-mail $to $subject $from nil",
		  "	(notmuch-mua-get-switch-function))" );
    if ($use_emacsclient) {
	my $cwd = cwd(); $cwd =~ s/("|\\)/\\$1/g;
	push @elisp, qq' (cd "$cwd")';
    }
    if ($save_buffer_kill_terminal_after_send) {
	push @elisp,
	  " (setq message-exit-actions '(save-buffers-kill-terminal))";
    }
    sub ideffi($) {
	no warnings; # ditto, now with @elisp too...
	return unless @{$hash{$_[0]}};
	push @elisp, " (message-goto-$_[0]) (insert \"@{$hash{$_[0]}}\")";
	use warnings;
    }
    ideffi 'cc';
    ideffi 'bcc';
    ideffi 'keywords';
    $" = "\n";
    ideffi 'body';
    push @elisp, " (goto-char (point-max))";
    push @elisp, " (if (/= (point) (line-beginning-position))";
    push @elisp, "    (insert \"\\n\"))";
    push @elisp, " (set-buffer-modified-p nil) (message-goto-to))";

    #print "@elisp\n"; exit 0;

    my @cmdline;
    if ($use_emacsclient) {
	if ($auto_daemon) {
	    @cmdline = qw/emacsclient -c --alternate-editor=/;
	}
	elsif ($create_frame) {
	    @cmdline = qw/emacsclient -c/;
	}
	else {
	    @cmdline = qw/emacsclient/;
	}
    }
    else {  @cmdline = qw/emacs/; }

    push @cmdline, '--eval', "@elisp";

    #print "@cmdline\n"; exit 0;
    exec @cmdline unless $_[0];
    system @cmdline;
}

my $last = pop @ARGV;
mail 1, $_ foreach (@ARGV);
mail 0, $last;
