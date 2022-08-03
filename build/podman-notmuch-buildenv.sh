#!/bin/sh
#
# $ podman-notmuch-buildenv.sh $
#
# Author: Tomi Ollila -- too ät iki piste fi
#
#	Copyright (c) 2022 Tomi Ollila
#	    All rights reserved
#
# Created: Wed 08 Apr 2020 22:04:22 EEST too
# Last modified: Wed 03 Aug 2022 18:04:01 +0300 too

# SPDX-License-Identifier: 0BSD

case ${BASH_VERSION-} in *.*) set -o posix; shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) emulate ksh; esac

set -euf  # hint: sh -x thisfile [args] to trace execution

# started this as buildah-.. but converted to podman-only solution so one
# doesn't need to install buildah(1) cli tool (also) just for this purpose

if test "${1-}" != '--in-container--' # --- this block is executed on host ---
then
	from_images="debian:* ubuntu:* fedora:*" # more to add...

	die () { printf '%s\n' '' "$@" ''; exit 1; } >&2
	x () { printf '+ %s\n' "$*" >&2; "$@"; }
	x_exec () { printf '+ %s\n' "$*" >&2; exec "$@"; }

	test $# = 0 && die "Usage: $0 ( make | run ) ..."
	if test "$1" = run
	then
		case $PWD in $HOME/*) ;; *)
			die "\$PWD '$PWD'" "not under \$HOME '$HOME/' ..."
		esac
		test $# -ge 2 || {
			# the following worked w/ podman old or new enough...
			#podman images --format '{{.ID}}  {{printf "%12.12s %8s" .CreatedSince .Size}}  {{$e:=""}}{{range $e = split .Repository "/"}}{{end}}{{$e}}:{{.Tag}}'
			il=$(podman images --format '{{.ID}}  {{printf "%12.12s %8s" .CreatedSince .Size}}  //{{.Repository}}:{{.Tag}}' '*notmuch-buildenv-*')
			test "$il" || die \
				"No notmuch buildenv container images created."\
			''	"Run $0 make ... to create one."
			echo
			# v tested that works w/ gawk & mawk v #
			awk -v il="$il" 'BEGIN { gsub("//[^/]*/", "", il); print il }'
			die  "Usage $0 $1 {container-image} [command [args]]" \
			''	'Use one of the container images listed above.'\
			''	'Note: $HOME/ is mounted in the started container...'
			exit not reached
		}
		case $2 in *notmuch-buildenv-*) ;; *)
			die "'$2': not a 'notmuch-buildenv' image"
		esac
		shift
		x_exec podman run --pull=never --rm -it --privileged \
			-v "$HOME:$HOME" -w "$PWD" "$@"
		exit not reached
	fi
	test "$1" = make || die "'$1': not 'run' nor 'make'"

	test $# = 3 || {
	    today=`date +%Y%m%d`
	    die "Usage: $0 $1 yyyymmdd from-image-name:tag" '' \
		"Enter '$today' as 'yyyymmdd'." '' \
		'Known "from" images '"(replace '*' with container image tag):"\
		'' "    $from_images" '' \
		"Creates: 'notmuch-buildenv-{from-image-name}-{tag}:yyyymmdd' container image." '' \
		'Note: all versions of the "from" images may not ne compatible.' \
		'(as of 2022-06 tested with debian:11.3 and fedora:36 as from-image)'
	}
	case $3 in ??*:?*) ;; *) die "'$3' not '{name}:{tag}'" ;; esac
	n3=${3%:*}
	for fimg in $from_images
	do	fimg=${fimg%:*}
		test "$fimg" = "$n3" || continue
		n3=
		break
	done
	test -z "$n3" || die "'$3': unknown \"from\" image"
	unset n2 fimg

	today=`date +%Y%m%d`

	test "$2" = $today || die "'$2' is not date of today ($today)"

	target_base=notmuch-buildenv-${3%:*}-${3##*:} # in one : we trust

	target_image=$target_base:$2
	if podman inspect -t image --format='{{.RepoTags}} {{.Created}}' \
		"$target_image" 2>/dev/null
	then
		echo; echo "Target image '$target_image' exists."; echo
		exit 0
	fi
	podman inspect -t image --format='{{.Size}}' "$3" || {
		printf '\n"From" image missing;'
		echo " podman pull the image ($3) before continuing."
		echo
		exit 1
	}
	#echo "'$0'"
	case $0 in /*/../*) dn0=`cd "${0%/*}" && pwd`
		;; /*)	dn0=${0%/*}
		;; */*/*) dn0=`cd "${0%/*}" && pwd`
		;; ./*)	dn0=$PWD
		;; */*)	dn0=`cd "${0%/*}" && pwd`
		;; *)	dn0=$PWD
	esac

	x podman run --pull=never -it --privileged -v "$dn0:/mnt:ro" \
		--tmpfs /tmp:rw,size=65536k,mode=1777 --hostname=buildhost \
		--name "$target_base-wip" "$3" \
		/bin/sh /mnt/"${0##*/}" --in-container-- "$3" ||
	die "Building '$target_image' failed..." '' Execute: \
	    "  podman start -ia $target_base-wip ;: or" \
	    "  podman logs $target_base-wip      ;: to investigate."

	echo 'Back in "host" environment...'

	#podman logs $target_base-wip > "$target_image".plog

	# remove some noise in container, at least older podmans did that...
	x podman unshare sh -eufxc '
		mp=`podman mount "'"$target_base-wip"'"`
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

