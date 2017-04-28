#!/bin/sh

:; exec "${EMACS:-emacs}" --debug-init --load "$0" "$@"; exit

;; wrapper to set up notmuch emacs MUA, configured emacs smtpmail
;; to send email via gmail

;; you may need https://myaccount.google.com/lesssecureapps
;; (working alternative not requiring the above would be nice)

;; when emacs suggest to save authinfo, press 'e' to edit and remove
;; password. alternatively, if you know how, save authinfo.gpg

(require 'smtpmail)

(eval-after-load "notmuch"
  (lambda ()
    (setq smtpmail-smtp-server "smtp.gmail.com"
          smtpmail-smtp-service 587
          smtpmail-stream-type 'starttls
          smtpmail-debug-info t
          smtpmail-debug-verb t
          message-send-mail-function 'message-smtpmail-send-it)))

(load "notmuch")

(notmuch-hello)

;; Local Variables:
;; mode: emacs-lisp
;; End:
