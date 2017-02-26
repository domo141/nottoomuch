#!/bin/sh
# -*- mode: shell-script; sh-basic-offset: 8; tab-width: 8 -*-
# $ test-in-docker.sh $

set -u	# expanding unset variable makes non-interactive shell exit immediately
set -f	# disable pathname expansion by default -- makes e.g. eval more robust
set -e	# exit on error -- know potential false negatives and positives !
#et -x	# s/#/s/ may help debugging  (or run /bin/sh -x ... on command line)

LANG=C LC_ALL=C; export LANG LC_ALL
PATH='/sbin:/usr/sbin:/bin:/usr/bin'; export PATH

saved_IFS=$IFS; readonly saved_IFS

warn () { printf '%s\n' "$*"; } >&2
die () { printf '%s\n' "$@"; exit 1; } >&2

known_argvals="'7.11', '8.6', '14.04.5', '16.04', '25', 'unstable' or 'centos70'"

test $# != 0 || die '' "Usage: $0 {debian/ubuntu/fedora base version}" \
		    '' "version options:" \
		    "${known_argvals% or *} and ${known_argvals#* or }" ''

case $known_argvals
  in *"'$1'"*) ;; *) die "'$1' not any of these: $known_argvals".
esac

ver=$1

# the scheme below works fine with current set of "supported" distributions...
case $1 in [12]?.04*)	base=ubuntu debian=true
	;; [23]*)	base=fedora debian=false
	;; centos70)	base=centos debian=false; ver=7.0.1406
	;; *)		base=debian debian=true
esac

x () { printf '+ %s\n' "$*" >&2; "$@"; }
x_env () { printf '+ %s\n' "$*" >&2; env "$@"; }
x_eval () { printf '+ %s\n' "$*" >&2; eval "$*"; }
x_exec () { printf '+ %s\n' "$*" >&2; exec "$@"; die "exec '$*' failed"; }

image=notmuch-te-$base-$ver
if test "${2-}" = --in-container--
then
	set -x
	chmod 755 /root # make /root visible to the non-root user...
	### test -f /etc/bash.bashrc && bashrc=/etc/bash.bashrc || bashrc=/etc/bashrc
	sed 1,/^---begin-rc---/d "$0" > /etc/profile.d/setuser.sh
	if $debian
	then	export DEBIAN_FRONTEND=noninteractive
		test $1 = 7.11 && emacs=emacs23-nox || emacs=emacs-nox
		apt-get update
		apt-get install -y -q build-essential git \
			libxapian-dev libgmime-2.6-dev libtalloc-dev \
			zlib1g-dev python-sphinx man dtach $emacs gdb gpgsm
		apt-get -y autoremove
		apt-get -y clean
		rm -rf /var/lib/apt/lists/
	else
		test $base = centos && {
			dnf=yum
			yum -v -y install epel-release findutils tar openssl
		} || dnf=dnf
		: Note: dnf commands below may be long-lasting and silent...
		$dnf -v -y install make gcc gcc-c++ redhat-rpm-config git \
			xapian-core-devel gmime-devel libtalloc-devel \
			zlib-devel python2-sphinx man dtach emacs-nox gdb \
			gnupg2-smime
		#$dnf -v -y autoremove # removes findutils in centos 7.0
		$dnf -v -y clean all

	fi
	command -v dtach >/dev/null || { # centos7 does not have as of 2017-02
		tgz=dtach-0.9.tar.gz
		dir=dtach-0.9
		url=https://downloads.sourceforge.net/project/dtach/dtach/0.9/$tgz
		if command -v wget >/dev/null
		then wget --no-check-certificate $url
		elif command -v curl >/dev/null
		then curl --insecure -L -O $url
		else echo Cannot download $url: no wget nor curl available
		     exit 1
		fi
		sha256sum=`exec sha256sum $tgz`
		case $sha256sum in 32e9fd6923c553c443fab4ec9c1f95d83fa47b771e*)
				;; *)
					echo $tgz checksum mismatch
					exit 1
		esac
		tar zxvf $tgz
		cd $dir
		./configure
		make
		mv dtach /usr/local/bin
		cd ..
		rm -rf $dir $tgz
	}
	exit
fi

echo Using docker image $image

test "${SUDO_USER-}" && { sudo=sudo user=$SUDO_USER; } || { sudo= user=$USER; }

x docker inspect --type=image --format='{{.ID}}' $image || {
	# create missing container image
	from=$base:$ver
	x docker inspect --type=image --format='{{.ID}}' $from ||
		x docker pull $from
	x docker create -w /root/.docker-setup \
		--name wip-$image $from ./"${0##*/}" $1 --in-container-- ||
		die ": execute; $sudo docker rm wip-$image ;: and try again"
	x docker cp "$0" wip-$image:/root/.docker-setup/${0##*/}
	echo Creating docker image $image...
	x docker start -i wip-$image
	x docker commit -c "CMD [ \"/bin/echo\", \"start this using '$0'\" ]" \
	  wip-$image $image
	x docker rm wip-$image
}

name=$image-$user

if status=`exec docker inspect -f '{{.State.Status}}' $name 2>&1`
then
	if test "$status" = running
	then x_exec docker exec -it "$name" /bin/bash --login
	else x_exec docker start -i "$name"
	fi
fi
#run ()
#{
	test -d /tmp/.X11-unix &&
		xv='-v /tmp/.X11-unix:/tmp/.X11-unix:ro' || xv=

	# privileged needed on fedora host for mounts to work
	sopts='--privileged --ipc=host'

	IFS=:; set -- `exec getent passwd "$user"`
	home=$6
	IFS=' '
	x_exec docker run -it -e DISPLAY -e user="$user" -e home="$home" \
		--name "$name" -h "$name" -v "$home:$home" \
		$xv $sopts "$image" /bin/bash --login
#}
#case $status in *parsing*error*.State.Status*) run; esac

die error

exit
---begin-rc---

if test "${UID}" = 0; then
  if test "${user-}" && test -d "${home:-/kun/ei/ole}"
  then
	case $user in *[!-a-z0-9_]*) exit 1; esac
	grep -q "^$user:" /etc/passwd || {
		duid=`exec stat -c %u "$home"`
		useradd -d "$home" -M -u $duid -U -G 0 -s /bin/bash \
			-c "user $user" "$user" 2>/dev/null || :
	}
	echo If root access is desired, docker exec -it non-login shell...
	# Simple change user which may work as well as gosu(1) if not (better).
	exec perl -e '
		my @user = getpwnam $ARGV[0];
		chdir $user[7];
		$ENV{HOME} = $user[7];
		$ENV{USER} = $ARGV[0];
		delete $ENV{user};
		$( = $) = "$user[3] $user[3] 0";
		$< = $> = $user[2]; die "setting uids: $!\n" if $!;
		exec qw"/bin/bash --login";' "$user"
  fi
  echo login shell only for users...
  exit 1
fi
case ${BASH_VERSION-} in *.*)
	# emulate zsh printexitvalue
	trap 'echo -n bash: exit $? \ \ ; fc -nl -1 -1' ERR
esac