# executed using /bin/sh -- which may be e.g. dash(1) #

die () { exit 1; }

set -x

test -f /run/.containerenv || die "No '/run/.containerenv' !?"

case $2 in ( debian:* | ubuntu:* )
	# libsexp-dev is in bullseye-backports...
	grep -q ' bullseye ' /etc/apt/sources.list &&
	echo deb http://deb.debian.org/debian bullseye-backports main \
		> /etc/apt/sources.list.d/backports.list
	export DEBIAN_FRONTEND=noninteractive
	apt-get update
	# note: no 'upgrade' -- pull new base image for that...
	# .travis.yml was helpful (but not complete)...
	apt-get install -y -q build-essential emacs-nox gdb git man \
		dtach libxapian-dev libgmime-3.0-dev libtalloc-dev \
		python3-sphinx python3-cffi python3-pytest \
		python3-setuptools libpython3-all-dev gpgsm ruby-dev
	apt-get install -y -q libsexp-dev || true

	apt-get -y autoremove
	apt-get -y clean
	rm -rf /var/lib/apt/lists/
	rm /.rerun
	exit
esac

case $2 in ( fedora:* | centos:* ) # alma/rocky linux instead of centos ?

	# note: centos in progress -- gmime, dtach, python3-sphinx not found...
	#case $2 in fedora:*) fedora=true ;; *) fedora=false ;; esac

	#$fedora || dnf -v -y install epel-release
	: Note: dnf commands below may be long-lasting and silent...
	#
	dnf -v -y install make gcc gcc-c++ emacs-nox gdb git man \
		dtach xapian-core-devel gmime30-devel libtalloc-devel \
		zlib-devel python3-sphinx gnupg2-smime xz openssl \
		redhat-rpm-config ruby-devel diffutils findutils \
		sfsexp-devel
		# python3-devel python3-cffi python3-pytest

	dnf -v -y autoremove # note: removed findutils in centos 7.0
	dnf -v -y clean all
	set +f
	rm -rf /var/cache/yum /var/cache/dnf /var/lib/yum/* /var/lib/dnf/*
	set -f
	#rm -rf /var/lib/rpm/__db*; rpm --rebuilddb
	test -x /usr/bin/gpg || ln -s gpg2 /usr/bin/gpg # in centos 8 not in 7?
	rm /.rerun
	exit
esac

die "'$2': unknown..."


# Local variables:
# mode: shell-script
# sh-basic-offset: 8
# tab-width: 8
# End:
# vi: set sw=8 ts=8
