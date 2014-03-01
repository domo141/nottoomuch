Notmuch remoteusage without password-free login requirement
===========================================================

This solution uses one pre-made ssh connection where the client is put into
"master" mode (-M) for connection sharing. The wrapper script then uses the
control socket created by this pre-made ssh connection for its own
connection. As long as master ssh connection is live, slave can use
it. Disconnecting master all future attempts to connect from the script
will fail.

The script
----------

Is available at `nottoomuch-remote.bash <nottoomuch-remote.bash>`_

While viewing the script, notice the ``0.1`` in ssh command line. It is
used to avoid any opportunistic behaviour ssh might do; for example if
control socket is not alive ssh would attempt to do it's own ssh connection
to remote ssh server. As address ``0.1`` is invalid this attempt will fail
early.

Test
----

Easiest way to test this script is to run the pre-made ssh connection using
the following command line:
::
    $ ssh -M -S '~'/.ssh/master-notmuch@remote:22 [user@]remotehost sleep 600

(replace ``[user@]remotehost`` above with your login info). Doing this the
above wrapper script can be run unmodified. After the above command has
been run on one terminal, enter ``chmod +x nottoomuch-remote.bash`` in another
terminal and then test the script with
::
    $ ./nottoomuch-remote.bash help

Note that the '~' in the ssh command line above is inside single quotes for
a reason. In this case shell never expand it to $HOME -- ssh does it by not
reading $HOME but checking the real user home directory from
``/etc/passwd``. For security purposes this is just how it should be.

Tune
----

The path ``'~'/.ssh/master-notmuch@remote:22`` might look too generic to be
used as is as the control socket after initial testing (but it can be used).
It is presented as a template for what could be configured to
``$HOME/.ssh/config``. For example:
::
    Host *
        ControlPath ~/.ssh/master-%h@%p:%r

is a good entry to have been written in ``$HOME/.ssh/config``.
Now, let's say you'd make your pre-made ssh connection with command
::
    $ ssh -M robin@example.org

There is 3 options how to handle this with ``./nottoomuch-remote.bash``:

1) Edit ``./nottoomuch-remote.bash`` and change ``REMOTE_NOTMUCH_SSHCTRL_SOCK``
   to contain the new value (being *master-robin@example.org:22* in this
   case)

2) Make symlink:
   ``$ ln -sfT master-robin@example.org:22 ~/.ssh/master-notmuch@remote:22``

3) ``REMOTE_NOTMUCH_SSHCTRL_SOCK`` can be used via environment; like:
   ::
       $ REMOTE_NOTMUCH_SSHCTRL_SOCK=master-robin@example.org:22 ./nottoomuch-remote.bash help

Alternative 3 provides way to use remote notmuch without editing
nottoomuch-remote.bash -- also the same script can be used with multiple
clients to separate (local +) remotes simultaneously!

Configure Emacs on the client computer
--------------------------------------

Add something like the following functions to your Emacs (general(*) or
notmuch specific) configuration files:
::
  ;; this should work as backend function when copied verbatim
  (defun user/notmuch-remote-setup (sockname)
    (setq notmuch-command "/path/to/nottoomuch-remote.bash")
    (setenv "REMOTE_NOTMUCH_SSHCTRL_SOCK" sockname)
    ;; If you use Fcc, you may want to do something like this on the client,
    ;; to Bcc mails to yourself (if not, remove in your implementation):
    (setq notmuch-fcc-dirs nil)
    (add-hook 'message-header-setup-hook
              (lambda () (insert (format "Bcc: %s <%s>\n"
                                         (notmuch-user-name)
                                         (notmuch-user-primary-email))))))

   ;; this is just an example to configure using "default" master socket
   (defun user/notmuch-remote-default ()
     (interactive)
     (user/notmuch-remote-setup "master-notmuch@remote:22")

   ;; usage example2: set USER & HOST1 according to your remote...
   (defun user/notmuch-remote-at-HOST1 ()
     (interactive)
     (user/notmuch-remote-setup "master-USER@HOST1:22")

   ;; ... you probably got the point now -- add relevant funcs to your config
   (defun user/notmuch-remote-at-HOST2 ()
     (interactive)
     (user/notmuch-remote-setup "master-USER@HOST2:22")

... and if you want to activate your remote by default just call
``(user/notmuch-remote-setup "master-USER@HOST:22")`` without function call
wrapper.

(*) general most likely being ~/.emacs

Creating master connection
--------------------------

**(Note: all the examples below use the default master socket written in**
``./nottoomuch-remote.bash`` **for initial test easiness; remove/change the**
``-S '~'/.ssh/master-notmuch@remote:22`` **in case you don't need it.)**

As mentioned so many times, using this solution requires one pre-made ssh
connection in *master* mode. The simplest way is to dedicate one terminal
for the connection with shell access to the remote machine:
::
    $ ssh -M -S '~'/.ssh/master-notmuch@remote:22 [user@]remotehost

One possibility is to have this dedicated terminal in a way that the
connection has (for example 1 hour) timeout:
::
    $ ssh -M -S '~'/.ssh/master-notmuch@remote:22 [user@]remotehost sleep 3600

The above holds the terminal. The next alternative puts the command in
background:
::
    $ ssh -f -M -S '~'/.ssh/master-notmuch@remote:22 [user@]remotehost sleep 3600

If you don't want this to timeout so soon, use a longer sleep, like
99999999 (8 9:s, 1157 days, a bit more than 3 years).

A more "exotic" solution would be to make a shell script running on remote
machine, checking/inotifying when new mail arrives. When mail arrives it
could send message back to local host, where a graphical client (to be
written) pops up on display providing info about received mail (and exiting
this graphical client connection to remote host is terminated).

Troubleshooting
---------------

If you experience strange output when using from emacs first attempt to
just run
::
    $ ./nottoomuch-remote.bash help

from command line and observe output. If it looks as it should be next
uncomment the line
::
    #BASH_XTRACEFD=6; exec 6>>remote-errors; echo -- >&6; set -x

in ``./nottoomuch-remote.bash`` and attempt to use it from emacs again --
and then examine the contents of remote-errors in the working directory
emacs was started.
