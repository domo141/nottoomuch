#!/bin/sh
# $Id; md5mda.sh $
#
#	Copyright (c) 2011-2014 Tomi Ollila
#	    All rights reserved
#
# Created: Thu Jul 28 2011 21:52:56 +0300 too
# Last modified: Tue 21 Jan 2014 17:55:50 +0200 too

set -eu

# When launched from ~/.forward, PATH not available...
PATH=$HOME/bin:/usr/bin:/bin:/usr/local/bin:/usr/sbin:/sbin
export PATH

case ${BASH_VERSION-} in *.*) shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) setopt shwordsplit; esac

saved_IFS=$IFS
readonly saved_IFS

# die() will be re-defined a bit later
die () { echo "$@" >&2; exit 1; }

# fd 3 will be opened to a file a bit later
log () { echo `exec date +'%Y-%m-%d (%a) %H:%M:%S'`: "$@" >&3; }

usage () {
	bn=`exec basename "$0"`
	echo
	echo Usage: $bn [--cd dir] [--log-tee-stdout] maildir wipdir logdir
	echo
}

set_argval () { shift; argval="$*"; }

while case ${1-} in
	-h|-?|--help) usage; exec sed -n '/^Options:/,$ p' "$0" ;;
	--cd=*) IFS==; set_argval $1; IFS=$saved_IFS; cd "$argval" ;;
	--cd) cd "$2"; shift ;;
	--log-tee-stdout)
		log () {
			date=`exec date +'%Y-%m-%d (%a) %H:%M:%S'`
			echo $date: "$@" >&3; echo $date: "$@"
		} ;;
	--) shift; false ;;
	-|-*) die "'$1': unknown option" ;;
	*) false
esac; do shift; done

case $# in 3) ;; *)
	exec >&2
	usage
	echo Enter '' $0 --help '' for more help
	echo
	exit 1
esac

nospaces ()
{
	case $2 in *[$IFS]*) die "$1 '$2' contains whitespace"; esac
}

maildir=$1 wipdir=$2 logdir=$3

nospaces maildir "$maildir"
nospaces wipdir "$wipdir"
nospaces logdir "$logdir"

eval `exec date +'year=%Y mon=%m'`

test -d $logdir || mkdir -p $logdir
exec 3>> $logdir/md5mda-$year$mon.log

# had to write the above as exec failure below is uncaughtable (in dash)
#{ exec 3>> $logdir/md5mda-$year$mon.log || {
#	mkdir -p $logdir
#	exec 3>> $logdir/md5mda-$year$mon.log; }
#} 2>/dev/null

die () { log "$@"; echo "$@" >&2; exit 1; }

if=`exec mktemp $wipdir/incoming.XXXXXX 2>/dev/null` || :
case $if in '')
	mkdir -p $wipdir
	if=`exec mktemp $wipdir/incoming.XXXXXX`
esac

# Write mail content from stdin to a file.
# 'bogofilter -p' could be used here (bogofilter keeps whole mail in memory).
cat >> $if

# openssl md5 provides same output on Linux & BSD systems (at least).
eval `openssl md5 $if | sed 's:.* \(..\):dirp=\1 filep=:'`
case $filep in '')
	die "Executing 'openssl md5 $if' failed!"
esac

# try atomic move, w/ link & unlink. don't overwrite old if any
trymove ()
{
    ln "$1" "$2" 2>/dev/null || return 0 # note: inverse logic in return value
    unlink "$1" || : # leftover if unlink (ever) fails...
    return 1
}

dof=$maildir/$dirp
of=$dof/$filep

movemailfile ()
{
	trymove $if $of || return 0

	# in most of the cases execution doesn't reach here.

	test -d $dof || mkdir -p $dof || : # parallel mkdir possible...
	trymove $if $of || return 0

	# if next test fails, leftover $if will be there
	test -f $of || die "ERROR: ln $if $of (where '$of' nonexistent) failed"

	for f in $of*
	do
		# duplicate mails are more probable collision reason than...
		if cmp -s $if $f
		then
			log "Duplicate mail '$f' ignored"
			rm $if
			exit 0
	       fi
	done
	# hmm, same sum but not duplicate. Older edited ?
	osum=`openssl md5 $of | sed 's:.* \(..\):\1/:'`
	case $osum in $dirp/$filep)
		log "WHOA! '$of' with 2 different files !"
		echo "WHOA! '$of' with 2 different files !" >&2
	esac
	# We don't go into rename game in this script, we just want to
	# deliver mail files.... Note that the mktemp is done in the target
	# dir to assume uniqueness in first hit -- so there is temporary
	# zero-sized file for a short moment until it is replaced by the real
	# mail file (with different inode number). In the very improbable
	# chance the temporary file is ever there and noticed this should not
	# cause any other problem than slight confusion (if ever that).
	of=`exec mktemp $of.XXXXXX`
	mv -f $if $of
}
movemailfile

log "Added '$of'"

exit 0

Options:

   --cd dir          -- change current directory to 'dir' before continuing
   --log-tee-stdout  -- write log also to stdout

Parameters:

   maildir -- the root directory for delivered mail
   wipdir  -- work in progress temporary location for mail in delivery
   logdir  -- directory where delivery logs are written

The mail is read from stdin and it is first written to a file in 'wipdir'
and its md5 checksum is calculated there. After that the file is moved to
a subdirectory(*) in 'maildir'.
Maildir and wipdir needs to be in the same file system.

(*) The subdirectory is the 2 first hexdigits of the md5 checksum of the
    mail contents and the filename is the rest 30 hexdigits of the checksum.
.
