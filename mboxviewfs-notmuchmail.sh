#!/bin/sh
# -*- mode: shell-script; sh-basic-offset: 8; tab-width: 8 -*-
# $ mboxviewfs-notmuchmail.sh $
#
# Author: Tomi Ollila -- too ät iki piste fi
#
#	Copyright (c) 2016 Tomi Ollila
#	    All rights reserved
#
# Created: Thu 27 Oct 2016 20:46:23 EEST too
# Last modified: Thu 27 Oct 2016 21:35:28 +0300 too

case ~ in '~') echo "'~' does not expand. old /bin/sh?" >&2; exit 1; esac

case ${BASH_VERSION-} in *.*) PATH=/ shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) PATH=/ emulate ksh; esac

set -u  # expanding unset variable makes non-interactive shell exit immediately
set -f  # disable pathname expansion by default -- makes e.g. eval more robust
set -e  # exit on error -- know potential false negatives and positives !
#et -x  # s/#/s/ may help debugging  (or run /bin/sh -x ... on command line)

LANG=C LC_ALL=C; export LANG LC_ALL
# LANG=en_IE.UTF-8 LC_ALL=en_IE.UTF-8; export LANG LC_ALL; unset LANGUAGE
# PATH='/sbin:/usr/sbin:/bin:/usr/bin'; export PATH

# XXX If bash finds *this* script by searching PATH...
case $0 in */*) ;; *)
	echo "'$0' does not contain '/'s. try './$0'" >&2; exit 1
esac

saved_IFS=$IFS; readonly saved_IFS

warn () { printf '%s\n' "$*"; } >&2
die () { printf '%s\n' "$@"; exit 1; } >&2

x () { printf '+ %s\n' "$*" >&2; "$@"; }
x_env () { printf '+ %s\n' "$*" >&2; env "$@"; }
x_eval () { printf '+ %s\n' "$*" >&2; eval "$*"; }
x_exec () { printf '+ %s\n' "$*" >&2; exec "$@"; die "exec '$*' failed"; }

test "${XDG_RUNTIME_DIR-}" || die '' \
 "'$0' requires 'XDG_RUNTIME_DIR' environment variable" \
 "to be set to some existing directory. Subdirectory 'mboxviewfs-notmuch'" \
 "will be created to that directory."\
 "Enter 'XDG_RUNTIME_DIR=... $0' to continue." ''

test -d "$XDG_RUNTIME_DIR" || die '' "Directory '${XDG_RUNTIME_DIR-}'"\
 "(value of \$XDG_RUNTIME_DIR) does not exist." ''

mountpoint=$XDG_RUNTIME_DIR/mboxviewfs-notmuch

test -d "$mountpoint" || mkdir "$mountpoint"

stat_rd=`exec stat -c %D "$XDG_RUNTIME_DIR"`
stat_mp=`exec stat -c %D "$mountpoint"`

test "$stat_rd" = "$stat_mp" || die '' "Directories '$XDG_RUNTIME_DIR'" \
	"and '$mountpoint' are on" \
	"different devices ($stat_rd and $stat_mp). So not (re!)mounting."

case $0 in /*) fn0=$0
	;; */*/*) fn0=`exec readlink -f "$0"`
	;; ./*) fn0=$PWD/${0#??}
	;; */*) fn0=`exec readlink -f "$0"`
	;; *)	fn0=$PWD/$0
esac
dn0=${fn0%/*}

x cd "$dn0"
test -f mboxviewfs.c || die "No 'mboxviewfs.c' in '$dn0'"
newer1=`exec ls -t mboxviewfs.c mboxviewfs 2>/dev/null || :`

case $newer1 in mboxviewfs.c*) # mboxviewfs.c is never (or no mboxviewfs)
	x sh mboxviewfs.c
esac
unset newer1

x wget --continue https://notmuchmail.org/archives/notmuch.mbox

x ./mboxviewfs notmuch.mbox "$mountpoint"

maildir=`exec notmuch config get database.path`
# double-check!
test -d "$maildir" || die "surprisingly '$maildir' is not a directory"
lndst=$maildir/mboxviewfs-notmuch
test -d "$lndst" || mkdir "$lndst"

x cd $mountpoint
set +f
for d in 2???-[01][0-9]
do
	test -d "$lndst"/$d &&
	test "$mountpoint"/$d -ef "$lndst"/$d && continue || :
	test ! -h "$lndst"/$d || rm "$lndst"/$d
	test ! -e "$lndst"/$d || die "'$lndst/$d' exists but is not symlink"
	x ln -s "$mountpoint"/$d "$lndst"/$d
done
