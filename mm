#!/bin/sh

# mm -- more mail -- a notmuch (mail) wrapper

# Created: Tue 23 Aug 2011 18:03:55 EEST (+0300) too
# Last Modified: Tue 09 Dec 2014 15:01:43 +0200 too

# For everything in this to work, symlink this from it's repository
# working copy position to a directory in PATH.

set -eu

case ~ in '~') exec >&2; echo
	echo "Shell '/bin/sh' lacks some required modern shell functionality."
	echo "Try 'ksh $0${1+ $*}', 'bash $0${1+ $*}'"
	echo " or 'zsh $0${1+ $*}' instead."; echo
	exit 1
esac

case ${BASH_VERSION-} in *.*) shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) setopt shwordsplit no_nomatch; esac

warn () { echo "$@"; } >&2
die () { echo "$@"; exit 1; } >&2

usage () { echo "Usage: $0 $cmd" "$@"; exit 1; } >&2

x () { echo + "$@" >&2; "$@"; }
x_eval () { echo + "$*" >&2; eval "$*"; }

yesno ()
{
	echo
	case ${KSH_VERSION-} in
	 '')	echo	"$* (yes/NO)? \\c" ;;
	 *)	echo -e	"$* (yes/NO)? \\c" ;;
	esac
	read ans
	echo
	case $ans in ([yY][eE][sS]) return 0; esac
	return 1
}  </dev/tty

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
		case $dln in /*) d0=$dln ;; *) d0=$d0/$dln; esac
	fi
	case $d0 in *["$IFS"]*) die "'$d0' contains whitespace!"
	;; /*) ;; *) d0=`cd "$d0"; pwd`
	esac
}

try_canon_d0 () {
	case $d0 in */../*|*/./*)
		_xd0=`readlink -f $d0 2>/dev/null || :`
		case $_xd0 in /*) d0=$_xd0; esac
	esac
}

cmd_mua () # Launch emacs as mail user agent.
{
	case ${1-} in -y) ;; *)
		if ps x | grep 'emacs[ ].*[ ]notmuch'
		then    echo
			echo '^^^ notmuch emacs mua already running ? ^^^'
			echo
			echo "to run another, add '-y' to the command line"
			echo
			exit 0
		fi
	esac
	case ${DISPLAY-} in '')
		#printf '\033[8;38;108t'
		# the line below matches *my* N9 Fingerterm settings...
	        case $TERM in xterm) case `exec stty -a` in (*'rows 25; columns 85;'*)
			exec emacs --eval "(setq frame-background-mode 'dark)" -f notmuch
		esac; esac
		exec emacs -f notmuch
	esac
	set -x
	#exec nohup setsid emacs -g 108x38 -f notmuch >/dev/null
	exec nohup setsid emacs -f notmuch >/dev/null
	# the command above works best on linux interactive terminal
}

mbox2md5mda ()
{
	set_d0
	tmpfile=`cd $HOME/mail; LC_ALL=C exec perl -e '
		mkdir q"wip" unless -d q"wip";
		system q"mktemp", (sprintf q"wip/mbox-%x,XXXX", time)'`
	x $d0/mbox-to-mda.sh --movemail $HOME/mail/$tmpfile $MAIL \
		$d0/md5mda.sh --cd $HOME/mail received wip log ||
		: ::: mbox-to-mda.sh exited nonzero ::: :
	test -s $HOME/mail/$tmpfile || rm $HOME/mail/$tmpfile || :
}

cmd_new () # Import new mail.
{
	TIMEFORMAT='%Us user %Ss system %P%% cpu %Rs total'
	ymdhms=`exec date +%Y%m%d-%H%M%S`
	case ${MAIL-} in '') # nothing to do when ''
	;;	*"[$IFS]"*) warn "'$MAIL' contains whitespace. Ignored."
	;;	/var/*mail/*) test ! -s $MAIL || mbox2md5mda
	;;	*) warn "Suspicious '$MAIL' path. Ignored."
	esac
	set -x
	time notmuch new --verbose | tee -a $HOME/mail/wip/new-$ymdhms.log
	read line < $HOME/mail/wip/new-$ymdhms.log
	case $line in 'No new mail.'*) rm $HOME/mail/wip/new-$ymdhms.log
	;; *) mv $HOME/mail/wip/new-$ymdhms.log $HOME/mail/log/new-$ymdhms.log
	esac
}

cmd_frm () # Run frm-md5mdalog.pl.
{
	set_d0
	case ${1-} in -D) ;; *) exec $d0/frm-md5mdalog.pl "$@" ;; esac
	case $# in 1) usage -D match-re ;; esac
	shift
	echo; echo
	$d0/frm-md5mdalog.pl "$@"
	yesno "Delete the messages listed above"
	$d0/frm-md5mdalog.pl -f "$@" | xargs rm -fv
}

cmd_startfemmda5 () # startfetchmail.sh using md5mda.sh mda
{
	case $# in 4|5) ;; *)
		usage '[-I]' '(143|993)' '(keep|nokeep)' user server
	esac
	set_d0
	try_canon_d0
	cd $HOME
	case $d0 in $PWD/*) d0=${d0#$PWD/}; esac
	set -x
	exec $d0/startfetchmail.sh $@ \
		"$d0/md5mda.sh --cd mail received wip log"
}

cmd_delete () # remove emails with tag deleted
{
	case $#${1-}
	  in '1!')
		x_eval 'notmuch search --output=files tag:deleted | xargs rm'
		exit
	  ;; '1h')
		x notmuch search tag:deleted
	  ;; 0)
		x notmuch address tag:deleted
		echo "enter '!' to the command line to do actual deletion"
	  ;; *)
		usage '[!|h]'
	esac
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
			s/$0/'"$bn"'/g; s/\(.\{14\}\) */\1/p; }' $0
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

case $cc in '') echo ${0##*/}: $cm -- command not found.; exit 1
esac
case $cp in '') ;; *)
	echo ${0##*/}: $cm -- ambiguous command: matches $cc; exit 1
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
