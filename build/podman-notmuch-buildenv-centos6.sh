#!/bin/sh
#
# Author: Tomi Ollila -- too ät iki piste fi
#
#       Copyright (c) 2019 Tomi Ollila
#           All rights reserved
#
# Created: Sun 20 Oct 2019 20:41:59 +0300 too
# Last modified: Tue 26 Nov 2019 20:59:30 +0200 too

# SPDX-License-Identifier: BSD-2-Clause

case ${BASH_VERSION-} in *.*) set -o posix; shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) emulate ksh; esac

set -euf  # hint: sh -x thisfile [args] to trace execution

die () { printf '%s\n' "$@"; exit 1; } >&2

x () { printf '+ %s\n' "$*" >&2; "$@"; }

tname=notmuch-buildenv-centos6

if test "${1-}" != '--in-container--'
then
	today=`exec date +%Y%m%d`
	test $# = 1 ||
		die '' \
		    "Usage $0 '$today' -- i.e. today's date as the only arg" \
		 '' 'Note: may pull centos:6.10 from an external registry.' ''
	test "$1" = $today || die "'$1' != '$today'"

	if podman images -n --format='{{.Repository}}:{{.Tag}} {{.Created}}' |
		grep $tname:$1' '
	then
		echo Target image exists.
		exit 0
	fi

	podman inspect centos:6.10 --format '{{.RepoTags}}'

	case $0 in /*)	dn0=${0%/*}
		;; */*/*) dn0=`exec realpath ${0%/*}`
		;; ./*)	dn0=$PWD
		;; */*)	dn0=`exec realpath ${0%/*}`
		;; *)	dn0=$PWD
	esac

	# remember in next container: --net=none \
	x podman run -it --privileged -v "$dn0:/mnt" \
		--tmpfs /tmp:rw,size=65536k,mode=1777 \
		--name $tname-wip centos:6.10 \
		/mnt/"${0##*/}" --in-container--
	echo 'back in "host" environment...'

	x podman unshare sh -eufxc '
		mp=`exec podman mount '"$tname"'-wip`
		( cd "$mp"; rm -rfv run; exec mkdir -m 755 run )
	'
	x podman commit --change 'ENTRYPOINT=["/usr/libexec/entrypoint"]' \
		--change 'CMD=/bin/bash' $tname-wip $tname:$1
	podman rm $tname-wip
	echo
	echo all done
	echo
	exit 0
fi

### rest of this file is executed in container ###

if test -f /.rerun
then
	echo --
	echo -- 'failure in previous execution -- starting "rescue" shell'
	echo --
	exec /bin/bash
fi
:>/.rerun

trap "{ set +x; } 2>/dev/null; echo; echo something failed
      echo ': execute ; podman start -ia $tname-wip ;: to investigate'
      echo" 0

echo --
echo -- Executing in container -- xtrace now on -- >&2
echo --

set -x

test -f /run/.containerenv || die "No '/run/.containerenv' !?"

yum -y install epel-release centos-release-scl

yum -y install devtoolset-8-gcc-c++ sclo-git212-git rh-python36 zsh xz \
	libtalloc-devel libffi-devel gettext-devel \
	rh-python36-python-sphinx patchelf

yum clean all
rm -rf /var/lib/yum/yumdb

(
 set +f +u
 for f in /opt/rh/*/enable
 do test -f $f || continue
    source $f
 done
 set -f -u
 exec 3>&1 > entrypoint.c
 echo 'int putenv(char *string);'
 echo 'int execvp(const char *file, char ** argv);'
 echo 'int main(int argc, char ** argv) {'
 echo "  putenv(\"PATH=$PATH\");"
 echo "  putenv(\"MANPATH=$MANPATH\");"
 echo "  putenv(\"INFOPATH=$INFOPATH\");"
 echo "  putenv(\"LD_LIBRARY_PATH=$LD_LIBRARY_PATH\");"
 echo "  putenv(\"PERL5LIB=$PERL5LIB\");"
 echo "  putenv(\"XDG_DATA_DIRS=$XDG_DATA_DIRS\");"
 echo "  putenv(\"PKG_CONFIG_PATH=$PKG_CONFIG_PATH\");"
 echo '  return execvp(argv[1], argv + 1);'
 echo '}'
 exec 1>&3 3>&-
 gcc -Wall -Wextra -O2 -o /usr/libexec/entrypoint entrypoint.c
 rm entrypoint.c
)

trap - 0
rm /.rerun
:
: all done in container
:


# Local variables:
# mode: shell-script
# sh-basic-offset: 8
# tab-width: 8
# End:
# vi: set sw=8 ts=8
