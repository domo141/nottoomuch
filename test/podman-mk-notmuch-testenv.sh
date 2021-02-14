#!/bin/sh
#
# $ podman-mk-notmuch-testenv.sh $
#
# Author: Tomi Ollila -- too ät iki piste fi
#
#	Copyright (c) 2021 Tomi Ollila
#	    All rights reserved
#
# Created: Sun 07 Apr 2020 22:04:22 EEST too
# Last modified: Sun 14 Feb 2021 21:44:31 +0200 too

case ${BASH_VERSION-} in *.*) set -o posix; shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) emulate ksh; esac

set -euf  # hint: sh -x thisfile [args] to trace execution

# started this as buildah-.. but converted to podman-only solution so
# one doesn't need to install buildah (also) just for this purpose

if test "${1-}" != '--in-container--' # --- this block is executed on host ---
then
	from_img_names=' debian  ubuntu  fedora ' # more to add...

	die () { echo; printf '%s\n\n' "$@"; exit 1; } >&2
	x () { printf '+ %s\n' "$*" >&2; "$@"; }

	today=`exec date +%Y%m%d`

	test $# = 2 || die "Usage: $0 $today {from-image-name:tag}" \
		'Potentially working "from" image names:' "   $from_img_names"\
		"If successful, created image: notmuch-testenv-{from-image-name-tag}:$today"

	img_name=${2%:*}

	test "$img_name" != "$2" || die "'$2' is not in format 'name:tag'"

	case $from_img_names in *" $img_name "*) ;; *)
		die "'$img_name': unsupported \"from\" image name"
	esac

	test "$1" = $today || die "'$1' is not date of today ($today)"

	target_base=notmuch-testenv-${2%:*}-${2##*:} # in one : we trust

	target_image=$target_base:$1
	if podman inspect -t image --format='{{.RepoTags}} {{.Created}}' \
		"$target_image" 2>/dev/null
	then
		echo; echo "Target image '$target_image' exists."; echo
		exit 0
	fi
	podman inspect -t image --format='{{.Size}}' "$2" || {
		printf '\n"From" image missing;'
		echo ' podman pull the image before continuing.'
		echo
		exit 1
	}
	case $0 in /*)	dn0=${0%/*}
		;; */*/*) dn0=`exec realpath ${0%/*}`
		;; ./*)	dn0=$PWD
		;; */*)	dn0=`exec realpath ${0%/*}`
		;; *)	dn0=$PWD
	esac

	x podman run --pull=never -it --privileged -v "$dn0:/mnt:ro" \
		--tmpfs /tmp:rw,size=65536k,mode=1777 --hostname=buildhost \
		--name "$target_base-wip" "$2" \
		/bin/sh /mnt/"${0##*/}" --in-container-- "$2" ||
	die "Building '$target_image' failed..." \
	    ": execute; podman start -ia $target_base-wip ;: to investigate"

	echo 'back in "host" environment...'

	x podman unshare sh -eufxc '
		mp=`exec podman mount "'"$target_base-wip"'"`
		( cd "$mp"; rm -rfv run; exec mkdir -m 755 run )
	'
	x podman commit --change 'CMD=/bin/bash' \
		"$target_base-wip" "$target_image"
	podman rm "$target_base-wip"
	echo
	echo all done
	echo
	exit
fi

# --- rest of this file is executed in container --- #

if test -f /.rerun
then
	echo --
	echo -- 'failure in previous execution -- starting "rescue" shell'
	echo --
	exec /bin/bash
fi
:>/.rerun

echo --
echo -- Executing in container -- xtrace now on -- >&2
echo --

die () { exit 1; }

set -x

test -f /run/.containerenv || die "No '/run/.containerenv' !?"

case $2 in ( debian:* | ubuntu:* )
	export DEBIAN_FRONTEND=noninteractive
	apt-get update
	# note: no 'upgrade' -- pull new base image for that...
	# .travis.yml was helpful (but not complete)...
	apt-get install -y -q build-essential emacs-nox gdb git man \
		dtach libxapian-dev libgmime-3.0-dev libtalloc-dev \
		python3-sphinx python3-cffi python3-pytest \
		python3-setuptools libpython3-all-dev gpgsm parallel
	apt-get -y autoremove
	apt-get -y clean
	rm -rf /var/lib/apt/lists/
	exit
esac

case $2 in ( fedora:* )

	#dnf -v -y install epel-release findutils tar
	: Note: dnf commands below may be long-lasting and silent...
	dnf -v -y install make gcc gcc-c++ redhat-rpm-config git \
		xapian-core-devel gmime30-devel libtalloc-devel \
		zlib-devel python3-sphinx man dtach emacs-nox gdb \
		openssl gnupg2-smime xz diffutils parallel
	#$dnf -v -y autoremove # removes findutils in centos 7
	#$dnf -v -y clean all

	dnf -v -y clean all
	set +f
	rm -rf /var/cache/yum/ /var/lib/dnf/* # /var/lib/rpm/__db*
	set -f
	#rpm --rebuilddb
	# rmmm
	#test -x /usr/bin/gpg || ln -s gpg2 /usr/bin/gpg
	exit
esac


# Local variables:
# mode: shell-script
# sh-basic-offset: 8
# tab-width: 8
# End:
# vi: set sw=8 ts=8
