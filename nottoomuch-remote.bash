#!/bin/bash
# -*- shell-script -*-
#
# Created: Tue 29 May 2012 21:30:17 EEST too
# Last modified: Sat 29 Oct 2016 15:43:48 +0300 too

# See first ./nottoomuch-remote.rst and then maybe:
# http://notmuchmail.org/remoteusage/
# http://notmuchmail.org/remoteusage/124/ <- this script

set -eu
# To trace execution, uncomment next line:
#exec 6>>remote-errors; BASH_XTRACEFD=6; echo -- >&6; set -x; env >&6

: ${REMOTE_NOTMUCH_SSHCTRL_SOCK:=master-notmuch@remote:22}
: ${REMOTE_NOTMUCH_COMMAND:=notmuch}

readonly REMOTE_NOTMUCH_SSHCTRL_SOCK REMOTE_NOTMUCH_COMMAND

SSH_CONTROL_ARGS='-oControlMaster=no -S ~'/.ssh/$REMOTE_NOTMUCH_SSHCTRL_SOCK
readonly SSH_CONTROL_ARGS

printf -v ARGS '%q ' "$@" # bash feature
readonly ARGS

if ssh -q $SSH_CONTROL_ARGS 0.1 "$REMOTE_NOTMUCH_COMMAND" $ARGS
then exit 0
else ev=$?
fi

# continuing here in case ssh exited with nonzero value

case $* in
 'config get user.primary_email') echo 'nobody@nowhere.invalid'; exit 0 ;;
 'config get user.name') echo 'nobody'; exit 0 ;;
 'count'*'--batch'*) while read line; do echo 1; done; exit 0 ;;
 'count'*) echo 1; exit 0 ;;
 'search-tags'*) echo 'errors'; exit 0 ;;
 'search'*'--output=tags'*) echo 'errors'; exit 0 ;;
esac

# fallback exit handler; print only to stderr...
exec >&2

if ssh $SSH_CONTROL_ARGS -O check 0.1
then
 echo " Control socket is alive but something exited with status $ev"
 exit $ev
fi

case $0 in */*) dn0=${0%/*} ;; *) dn0=. ;; esac
echo "See  $dn0/nottoomuch-remote.rst  for more information"

exit $ev
