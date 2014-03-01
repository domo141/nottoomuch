#!/bin/bash
# -*- mode: shell-script; sh-basic-offset: 8; tab-width: 8 -*-
#
# Created: Tue 29 May 2012 21:30:17 EEST too
# Last modified: Fri 28 Feb 2014 22:15:26 +0200 too

# See first ./nottoomuch-remote.rst and then maybe:
# http://notmuchmail.org/remoteusage/
# http://notmuchmail.org/remoteusage/124/ <- this script

set -eu
# To trace execution, uncomment next line.
#BASH_XTRACEFD=6; exec 6>>remote-errors; echo -- >&6; set -x

readonly SSH_CONTROL_SOCK='~'/.ssh/master-notmuch@remote:22
#readonly SSH_CONTROL_SOCK='~'/.ssh/symlink-to-notmuch-remote-ctrl-sock

readonly notmuch=notmuch

printf -v ARGS '%q ' "$@" # bash feature

readonly SSH_CONTROL_ARGS='-oControlMaster=no -S '$SSH_CONTROL_SOCK

if ssh -q $SSH_CONTROL_ARGS 0.1 $notmuch $ARGS
then exit 0
else ev=$?
fi

# continuing here in case ssh exited with nonzero value.

case $* in
 'config get user.primary_email') echo 'nobody@nowhere.invalid'; exit 0 ;;
 'config get user.name') echo 'nobody'; exit 0 ;;
 'count'*'--batch'*) while read line; do echo 1; done; exit 0 ;;
 'count'*) echo 1; exit 0 ;;
 'search-tags'*) echo 'errors'; exit 0 ;;
 'search'*'--output=tags'*) echo 'errors'; exit 0 ;;
esac

# for unhandled command line print only to stderr...
exec >&2

if ssh $SSH_CONTROL_ARGS -O check 0.1
then
 echo ' Control socket is alive but something failed during data transmission'
 exit $ev
fi

case $0 in */*) dn0=${0%/*} ;; *) dn0=. ;; esac
echo "See  $dn0/nottoomuch-remote.rst  for more information"
#EOF
