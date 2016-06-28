#!/bin/sh
# -*- mode: shell-script; sh-basic-offset: 8; tab-width: 8 -*-
#
# Created: Sat 06 Jul 2013 20:08:27 EEST too
# Last modified: Thu 13 Feb 2014 19:01:45 +0200 too

set -eu
#set -x # or enter /bin/sh -x ... on command line.

#case ~ in '~') exec >&2; echo
#	echo "Shell '/bin/sh' lacks some required modern shell functionality."
#	echo "Try 'ksh $0${1+ $*}', 'bash $0${1+ $*}'"
#	echo " or 'zsh $0${1+ $*}' instead."; echo
#	exit 1
#esac

# LANG=C LC_ALL=C; export LANG LC_ALL
PATH='/sbin:/usr/sbin:/bin:/usr/bin'; export PATH

warn () { echo "$@"; } >&2
die () { exec >&2; echo "$@"; exit 1; }

case ${BASH_VERSION-} in *.*) shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) setopt shwordsplit; esac

x () { echo + "$@" >&2; "$@"; }
x_exec () { echo + "$@" >&2; exec "$@"; }

usage () { echo; echo Usage: $0 $cmd "$@"; exit 1; } >&2

yesno ()
{
	echo
	echo "$0: $* (yes/NO)? \\c"
	read ans
	echo
	case $ans in ([yY][eE][sS]) return 0; esac
	return 1
}  </dev/tty

y_n_e ()
{
	while :; do
		echo "$0: $* (y/n)? \\c"
		stty raw -echo
		ans=`exec head -c 1`
		stty -raw echo
		echo
		case $ans in
			(y) return 0 ;;
			(n) return 1 ;;
			(e) yesno Do you want to exit && exit 0 ;;
		esac
	done
}  </dev/tty


cmd_source () # check source of given '$0' command
{
	set +x
	case ${1-} in '') die $0 $cmd cmd-prefix ;; esac
	echo
	exec sed -n "/cmd_$1.*(/,/^}/p" "$0"
}

die_unclean ()
{
	echo
	echo working tree not clean\\c
	echo '' -- exiting to avoid accidental data loss.
	die
} >&2

cmd_update () # update dogfood branch to origin/dogfood
{
	#case `exec git symbolic-ref --short HEAD` in dogfood) ;; *)
	case `exec git rev-parse --abbrev-ref HEAD` in dogfood) ;; *)
		exec >&2
		git branch
		echo
		echo "current branch not 'dogfood' -- exiting."
		die
	esac
	case `exec git status --porcelain` in '') ;; *)
		exec >&2
		git status >&2
		die_unclean
	esac
	case `x git clean -ndx` in '') ;;
		*) die_unclean
	esac
	date=`exec date +%Y%m%d-%H%M%S`
	x git branch dogfood-$date dogfood
	x git fetch --all -p
	x git reset --hard origin/dogfood
	echo
	echo if you now remember that you had some local commits in dogfood
	echo those are now '"backupped"' in branch dogfood-$date.
	echo \$ git branch -D dogfood-$date when you are done with it.
	echo \$ tig --all -10 is also useful.
	echo
}

cmd_master () # set master to origin/master
{
	#case `exec git branch --list master` in '*'*) ;;
	case `exec git rev-parse --abbrev-ref HEAD` in master)
		die "cannot set master when in master branch. Run git pull?"
	esac
	x git fetch --all -p
	x git branch --list -v master
	# this is found by experiment (although explanations say otherwise)
	case `exec git rev-list --boundary origin/master..master` in '') ;;
		*) die "master & origin/master diverged ???"
	esac
	x git branch -f master origin/master
	x_exec git branch --list -v master

}

dfbranch ()
{
	git branch -r | sort -r | sed -n '/\/df-/ { s|.*origin/||p;q; }'
}

cmd_dfpushtree () # push dogfood tree to df-yymm branch with new commit
{
	case $# in 1) dfbranch=`dfbranch` ;; 2) dfbranch="$2" ;;
		*) usage ref-for-commit-msg '[df-branch]'
	esac

	case $dfbranch in
		*' '*) die "df branch '$dfbranch' contains spaces" ;;
		df-*) ;;
		*) die "df branch '$dfbranch' does not start with df-"
	esac

	GIT_AUTHOR_DATE=`exec git log -1 --pretty=%at "$1"`
	export GIT_AUTHOR_DATE

	eval `git log -1 --pretty='treeish=%T tree7=%t' dogfood`
	eval `git log -1 --pretty='parent_commit=%H parc7=%h' origin/$dfbranch`
	tmpmsg=./-dfpt-tmpmsg-
	trap 'rm -rf $tmpmsg*' 0
	exec 3> $tmpmsg
	echo tree
	echo tree: $tree7, parent commit: $parc7 >&3
	echo >&3
	echo tree: $treeish >&3
	echo parent commit: $parent_commit >&3
	case $1 in master|dogfood) ;; *)
	  echo >&3
	  x git log -1 --name-status --pretty=fuller "$1" >&3 2>&3
	esac
	echo >&3
	x git log -1 --name-status --pretty=fuller master >&3 2>&3
	echo >&3
	x git log -1 --name-status --pretty=fuller dogfood >&3 2>&3
	${EDITOR:-emacs} $tmpmsg
	new_commit=`git commit-tree $treeish -p $parent_commit < $tmpmsg`
	x git log -1 --pretty=raw --name-status $new_commit
	x git --no-pager diff $new_commit dogfood
	yesno "execute 'git push origin \$new_commit:$dfbranch'"
	x git push origin $new_commit:$dfbranch
	if git branch | grep "$dfbranch" >/dev/null
	then 	echo git branch -f $dfbranch origin/$dfbranch ';: ?'
	fi
}

cmd_tig () # tig --all
{
	x_exec tig --all
}

cmd_cmds () # useful lines...
{
	echo '
	echo git commit --amend -C HEAD //files// && git push --force
	echo git cherry-pick dogfood
'
}


# ---

case ${1-} in '')
	bn0=`exec basename "$0"`
	echo
	echo Usage: $0 '<command> [args]'
	echo
	echo $bn0 commands available:
	echo
	sed -n '/^cmd_[a-z0-9_]/ { s/cmd_/ /; s/ () [ #]*/                   /
		s/$0/'"$bn0"'/; s/\(.\{13\}\) */\1/p; }' "$0"
	echo
	echo Command can be abbreviated to any unambiguous prefix.
	echo
	exit 0
esac

cm=$1; shift

# case $cm in
# 	d) cm=diff ;;
# esac

cc= cp=
for m in `LC_ALL=C exec sed -n 's/^cmd_\([a-z0-9_]*\) (.*/\1/p' "$0"`
do
	case $m in
		$cm) cp= cc=1 cmd=$cm; break ;;
		$cm*) cp=$cc; cc="$m $cc"; cmd=$m ;;
	esac
done

case $cc in '') echo $0: $cm -- command not found.; exit 1
esac
case $cp in '') ;; *) echo $0: $cm -- ambiguous command: matches $cc; exit 1
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
