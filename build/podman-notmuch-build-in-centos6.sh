#!/bin/sh
#
# Author: Tomi Ollila -- too ät iki piste fi
#
#       Copyright (c) 2019 Tomi Ollila
#           All rights reserved
#
# Created: Sun 20 Oct 2019 20:41:59 +0300 too
# Last modified: Thu 20 May 2021 23:41:05 +0300 too

# Note: writes material under $HOME. grep HOME {thisfile} to see details...

# SPDX-License-Identifier: BSD-2-Clause

case ${BASH_VERSION-} in *.*) set -o posix; shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) emulate ksh; esac

set -euf  # hint: sh -x thisfile [args] to trace execution

die () {
	{ case "$-" in *x*) ;; *) printf '%s\n' "$@"
	  esac; } 2>/dev/null
	exit 1;
} >&2

x () { printf '+ %s\n' "$*" >&2; "$@"; }

test $# -ge 3 || {
	exec >&2; echo
	echo "Usage: $0 yyyymmdd notmuch-srcdir [0] [1]..."
	echo
	echo '  yyyymmdd: TAG of notmuch-buildenv-centos6 container image'
	echo
	podman images notmuch-buildenv-centos6
	echo
	grep ' [0-9] '\' "$0"
	echo
	exit 1
}

tag=$1; shift

ciname=notmuch-buildenv-centos6:$tag
coname=notmuch-buildenv-centos6-$tag

if test "${1-}" != '--in-container--'
then
	podman inspect "$ciname" --format '{{.RepoTags}}'

	test -f "$1/configure" && test -f "$1/lib/notmuch-private.h" ||
		die "'$1' does not look like notmuch source dir"

	nmsrc=$1; shift

	case $0 in /*)	dn0=${0%/*}
		;; */*/*) dn0=`cd "${0%/*}" && pwd`
		;; ./*)	dn0=$PWD
		;; */*)	dn0=`cd "${0%/*}" && pwd`
		;; *)	dn0=$PWD
	esac

	# used initially, but stated "non-essential", so...
	#test "${XDG_CACHE_HOME-}" &&
	#	cache_dir=$XDG_CACHE_HOME || cache_dir=$HOME/.cache
	#case $cache_dir in $HOME*) ;; *)
	#	die "'$cache_dir' not in '$HOME'..."
	#esac
	Z=`exec date +%Z`
	x podman run --pull=never --rm -it --privileged -v "$dn0:/media" \
		--tmpfs /tmp:rw,size=65536k,mode=1777 \
		-v "$HOME:$HOME" -v "$nmsrc:/mnt" \
		--name "$coname" "$ciname" \
		/media/"${0##*/}" "$tag" --in-container-- \
			"$HOME" "$Z" '' "$@" ''
	echo 'back in "host" environment...'
	echo
	echo all done
	echo
	exit 0
fi

### rest of the file executed in container ###

echo --
echo -- Executing in container -- xtrace now on -- >&2
echo --

set -x

test -f /run/.containerenv || die "No '/run/.containerenv' !?"

HOME=$2; Z=$3; shift 3
echo $HOME - $Z
# note: HOME not exported..

TAR_OPTIONS='--no-same-owner' # hint: podman unshare ... if this does not do it
export TAR_OPTIONS

