#!/bin/sh
:; export REMOTE_NOTMUCH_SSHCTRL_SOCK=${1##*/}; shift
:; exec "${EMACS:-emacs}" --debug-init --load "$0" "$@"; exit

;; wrapper to set up remote notmuch for emacs; used with nottoomuch-remote.bash

;; setting REMOTE_NOTMUCH_SSHCTRL_SOCK from command line has been put
;; into the shell script part so that it does not stay in ps output

;; alternatively, this file can be copied as new one, and embed the socket
;; path in. in that case it is also convenient to add more eval-after-load
;; settings (e.g. mail send configurations)

;; (setenv "REMOTE_NOTMUCH_SSHCTRL_SOCK" "master-notmuch@remote:22")

(setq sshctrl-sock (getenv "REMOTE_NOTMUCH_SSHCTRL_SOCK"))

(when (string-equal sshctrl-sock "")
  (insert "\nUsage: " (file-name-nondirectory load-file-name) " {ctl_name} "
          "[other emacs options]\n"
          "\n{cl_name} is ssh control socket located in ~/.ssh/...")
  (error "missing argument"))

(setq ctl_path (concat (expand-file-name "~/.ssh/") sshctrl-sock))

(unless (file-exists-p ctl_path)
  (insert "\nSocket '" ctl_path "' does not exist!")
  (error "missing file"))

;; XXX common cases -- don't know how to check for socket
(when (or (file-regular-p ctl_path) (file-directory-p ctl_path))
  (insert "\nFile '" ctl_path "' is not socket!")
  (error "file not socket"))

(eval-after-load "notmuch"
  (lambda ()
    (setq notmuch-command (concat (file-name-directory load-file-name)
                                  "nottoomuch-remote.bash"))
    ;; add more in your own copy, if desired
    ))

(load "notmuch")

(insert "
To start notmuch (hello) screen, evaluate
(notmuch-hello)  <- type C-x C-e or C-j between \")\" and \"<-\"")

;; Local Variables:
;; mode: emacs-lisp
;; End:
