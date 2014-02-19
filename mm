#!/bin/sh

# mm -- more mail -- a notmuch (mail) wrapper

# Created: Tue 23 Aug 2011 18:03:55 EEST (+0300) too
# Last Modified: Wed 19 Feb 2014 23:24:37 +0200 too

# For everything in this to work, symlink this from it's repository
# working copy position to a directory in PATH.

set -eu

case ~ in '~') exec >&2; echo
	echo "Shell '/bin/sh' lacks some required modern shell functionality."
	echo "Try 'ksh $0${1+ $*}', 'bash $0${1+ $*}'"
	echo " or 'zsh $0${1+ $*}' instead."; echo
	exit 1
esac


cmd_source () # Display source of given $0 command (or function).
{
	case ${1-} in '') usage cmd-prefix ;; */*) echo; exit 0 ;; esac
	echo
	exec sed -n "/^cmd_$1/,/^}/p; /^$1/,/^}/p" "$0"
}

set_ln_of_file ()
{
	# whitespace in link target not tolerated...
	set x `exec ls -l "$1"`
	shift $(($# - 1))
	ln=$1
}

# Note: for this to work, either do not chdir before executing or run $0
# using absolute path ($0 has absolute path if PATH component is absolute)
set_d0 ()
{
	d0=${0%/*}; case $d0 in $0) d0=.; esac
	if test -h "$0"
	then	# symlink. we can tolerate one level, as readlink(1)
		set_ln_of_file "$0"	#  may not be always available.
		dln=${ln%/*}; case $dln in $ln) dln=.; esac
		d0=$d0/$dln
	fi
	case $d0 in /*) ;; *) d0=`cd "$dn0"; pwd` ;; esac
}

cmd_mua () # Launch emacs as mail user agent.
{
	case ${DISPLAY-} in '')
		printf '\033[8;38;108t'
		exec emacs -f notmuch
	esac
	exec nohup setsid emacs -g 108x38 -f notmuch >/dev/null
	# the command above works best on linux interactive terminal
}

mbox2md5mda ()
{
	set_d0
	tmpfile=`LC_ALL=C exec perl -e 'mkdir q"wip" unless -d q"wip";
                system q"mktemp", (sprintf q"wip/mbox-%x,XXXX", time)'`
	set -x
	$d0/mbox-to-mda.sh --movemail $tmpfile $MAIL \
		$d0/md5mda.sh received wip log ||
		: ::: mbox-to-mda.sh exited nonzero ::: :
	test -s $tmpfile || rm $tmpfile
}

cmd_new () # Import new mail.
{
	# XXX fix cd location to avoid the path problem...
	cd $HOME/mail # note: $0 needs to have absolute path for mbox2md5mda...
	TIMEFORMAT='%Us user %Ss system %P%% cpu %Rs total'
	ymdhms=`exec date +%Y%m%d-%H%M%S`
	case ${MAIL-} in '') set -x # nothing else to do
	;;	*"[$IFS]"*) warn "'$MAIL' contains whitespace. Ignored.";set -x
	;;	/var/*mail/*) test -s $MAIL && mbox2md5mda || set -x
	;;	*) warn "Suspicious '$MAIL' path. Ignored."; set -x
	esac
	time notmuch new --verbose | cat # tee -a log/new-$ymdhms.log
}

# --

case ${1-} in -x) set -x; shift; esac

case ${1-} in '')
	#bn=`exec basename "$0"`
	bn=${0##*/} # basename
	echo
	echo Usage: $0 '[-x] <command> [args]'
	echo
	echo $bn commands available:
	echo
	sed -n '/^cmd_[a-z0-9_]/ { s/cmd_/ /; s/ () [ -#]*/                   /
			s/$0/'"$bn"'/g; s/\(.\{13\}\) */\1/p; }' $0
	echo
	echo Commands may be abbreviated until ambiguous.
	echo
	exit 0
;; esac

cm=$1; shift

#case $cm in
#        d) cm=diff ;;
#esac

cc= cp=
for m in `LC_ALL=C exec sed -n 's/^cmd_\([a-z0-9_]*\) (.*/\1/p' $0`
do
	case $m in
		$cm) cp= cc=1 cmd=$cm; break ;;
		$cm*) cp=$cc; cc="$m $cc"; cmd=$m ;;
	esac
done

case $cc in '') echo $bn: $cm -- command not found.; exit 1
esac
case $cp in '') ;; *) echo $bn: $cm -- ambiguous command: matches $cc; exit 1
esac

unset cc cp cm
#set -x

cmd_$cmd ${1+"$@"}
exit


# Local variables:
# mode: shell-script
# sh-basic-offset: 8
# tab-width: 8
# End:
# vi: set sw=8 ts=8
