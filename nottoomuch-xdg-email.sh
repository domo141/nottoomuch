#!/bin/sh

# wrap system xgd-email to run nottoomuch-emacs-mailto.pl for mailto: links
# for those (including me) who don't know (or want or cannot) how to configure
# xdg-email to run specific email program.

# these steps usually work:
#
# $ mkdir $HOME/bin
# $ cd $HOME/bin
# $ ln -s ../path/to/nottoomuch/nottoomuch-emacs-mailto.pl .
# $ ln -s ../path/to/nottoomuch/nottoomuch-xdg-email.sh xdg-email

# use MAILER=echo /usr/bin/xdg-email ... to test how system xdg-email works...

set -euf

MAILER=`command -v nottoomuch-emacs-mailto.pl`
#if test -h "$MAILER"
#then	MAILER=`exec readlink -f "$mailer"`
#fi
export MAILER


#saved_IFS=$IFS
IFS=: # this setting does not affect expansion of "$@" (vs "$*")

for d in $PATH
do	if test -x "$d"/xdg-email
	then
	    test "$0" -ef "$d"/xdg-email || exec "$d"/xdg-email "$@"
	fi
done

exec >&2
echo Cannot find xdg-email
exit 1
