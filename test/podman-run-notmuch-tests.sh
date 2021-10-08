#!/bin/sh
#
# $ podman-run-notmuch-tests.sh $
#
# Author: Tomi Ollila -- too ät iki piste fi
#
#	Copyright (c) 2021 Tomi Ollila
#	    All rights reserved
#
# Created: Fri 12 Feb 2021 22:37:42 EET too
# Last modified: Fri 08 Oct 2021 23:24:29 +0300 too

# use podman-mk-notmuch-testenv.sh to create container image for this tool...

case ${BASH_VERSION-} in *.*) set -o posix; shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) emulate ksh; esac

set -euf  # hint: sh -x thisfile [args] to trace execution

eval_dirabspath () # val '=' $var
{
 eval ' case $3 in .)	  '$1'=$PWD
		;; /*)	  '$1'=$3
		;; */*/*) '$1'=`cd "$3" && pwd`
		;; ./*)   '$1'=$PWD/${3#./}
		;; */*)   '$1'=`cd "$3" && pwd`
		;; *)	  '$1'=$PWD/$3
	esac '
}

test $# -le 1 || bd=${1##*/} bd=${bd#notmuch-testenv-}

if test "${1-}" != '--in-container--' # --- this block is executed on host ---
then
	case $# in 2|3) ;; *)
	  exec >&2; echo
	  echo "Usage: ${0##*/} ['notmuch-testenv-']{image-name:tag} \\"
	  echo "          ({srcdir} [tree-ish]|'.'|'bash')"
	  echo
	  echo Available container images:
	  format='table {{.Repository}}:{{.Tag}} {{.CreatedSince}} {{.Size}}'
	  podman images --format="$format" 'notmuch-testenv-*'
	  cdt='current dir'
	  echo
	  echo ' srcdir:  path where notmuch source is located'
	  echo "          (out of tree build, builddir is created in $cdt)"
	  echo "    '.':  build and run tests in notmuch source dir"
	  echo "          (current dir has to be notmuch source dir)"
	  echo " 'bash':  start bash in podman-started testenv container"
	  echo "          (build and run tests manually in container)"
	  echo
	  echo ' [tree-ish]:  optional argument to be used with srcdir:'
	  echo '              git commit or tree to copy to builddir'
	  echo
	  exit 1
	esac
	case $1 in *notmuch-testenv-*) image=$1
		;; *)  image=notmuch-testenv-$1
	esac

	eval_dirabspath dn0 = "${0%/*}"

	if test "$2" = bash
	then
		case $PWD in $HOME/*/*) ;; *) die "'$PWD' not '$HOME/*/*'"
		esac
		# mount subdir in $HOME, to disable access to full $HOME
		md=${PWD#$HOME/*/}; md=${PWD%/$md}

		set -x
		exec podman run --pull=never --rm -it --privileged \
			--tmpfs /tmp:rw,size=65536k,mode=1777 \
			-v "$dn0:/mnt:ro" -v "$md:$md" -w "$PWD" \
			--hostname=$bd "$image" /bin/bash
		exit not reached
	fi

	die () { echo; printf '%s\n\n' "$@"; exit 1; } >&2

	test -d "$2" || die "'$2': no such directory (notmuch source)"
	for f in notmuch.c Makefile.global Makefile.local Makefile configure
	do
		test -f "$2/$f" || die "'$2/$f' does not exist" \
			"'$2' does not look like a notmuch source directory"
	done

	if test "$2" != '.'
	then
		eval_dirabspath ap2 = "$2"
		case $ap2 in $HOME/*/*) ;; *) die "'$ap2' not '$HOME/*/*'"
		esac
		# mount subdir in $HOME, to disable access to full $HOME
		md=${ap2#$HOME/*/}; md=${ap2%/$md}

		case $dn0 in $md/*) ;; *) die "'$dn0' not '$md/*'" ;; esac
		case $PWD in $md/*) ;; *) die "'$PWD' not '$md/*'" ;; esac
	else
		md=$PWD
		ap2='.'
	fi

	podman inspect -t image --format='{{.Size}}' "$image" 2>/dev/null || {
		exec >&2
		echo "'$1': image missing"
		echo
		echo Available container images:
		f='table {{.Repository}}:{{.Tag}} {{.CreatedSince}} {{.Size}}'
		podman images --format="$f" 'notmuch-testenv-*'
		echo
		echo podman-mk-notmuch-testenv.sh \
			can be used to create a new one...
		echo; exit
	}
	set -x
	exec podman run --pull=never --rm -it --privileged \
		--tmpfs /tmp:rw,size=65536k,mode=1777 \
		-v "$dn0:/mnt:ro" -v "$md:$md" -w "$PWD" "$image" \
		/bin/bash /mnt/"${0##*/}" --in-container-- \
			"$image" "$ap2" ${3:+"$3"}
	exit not reached
fi

# --- rest of this file is executed in container --- #

timez ()
{
	printf -v t '%(%s)T' -1
	printf -v $1 '%(%s)T' $t
	printf -v $2 '%(%H:%M:%S)T' $t
} 2>/dev/null

set -x

( : ) & wait; pid0=$!
ymd_hms=`exec date +%Y%m%d-%H%M%S`
#ymd_hms=`date +%Y%m%d-%H%M%S` # ooh, same pid count as above (???)
( : ) & wait; pid1=$!

sd=$3

if test "$sd" != '.'
then
	bd=${2##*/} bd=${bd#notmuch-testenv-}
	bd=nmbd-$ymd_hms-${bd%:*}-${bd#*:}

	mkdir "$bd"
	cd "$bd"
	if test "${4-}"
	then
		git -C "$3" archive --format tar "$4" | tar xf -
		sd='.'
	fi
fi

timez ss2 st2
( : ) & wait; pid2=$!


"$sd"/configure

if test "$sd" != '.'
then
	# temp hack to disable python bindings in out-of-tree builds
	sed -i '/HAVE_PYTHON/ s/1/0/' Makefile.config sh.config
fi

timez ss3 st3
( : ) & wait; pid3=$!
make

timez ss4 st4
( : ) & wait; pid4=$!
make test && ev=0 || ev=$?

timez ss5 st5
( : ) & wait; pid5=$!

set +x

#printf '%s %2d %s\n' - $$     'first pid'
#printf '%s %2d %s\n' - $pid0  'test pid'
#printf '%s %2d %s\n' - $pid1  'test pid2'
#printf '%s %2d %s\n' - $pid2  'before configure'

xpid=$pid2 xss=$ss2
prnt ()
{
	printf '%s %-10s %5d  %5s  %5s\n' \
		$1 "$2" $(($3 - xpid - 1)) \~$(($4 - xss))s \~$(($4 - ss2))s
	xpid=$3 xss=$4
}

echo ' start   cmd         pids   secs    tot'
prnt $st2 'configure' $pid3 $ss3
prnt $st3 'make'      $pid4 $ss4
prnt $st4 'make test' $pid5 $ss5
echo $st5 'end'
echo
echo $PWD
echo

exit $ev


# Local variables:
# mode: shell-script
# sh-basic-offset: 8
# tab-width: 8
# End:
# vi: set sw=8 ts=8
