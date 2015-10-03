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
# Last modified: Mon 30 Jun 2014 00:33:38 +0300 too

use 5.8.1;
use strict;
use warnings;

die "Usage: $0 mailto-url\n" unless @ARGV;

sub mail($$)
{
    my $rest;
    ($_, $rest) = split /\?/, $_[1], 2;
    s/^mailto://; #s/\s+//g;
    my %hash = ( to => [], subject => [], cc => [], bcc => [], keywords => [],
		 from => [], body => [] );
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
    my $from = liornil 'from';

    my @elisp = ( "(progn (require 'notmuch)",
		  " (notmuch-mua-mail $to $subject $from nil",
		  "	(notmuch-mua-get-switch-function))" );
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

    unless (fork) {
	open STDOUT , '>', '/dev/null';
	open STDERR , '>&', \*STDOUT;
	exec qw/emacsclient --eval t/;
    }
    wait;
    my $editor = $? ? $ENV{EMACS}||'emacs' : $ENV{EMACSCLIENT}||'emacsclient';
    my @cmdline = ( $editor, '--eval', "@elisp" );

    # my @cmdline = ( $ENV{EMACSCLIENT} || 'emacsclient',
    # '-a', $ENV{EMACS} || 'emacs', '--eval', "@elisp" );

    eval @cmdline unless $_[0];
    system @cmdline;
}

my $last = pop @ARGV;
mail 1, $_ foreach (@ARGV);
mail 0, $last;
