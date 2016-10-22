nottoomuch-emacs-mailto.pl
==========================

*nottoomuch-emacs-mailto.pl* is a tool typically used from web browser
``mailto:`` links to send email using notmuch emacs client.

When used in graphical environment, a new emacs frame is started
and filled with the information provided in ``mailto:`` link. After
sending the frame will stay on desktop and can be closed the usual
emacs way (*).

On non-graphical terminal, new emacs process is started on the terminal
and from there it works like in graphical display.

In addition to taking ``mailto:`` arguments from command line, there are
(currently) 2 other options, ``-nw`` and ``--from=<address>``. These are,
and can be used in special applications (e.g. wrappers) to e.g. get some
work done.

How To "Install"
----------------

1. Copy `nottoomuch-emacs-mailto.pl <nottoomuch-emacs-mailto.pl>`_ to
   the machine you intent to use it (or clone this repository).

2. Configure web browser to use this when following ``mailto:`` links.
   In Firefox this was easy: *Edit->Preferences->Applications* and set
   ``mailto`` there. In Chrome I could not find how this is done;
   perhaps some mystic *xdg* things or something... I'll update this
   whenever I figure out... OK, the solution is to use
   nottoomuch-xdg-email_ to wrap ``xdg-email``... see its embedded
   documentation for more info.

.. _nottoomuch-xdg-email: nottoomuch-xdg-email.sh

(*) In graphical display, emacs is started in server mode and the frame
is opened using ``emacsclient(1)``. The emacs server uses special server
socket named ``mailto-server``. When last frame closes, there are no
clients connected and no modified buffers with file name, the emacs
in daemon mode exits.
