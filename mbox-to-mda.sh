#!/bin/sh
# $Id; mbox-to-mda.sh $
#
#	Copyright (c) 2011 Tomi Ollila
#	    All rights reserved
#
# Created: Tue Jul 26 11:45:58 2011 (+0300) too
# Last modified: Sat 22 Feb 2014 01:33:55 +0200 too

set -eu

case ${BASH_VERSION-} in *.*) shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) setopt shwordsplit; esac

saved_IFS=$IFS
readonly saved_IFS

die () { echo "$@" >&2; exit 1; }

usage () {
	bn=`basename "$0"`
	echo
	echo Usage: $bn [-q] [--movemail to-file] mbox-file mda-cmd [mda-args]
	echo
}

set_argval () { shift; argval="$*"; }

mmmboxf=
verbose_echo () { echo "$@"; }
while case ${1-} in
	-q) verbose_echo () { :; } ;;
	-h|-?|--help) usage; exec sed -n '/^This program /,$ p' "$0" ;;
	--movemail=*) IFS==; set_argval $1; IFS=$saved_IFS; mmmboxf=$argval ;;
	--movemail) mmmboxf=$2; shift ;;
	--) shift; false ;;
	-|-*) die "'$1': unknown option" ;;
	*) false
esac; do shift; done

case $# in 0|1)
	exec >&2
	usage
	echo Enter '' $0 --help '' for more help
	echo
	exit 1
esac

mbox=$1
shift

test -f "$mbox" || die "'$mbox': no such file"
test -x "$1" || die "'$1' cannot be executed"
test -s "$mbox" || { verbose_echo "Mail file '$mbox' is empty"; exit 0; }

# check formail(1) existence
formail=`exec which formail 2>/dev/null || :`
case $formail in /*/formail) ;;
	*) die "Cannot find 'formail' program"
esac
verbose_echo Using formail $formail

case $mmmboxf in '') ;; *)
 # search for movemail(1)
 movemail=`exec which movemail 2>/dev/null` || :
 case $movemail in /*/movemail) echo foo ;;
  *) movemail=`emacs --batch --eval '(progn (defun find-bin (path)
	(if (file-exists-p (concat (car path) "/movemail"))
		(message (concat (car path) "/movemail"))
		(if (not (eq (cdr path) nil))
			(find-bin (cdr path)))))
	(find-bin exec-path))' 2>&1 | tail -1 || :`
  case $movemail in /*/movemail) ;;
	*) die "Cannot find 'movemail' program"
  esac
 esac

 verbose_echo Using movemail $movemail
esac

tmmf=
case $mmmboxf in '') ;; *)
	tmmf=$mmmboxf.wip

	"$movemail" "$mbox" "$tmmf"

	test -s "$tmmf" || {
		verbose_echo "Moved mail file '$tmmf' is empty."
		rm -f "$tmmf"
		exit 0
	}
esac

"$formail" -bz -R 'From ' X-From-Line: -s "$@" < "${tmmf:-$mbox}"

case $tmmf in '') ;; *) mv "$tmmf" "$mmmboxf" || :
esac
exit

# Old thoughts about lockfile(1) usage.. now replaced with movemail(1).

# If I ctrl-c when lockfile running, It seems to be possible
# that lockfile gets created (but not deleted), if ctrl-c
# hits between creating lock and trap instantiation.
# trap cannot be instantiated earlyer as it would make possible
# removing lock created by another process.
# I wish there were way to determine (random) content in lockfile
# then we could check the contents and if matches, then delete
# the lockfile is content matches.

# Internally this script uses 'movemail' to move mails from mbox file
# (supposedly atomically) and 'formail' to split these mails to
# separate streams each given to mda-cmd provided in command line...

This program delivers all mail from mbox file to an MDA program given
on command line.

Options:
          -q                    keep quiet on non-fatal messages
          --movemail to-file    move mail file to new location (to avoid
                                concurrent updates) before continuing

mbox-file    the mbox file where mails are to be extracted
mda-cmd      mail delivery agent command which is executed for each
             individual email which are present in mbox-file
[mda-args]   optional arguments for mda-cmd

Example: Shell wrapper which uses md5mda.sh as MDA.

cat > mbox-to-md5mda.sh <<EOF
#/bin/sh
d0=`dirname "$0"`
case $d0 in /*) ;; *) d0=`cd "$d0"; pwd` ;; esac
cd $HOME/mail
tmpfile=`LC_ALL=C exec perl -e 'mkdir q"wip" unless -d q"wip";
                system q"mktemp", (sprintf q"wip/mbox-%x,XXXX", time)'`
"$d0"/mbox-to-mda.sh --movemail $tmpfile $MAIL "$d0"/md5mda.sh received wip log
EOF
