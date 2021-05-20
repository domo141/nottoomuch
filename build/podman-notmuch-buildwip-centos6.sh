#!/bin/sh
#
# Author: Tomi Ollila -- too ät iki piste fi
#
#       Copyright (c) 2019 Tomi Ollila
#           All rights reserved
#
# Created: Sat 23 Nov 2019 20:11:23 +0200 too
# Last modified: Thu 20 May 2021 23:35:41 +0300 too

# SPDX-License-Identifier: Unlicense

case ${BASH_VERSION-} in *.*) set -o posix; shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) emulate ksh; esac

set -euf  # hint: sh -x thisfile [args] to trace execution

false || { # set to 'true' (or ': false') to enable
	printf '  %s\n' '' \
	'Disabled by default. See comment and use temporarily where useful.' ''
	exit 1
	Enable this script by changing "false" to "true" when testing and
	trying new content to be added to the "parent" container image
	{instead of fully rebuilding it every time}. Finally, copy newfound
	content to the "parent" container and disable this script.
	Dockerfile option is too limiting in many cases...
}

die () { printf '%s\n' "$@"; exit 1; } >&2

x () { printf '+ %s\n' "$*" >&2; "$@"; }

test $# -ne 0 || {
	exec >&2; echo
	echo "Usage: $0 prev-tag"
	echo
	echo '  prev-tag: TAG of notmuch-buildenv-centos6 container image'
	echo
	podman images notmuch-buildenv-centos6
	echo
	grep ' wip[0-9] '\' "$0"
	echo
	exit 1
}

tag=$1; shift

ciname=notmuch-buildenv-centos6:$tag
coname=notmuch-buildwip-centos6-$tag

if test "${1-}" != '--in-container--'
then
	test $# = 0 || die "'$*' extra args"
	case $tag
		in wip[1-8]) otag=wip$(( ${tag#wip} + 1 ))
		;; wip*) die "'$tag': unsupported wip prefix"
		;; *) otag=wip1
	esac

	podman inspect "$ciname" --format '{{.RepoTags}}'

	oname=${ciname%:*}:$otag
	if podman inspect "$oname" --format '{{.RepoTags}}'
	then die "'$oname' exists"
	fi

	case $0 in /*)	dn0=${0%/*}
		;; */*/*) dn0=`cd "${0%/*}" && pwd`
		;; ./*)	dn0=$PWD
		;; */*)	dn0=`cd "${0%/*}" && pwd`
		;; *)	dn0=$PWD
	esac

	x podman run --pull=never -it --privileged -v "$dn0:/mnt" \
		--tmpfs /tmp:rw,size=65536k,mode=1777 \
		--name "$coname" "$ciname" \
		/mnt/"${0##*/}" "$tag" --in-container-- "$otag"
	echo 'back in "host" environment...'

	x podman unshare sh -eufxc '
		mp=`exec podman mount '"$coname"'`
		( cd "$mp"; rm -rfv run; exec mkdir -m 755 run )
	'
	x podman commit --change 'CMD=/bin/bash' "$coname" "$oname"
	podman rm "$coname"

	echo
	echo all done
	echo
	exit 0
fi

# rest of the file executed in container #

if test -f /.rerun
then
	echo --
	echo -- 'failure in previous execution -- starting "rescue" shell'
	echo --
	/bin/bash
	echo 'exit from "rescue" shell'
	exit 1
fi
:>/.rerun

trap "{ set +x; } 2>/dev/null; echo; echo something failed
      echo ': execute ; podman start -ia $coname ;: to investigate'
      echo" 0

echo --
echo -- Executing in container -- xtrace now on -- >&2
echo --

d='nothing to do!'

set -x

test -f /run/.containerenv || die "No '/run/.containerenv' !?"

# note: no yum cleanups, temp/wip work...

if test "$2" = wip1
then
	yum -y install patchelf rh-python36-python-sphinx # 2nd round...
	#yum -y install libtalloc-devel glib2-devel
	d=
fi

if test "$2" = wip2
then
	false # already "merged", so not needed anymore
	yum -y install libffi-devel gettext-devel
	d=
fi

if test "$2" = wip3-not # was not useful, had to compile
then
	yum -y install pcre-devel pcre2-devel
	d=
fi

test -z "$d"

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
