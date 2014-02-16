#!/bin/sh
# -*- mode: shell-script; sh-basic-offset: 8; tab-width: 8 -*-
# $ startfetchmail.sh $
#
# Created: Wed 06 Mar 2013 17:17:58 EET too
# Last modified: Sun 16 Feb 2014 22:35:31 +0200 too

# Fetchmail does not offer an option to daemonize it after first authentication
# is successful (and report if it failed). After 2 fragile attempts to capture
# the password in one-shot fetch (using tty play) and if that successful
# run fetchmail in daemon mode I've settled to run this script and just check
# from log whether authentication succeeded...

set -eu
#set -x

case ${1-} in -I) idle=; shift ;; *) idle=idle
esac

case $# in 5) ;; *) exec >&2
	echo
	echo Usage: $0 [-I] '(143|993) (keep|nokeep)' user server mda_cmdline
	echo
	echo This script runs fetchmail with options to use encrypted IMAP
	echo connection when fetching email. STARTTLS is required when using
	echo port 143. IMAP IDLE feature used when applicable...
	echo
	echo ... except -I option can be used to inhibit IDLE usage, in cases
	echo where mail delivery is delayed or does not happen with IDLE.
	echo
	echo fetchmail is run in background '(daemon mode)' and first few
	echo seconds of new fetchmail log is printed to terminal so that user
	echo can determine whether authentication succeeded.
	echo
	echo Examples:
	echo
	echo ' ' $0 993 keep $USER mailhost.example.org \\
        echo "          '/usr/bin/procmail -d %T'"
	echo
	echo '    Deliver mail from imap[s] server to user mbox in spool'
	echo '    directory (usually /var[/spool]/mail/$USER, or $MAIL).'
	echo '    Mails are not removed from imap server.'
	echo
	echo ' ' $0 143 nokeep $USER mailhost.example.org \\
        echo "          ~'/nottoomuch/md5mda.sh --cd mail received wip log'"
	echo
	echo '    Deliver mail from imap server (STARTTLS required) to'
	echo '    separate mails in ~/mail/received/??/ directories.'
	echo '    Mails are removed from imap server.'
	echo
	exit 1
esac

case $1 in 143) ssl='sslproto TLS1' ;; 993) ssl=ssl ;; *) exec >&2
	echo
	echo "$0: '$1' is not either '143' or '993'".
	exit 1
	echo
esac

case $2 in keep) keep=keep ;; nokeep) keep= ;; *) exec >&2
	echo
	echo "$0: '$2' is not either 'keep' or 'nokeep'".
	echo
	exit 1
esac
shift 2

imap_user=$1 imap_server=$2 mda_cmdline=$3
shift 3
readonly ssl keep imap_server imap_user mda_cmdline

cd "$HOME"

mda_cmd=`expr "$mda_cmdline" : ' *\([^ ]*\)'`
test -s $mda_cmd || {
	exec >&2
	case $mda_cmd in
	  /*)	echo "Cannot find command '$mda_cmd'" ;;
	  *)	echo "Cannot find command '$HOME/$mda_cmd'"
	esac
	exit 1
}

if test -f .fetchmail.pid
then
	read pid < .fetchmail.pid
	if kill -0 "$pid" 2>/dev/null
	then
		echo "There is (fetchmail) process running in pid $pid"
		ps -p "$pid"
		echo "If this is not fetchmail, remove the file"
		exit 1
	fi
fi

logfile=.fetchmail.log
if test -f $logfile
then
	echo "Rotating logfile '$logfile'"
	mv "$logfile".2 "$logfile".3 2>/dev/null || :
	mv "$logfile".1 "$logfile".2 2>/dev/null || :
	mv "$logfile"   "$logfile".1
fi
touch $logfile

tail -f $logfile &
logfilepid=$!

trap 'rm -f fmconf; kill $logfilepid' 0

echo "
set daemon 120
set logfile '$logfile'

poll '$imap_server' proto IMAP user '$imap_user' $ssl $keep $idle
  mda '$mda_cmdline'
" > fmconf
chmod 700 fmconf

( set -x; exec fetchmail -f fmconf -v )

#x fetchmail -f /dev/null -k -v -p IMAP --ssl --idle -d 120 --logfile $logfile\
#	-u USER --mda '/usr/bin/procmail -d %T' SERVER

sleep 2
test -s $logfile || sleep 2
ol=0
for i in 1 2 3 4 5 6 7 8 9 0
do
	nl=`exec stat -c %s $logfile 2>/dev/null` || break
	test $nl != $ol || break
	ol=$nl
	sleep 1
done
rm -f fmconf
trap '' 15 # TERM may not be supported in all shells...
exec 2>/dev/null # be quiet from no on...
kill $logfilepid
trap - 0 15
echo
ps x | grep '\<fetch[m]ail\>'
echo
echo "Above the end of current fetchmail log '$HOME/$logfile'"
echo "is shown. Check there that your startup was successful."
echo
