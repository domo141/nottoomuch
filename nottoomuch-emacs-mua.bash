#!/usr/bin/env bash
# -*- mode: shell-script; sh-basic-offset: 8; tab-width: 8 -*-

# Created: Fri 11 Jul 2014 00:12:59 EEST too
# Last Modified: Sat 03 Oct 2015 15:53:51 +0300 too

set -eu

# this script uses some bash features. therefore attempt to ensure it is
case ${BASH_VERSION-} in '') echo 'Not BASH!' >&2; exit 1; esac

if test $# = 0
then
	bn=${0##*/}
	exec sed -e '1,/^exit/d' -e "s/\$0/$bn/" "$0"
	exit not reached
fi

# escape: "expand" '\' as '\\' and '"' as '\"'
# calling convention: escape -v var "$arg" (like in bash printf).
# printf -v var and ${var//...} are bash features (the only one used...)
escape ()
{
	local __escape_arg__=${3//\\/\\\\}
	printf -v $2 '%s' "${__escape_arg__//\"/\\\"}"
}

append_body_text ()
{
	bodycode=$bodycode$nl"  (insert \"$body\n\")"
	body=
}
insert_body_file ()
{
	[ -f "$1" ] || { echo "$0: '$1': no such file" >&2; exit 1; }
	test "$body" = '' || append_body_text
	escape -v arg "$1"
	## XXX yhdistä ?
	bodycode=$bodycode$nl"  (forward-char (cadr (insert-file-contents \"${arg}\" nil 0 1048576)))"
	bodycode=$bodycode$nl"  (unless (bolp) (insert \"\\n\"))"
}


# note: dollar-single i.e. $'...' is bash (ksh, zsh, mksh) but not dash feature
#nl=$'\n'
nl='
'
exec=exec nw= sep=' '
from= to= subject= cc= bcc= body= bodycode=
var=to
while test $# -gt 0	# note $# does not need quoting
do
	arg=$1; shift
	case $arg
	in -n | --n )
		[ "$arg" = "${1-}" ] && shift || {
		print_instead () { printf '\n%s\n' "$*"; }
		exec=print_instead
		continue
	}
	;; -nw | --nw )
		[ "$arg" = "${1-}" ] && shift || {
		nw=-nw
		continue
	}
	;; -from | --from | [Ff]rom:)
		[ "$arg" = "${1-}" ] && shift || {
		message_goto='(messge-goto-from)'
		[ $# != 0 ] || continue
		from=$1; shift
		continue
	}
	;; -to | -cc | -bcc | --to | --cc | --bcc | [Tt]o: | [Cc]c: | [Bb]cc: )
		[ "$arg" = "${1-}" ] && shift || {
		var=${arg#-}; var=${var#-}; var=${var%:}
		eval "message_goto='(message-goto-$var)'"
		[ $# != 0 ] || continue
		arg=$1; eval "sep=\"\${$var:+, }\""; shift
	}
	;; -subject | --subject | [Ss]ubject: )
		[ "$arg" = "${1-}" ] && shift || {
		var=subject
		eval "message_goto='(message-goto-$var)'"
		[ $# != 0 ] || continue
		var=subject arg=$1; eval "sep=\"\${$var:+ }\""; shift
	}
	;; -file | --file )
		[ "$arg" = "${1-}" ] && shift || {
		message_goto=
		[ $# != 0 ] || continue
		insert_body_file "$1"; shift
		continue;
	}
	;; -text | --text )
		[ "$arg" = "${1-}" ] && shift || {
		message_goto=
		[ $# != 0 ] || continue
		var=body arg=$1; eval "sep=\"\${$var:+ }\""; shift
	}
	;; -body | --body )
		[ "$arg" = "${1-}" ] && shift || {
		exec >&2
		echo
		echo "'$arg' is not supported; use -file or -text instead"
		echo
		exit 1
	}
	esac
	escape -v arg "$arg"
	eval "$var=\${$var:+\$$var$sep}\$arg"
	sep=' '
done

[ "$body" = '' ] || append_body_text

elisp="\
${cc:+$nl  (message-goto-cc) (insert \"$cc\")}\
${bcc:+$nl  (message-goto-bcc) (insert \"$bcc\")}\
${bodycode:+$nl  (message-goto-body)$bodycode}"

escape -v _pwd "$PWD"

exec_mua () { $exec ${EMACS:-emacs} $nw --eval "$@"; }

elisp_start="prog1 'done (require 'notmuch)"

if [ "$to" = '' -o "$to" = . ] && [ "$subject" = '' ] && [ "$elisp" = '' ]
then
	exec_mua "($elisp_start (notmuch-hello) (cd \"$_pwd\"))"
else
	[ "$from" != '' ] && oh="(list (cons 'From \"$from\"))" || oh='  nil'

	if [ "$subject" == '' ]
	then	subject=nil
		message_goto=' (message-goto-subject)'
	else
		subject=\"$subject\"
	fi
	if [ "$to" == '' ]
	then	to=nil
		message_goto=' (message-goto-to)'
	else
		to=\"$to\"
	fi
	exec_mua "(${elisp_start}
;;(setq message-exit-actions (list #'save-buffers-kill-terminal))
  (notmuch-mua-mail ${to} ${subject}
     ${oh} nil (notmuch-mua-get-switch-function))
  (cd \"$_pwd\")\
${elisp}${nl}  (set-buffer-modified-p nil)${message_goto})"
fi
exit

Execute `$0 .` to run just notmuch-hello

Otherwise enter content on command line: initial active option is '-to'

The list of options are:
    -nw (no window)  -n (dry run)
    -to  -subject  -cc  -bcc  -text  -file  -from

In all options -- -prefixed alternatives are also recognized.
In to:, subject:, cc:, bcc:, and from: this format is also accepted.

Duplicating option (e.g. -to -to) will "escape" it -- produce just
one of it as content of the currently active option.

If option is last argument on command line it just sets final
cursor position (provided that -to and -subject are set).

Currently --opt=val is not supported, because it is SMOP. Maybe later...

Example:
    $0 user@example.org -subject give me some -cc -cc
.