dn0=${0%/*}

ls -l /mnt /media

# zlib on centos6 is too old (1.2.3)
zlib_lnk=http://prdownloads.sourceforge.net/libpng/zlib-1.2.11.tar.gz
zlib_cks=c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1

xapian_lnk=https://oligarchy.co.uk/xapian/1.4.14/xapian-core-1.4.14.tar.xz
xapian_cks=975a7ac018c9d34a15cc94a3ecc883204403469f748907e5c4c64d0aec2e4949

pcre_lnk=https://ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz
pcre_cks=0b8e7465dc5e98c757cc3650a20a7843ee4c3edf50aaf60bb33fd879690d2c73

# 2.57.1 works w/o meson/ninja (and has ./configure) but requires libmount
#glib_lnk=http://ftp.gnome.org/pub/gnome/sources/glib/2.57/glib-2.57.1.tar.xz
#glib_cks=d029e7c4536835f1f103472f7510332c28d58b9b7d6cd0e9f45c2653e670d9b4

glib_lnk=http://ftp.gnome.org/pub/gnome/sources/glib/2.49/glib-2.49.4.tar.xz
glib_cks=9e914f9d7ebb88f99f234a7633368a7c1133ea21b5cac9db2a33bc25f7a0e0d1

gmime_lnk=https://download.gnome.org/sources/gmime/3.2/gmime-3.2.5.tar.xz
gmime_cks=fb7556501f85c3bf3e65fdd82697cbc4fa4b55dccd33ad14239ce0197e78ba59


dl_dir=$HOME/.local/share/nottoomuch-c6/dl

: 0 :
case $* in *' 0 '*) ## download missing source archives
	test -d "$dl_dir" || mkdir -p "$dl_dir"
	may_dl () {
		test -f "$dl_dir"/${1##*/} || {
			curl -Lo "$dl_dir"/${1##*/}.wip $1${2-}
			mv "$dl_dir"/${1##*/}.wip "$dl_dir"/${1##*/}
		}
	}
	may_dl $zlib_lnk '?download'
	may_dl $xapian_lnk
	may_dl $pcre_lnk
	may_dl $glib_lnk
	may_dl $gmime_lnk
esac

ipa=$HOME/.local/share/nottoomuch-c6/a
ips=$HOME/.local/share/nottoomuch-c6/src
test -d "$ipa" || mkdir -p "$ipa"
test -d "$ips" || mkdir -p "$ips"


: 1 :
nob=t
case $* in *' 1 '*) ## build needed libs
	chk_sha256 () {
		set -- "$1" "$2" `exec openssl sha256 < "$1"`
		test "$2" = "$4" || die "sha256 of '$1' is not expected" \
			"expected: $2" "actual: $4"
	}
	nob=
esac

lnk_to_file () {
	eval set -- \$1 \$$1''_lnk
	a=${2##*/}
	test -f "$dl_dir"/$a
	eval $1_file="$dl_dir"/$a
	case $a in *.tar.gz) a=${a%.tar.gz}
		;; *.tar.xz) a=${a%.tar.xz}
	esac
	eval $1_ver=\${a##*-}
}

lnk_to_file zlib

test "$nob" || test -d $ipa/zlib-$zlib_ver || (
	# false
	chk_sha256 "$zlib_file" $zlib_cks
	rm -rf $ips/zlib-$zlib_ver
	tar -C $ips -zxvf "$zlib_file"
	cd $ips/zlib-$zlib_ver
	./configure --prefix=$ipa/zlib-$zlib_ver
	make install
)
#export CPPFLAGS="-I$ipa/zlib-$zlib_ver/include"
#export LDFLAGS="-L$ipa/zlib-$zlib_ver/lib"
export CPATH=$ipa/zlib-$zlib_ver/include
export LIBRARY_PATH=$ipa/zlib-$zlib_ver/lib

export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$ipa/zlib-$zlib_ver/lib/pkgconfig

lnk_to_file xapian

test "$nob" || test -d $ipa/xapian-core-$xapian_ver || (
	# false
	chk_sha256 "$xapian_file" $xapian_cks
	rm -rf $ips/xapian-core-$xapian_ver
	tar -C $ips -Jxvf "$xapian_file"
	cd $ips/xapian-core-$xapian_ver
	./configure --prefix=$ipa/xapian-core-$xapian_ver
	make install
)
# environment settings for xapian not needed yet

lnk_to_file pcre

test "$nob" || test -d $ipa/pcre-$pcre_ver || (
	# false
	chk_sha256 "$pcre_file" $pcre_cks
	rm -rf $ips/pcre-$pcre_ver
	tar -C $ips -zxvf "$pcre_file"
	cd $ips/pcre-$pcre_ver
	./configure --prefix=$ipa/pcre-$pcre_ver \
		--enable-utf --enable-unicode-properties
	make install
)
#export CPPFLAGS="$CPPFLAGS -I$ipa/pcre-$pcre_ver/include"
#export CPATH=$CPATH:$ipa/pcre-$pcre_ver/include
#export LDFLAGS="$LDFLAGS -L$ipa/pcre-$pcre_ver/lib"
#export LIBRARY_PATH=$LIBRARY_PATH:$ipa/pcre-$pcre_ver/lib

export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$ipa/pcre-$pcre_ver/lib/pkgconfig
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ipa/pcre-$pcre_ver/lib

lnk_to_file glib

test "$nob" || test -d $ipa/glib-$glib_ver || (
	# false
	chk_sha256 "$glib_file" $glib_cks
	rm -rf $ips/glib-$glib_ver
	tar -C $ips -Jxvf "$glib_file"
	cd $ips/glib-$glib_ver
	./configure --prefix=$ipa/glib-$glib_ver
	make install
)
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$ipa/glib-$glib_ver/lib/pkgconfig
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ipa/glib-$glib_ver/lib

