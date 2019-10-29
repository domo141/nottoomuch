#!/bin/sh

set -euf

# tput: unknown terminal "rxvt-unicode"
term=$TERM
export TERM=xterm

die () { printf '%s\n' "$@"; exit 1; } >&2
x () { printf '+ %s\n' "$*" >&2; "$@"; }
x_eval () { printf '+ %s\n' "$*" >&2; eval "$*"; }

test "`exec uname -s`" = Darwin || die "uname -s: '`uname -s`' not 'Darwin'"

BREWLOC=$HOME/.local/share/brew
case ${BREWLOC} in *["$IFS"]*) die whitespace ;; */) die 'trailing /' ;; esac

case $PATH in *$BREWLOC/*)
	echo '' $BREWLOC/ already in
	echo '' $PATH
	ps -xfp ${PPID:+$PPID,}$$
	echo '' continuing to use current shell environment "($SHELL $$)"
	exit
esac

test -d ${BREWLOC} || die '' "Directory '${BREWLOC}' nonexistent." '' \
	'This system installs (home)brew in abovementioned location.' \
	'If you want to use "standard" location just install the few brew' \
	"packages listed by ; grep install_if_missing '$0'" \
	": else execute ; mkdir -p ${BREWLOC} ;: to continue" ''

missing=''
for cmd in gcc g++
do
	command -v $cmd >/dev/null || missing=${missing:+$missing }$cmd
done
test -z "$missing" || die "Required commands missing: $missing (XCode?)"
unset missing cmd

test -x ${BREWLOC}/bin/brew || {
#	x mkdir -p ${BREWLOC%/*} # parent dir
#	x mkdir ${BREWLOC} ;: if this fails, stop '(or rm -rf and retry)'

	x curl -L https://github.com/Homebrew/brew/tarball/master \
		| x bsdtar -C ${BREWLOC} --strip-components 1 -xvf -
}

#mkdir -p $HOME/bin
# XXX not with brewloc as currently in below
#ln -s ../.local/share/brew/bin/brew $HOME/bin

install_if_missing ()
{
	test -d ${BREWLOC}/Cellar/$1 || x ${BREWLOC}/bin/brew install $1
}

# cli & lib
install_if_missing xapian
install_if_missing gmime
install_if_missing talloc

# emacs
install_if_missing emacs

## doc
# #install_if_missing xxx-sphinx-xxx ## xxx needs pip to install

# bash 4.x for testing
install_if_missing bash

# dtach(1) for testing
install_if_missing dtach

# gdb(1) & gpgsm for testing
install_if_missing gdb
install_if_missing gpgme


# note: with 'export', 'x' works. without it would not work (x_eval would then)
case $PATH in */brew/bin/*) ;;
	*) x export 'PATH'="$HOME/.local/share/brew/bin:$PATH"
esac
case ${CPATH-} in */brew/include/*) ;;
	*) x export 'CPATH'="$HOME/.local/share/brew/include${CPATH:+:$CPATH}"
esac
LB=${LIBRARY_PATH-}
case $LB in */brew/lib/*) ;;
	*) x export 'LIBRARY_PATH'="$HOME/.local/share/brew/lib${LB:+:$LB}"
esac
## XXX does not wrok
#LB=${DYLD_LIBRARY_PATH-}
#case $LB in */brew/lib/*) ;;
# *) x export 'DYLD_LIBRARY_PATH'="$HOME/.local/share/brew/lib${LB:+:$LB}"
#esac

echo
echo Starting interactive shell with modified environment.
echo
echo DYLD_* variables no longer work in macOS '(sierra, el capitan)'.
echo : Use ./configure --prefix=\$PWD ';:' before testing
echo : also for testing: python wrapper which symlinks libnotmuch.4.dylib to cwd
echo : and ./configure --prefix=$HOME/.local/share/brew ';:' before installing.
echo : '(and 4 testing CDLL("../../libnotmuch.{0:s}.dylib".format(SOVERSION)))'
echo : also use ... install_name_tool or whatnot ... check these 2 lines out...
echo
export 'TERM'="$TERM"
x exec ${SHELL} -i
