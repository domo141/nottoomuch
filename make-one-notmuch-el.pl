#!/usr/bin/perl
# -*- mode: cperl; cperl-indent-level: 4 -*-

use 5.6.1;
use strict;
use warnings;

die "
Usage: $0 notmuch-dir

Example (entered in root of notmuch source): $0 .

This script builds one notmuch .elc file which can be convenient
for some purposes. This is provided in the hope that it will be
useful, but this is not guaranteed to work always. As a developer
tool you may have to fix it yourself.

" unless @ARGV == 1;

die $! unless chdir $ARGV[0];

sub needf ($$)
{
    if ($_[0]) {
	die "'$ARGV[0]/$_[1]': no such file.\n" unless -f $_[1];
    }
    else {
	die "'$ARGV[0]/$_[1]': no such directory.\n" unless -d $_[1];
    }

}

needf 0, 'emacs';
needf 1, 'emacs/notmuch.el';
needf 1, 'emacs/Makefile.local';
needf 1, 'Makefile.local';

system qw'make emacs/.eldeps WITH_EMACS=1';
die unless $? == 0;

my $eldeps = 'emacs/.eldeps';
open ELDEPS, '<', $eldeps or die "Opening $eldeps failed: $!\n";

my $sources = [ 'emacs/notmuch.el' ];
my %deps = ( 'emacs/notmuch.el' => [ 'emacs/notmuch-version.el' ] );

# load dependencies.

while (<ELDEPS>) {
    die "Unexpected line $. in $eldeps\n" unless /^(\S+[.]el)c:\s+(\S+[.el])c$/;
    my $lref = $deps{$1};
    if (defined $lref) {
	push @$lref, $2;
    }
    else {
	push @$sources, $1;
	$deps{$1} = [ $2 ];
    }
}
close ELDEPS;

my %seen;
my @files;

# resolve dependencies.

sub dodep($);
sub dodep($)
{
    foreach (@{$_[0]}) {
	next if $seen{$_}; $seen{$_} = 1;
	my $name = $_;

	dodep $_ foreach $deps{$name}; # surprisingly this worked...

	push @files, $name;
    }
}

dodep $sources;

# concatenate files to one.

open ONE, '>', 'emacs/one-notmuch.el'
  or die "Opening emacs/one-notmuch.el for writing failed: $!\n";

foreach (@files) {
    print "Reading $_ ...\n";
    open I, '<', $_ or die $!;
    binmode I;
    while (<I>) {
	if ( /\(declare-function.*"notmuch/ ) {
	    my $op = tr/(/(/ - tr/)/)/;
	    while ($op > 0) {
		$_ = <I>;
		last if eof I;
		$op += tr/(/(/ - tr/)/)/;
	    }
	    next
	}
	s/(\(provide)\s+(.*)/(eval-and-compile $1 $2)/;
	print ONE $_;
    }
    close I;
}
print ONE "
;; Local Variables:
;; byte-compile-warnings: (not cl-functions)
;; End:\n";
close ONE;

# build one-notmuch.elc

print "Wrote\n";
system qw'ls -l emacs/one-notmuch.el';
print "\nExecuting make emacs/one-notmuch.elc WITH_EMACS=1\n";
system qw'make emacs/one-notmuch.elc WITH_EMACS=1';
die unless $? == 0;
system qw'ls -l emacs/one-notmuch.elc';
exit $?