lnk_to_file gmime

test "$nob" || test -d $ipa/gmime-$gmime_ver || (
	# false
	chk_sha256 "$gmime_file" $gmime_cks
	rm -rf $ips/gmime-$gmime_ver
	tar -C $ips -Jxvf "$gmime_file"
	cd $ips/gmime-$gmime_ver
	./configure --prefix=$ipa/gmime-$gmime_ver
	make install
)
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$ipa/gmime-$gmime_ver/lib/pkgconfig
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ipa/gmime-$gmime_ver/lib

test "$nob" || (
	cd $ipa
	# zero timestamps in ar(5) files. build reproducible if same --prefix
	find . -name '*.a' | xargs $dn0/ardet.pl  # from ldpreload-ardet repo
)

# xapian not needed until now...
#export CPPFLAGS="$CPPFLAGS -I$ipa/xapian-core-$xapian_ver/include"
#export CPATH=$CPATH:$ipa/xapian-core-$xapian_ver/include
#export LDFLAGS="$LDFLAGS -L$ipa/xapian-core-$xapian_ver/lib"
#export LIBRARY_PATH=$LIBRARY_PATH:$ipa/xapian-core-$xapian_ver/lib

export PATH=$PATH:$ipa/xapian-core-$xapian_ver/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ipa/xapian-core-$xapian_ver/lib

# this ld library path setting was not needed until now
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ipa/zlib-$zlib_ver/lib

: 2 :
case $* in *' 2 '*) ## patch notmuch (optional) (modifies notmuch-srcdir)
	cd /mnt
	gl5=`exec git --no-pager log -5 --oneline` # enough, due to rebases...
	case $gl5 in *'hax: notmuch binary with embedded manpages'*) ;; *)
		git am "$dn0"/02-hack-notmuch-with-embedded-manpages.patch
	esac
	#git am "$dn0"/01-date-local.patch # see: make-one-notmuch-el.pl
esac


: 3 :
case $* in *' 3 '*) ## build notmuch (in-tree) (remember '7' -- rpath)
	cd /mnt
	sed '/command .* gpgme-config/,/^else/ s/errors=/#errors=/' configure \
		> hax-centos6-configure
	sh ./hax-centos6-configure
	#export CFLAGS="${CFLAGS:+$CFLAGS } -v"
	make #V=1
	#make test
esac


: 5 :
case $* in *' 5 '*) ## try notmuch
	cd /mnt
	ldd notmuch
	ldd notmuch-shared
	ldd lib/libnotmuch.so.5
	:; : try ./notmuch --help on shell prompt below... ;:
	/bin/bash #/bin/zsh
esac

: 6 :
case $* in *' 6 '*) ## package libs for dist: set rpaths...
	cd /mnt
	od=`TZ=$Z exec date +nmc6-deplibs-%Y%m%d-%H%M`
	mkdir $od
	dlibs=`ldd notmuch | sed -n '/nottoomuch-c6\/a/ s/=.*//p'`
	set +f
	for f in $dlibs; do cp -L $ipa/*/lib/$f $od/.; done
	cd $od
	# set RPATH/RUNPATH, some may not need buit...
	for f in *.so*
	do	ldd $f | grep -q nottoomuch-c6/a || continue
		test "`patchelf --print-rpath $f`" || continue
		patchelf --set-rpath '$ORIGIN' $f
	done
	set -f
	cd ..
	tar zcvf $od.tar.gz $od
esac

: 7 :
case $* in *' 7 '*) ## set rpath to notmuch(1) (not notmuch-shared (for now))
	cd /mnt
	patchelf --set-rpath '$ORIGIN/../lib' notmuch
esac

: 8 :
case $* in *' 8wip '*) ## build and package emacs (tested emacs 27.1)
	cd /mnt/emacs-[1-9]*[0.9]
	./configure --prefix=$HOME/.local
	make
	make install DESTDIR=$PWD/tmp-dd
	( cd tmp-dd/$HOME/.local &&
	  exec rm -rf include lib share/applications share/icons share/metainfo
	)
	ver=`cd tmp-dd/$HOME/.local/share/emacs; echo [1-9]*`
	tar -C tmp-dd/$HOME -zcf emacs-$ver-centos6.tar.gz .local
esac

:
: all done in container
:


# Local variables:
# mode: shell-script
# sh-basic-offset: 8
# tab-width: 8
# End:
# vi: set sw=8 ts=8
