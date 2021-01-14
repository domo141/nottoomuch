nottoomuch-addresses.sh
=======================

*Nottoomuch-addresses.sh* is an email address completion/matching tool
to be used with `notmuch <http://notmuchmail.org>`_ mail user agents.

*Nottoomuch-addresses.sh* works by caching the email addresses from users'
email files and then doing (fgrep) matching against that cache when
requested.

The matching part is very fast.

How To Install
--------------

1. Copy `nottoomuch-addresses.sh <nottoomuch-addresses.sh>`_  to the machine
   you're running notmuch and find suitable location for it.

2. Run ``/path/to/nottoomuch-addresses.sh --rebuild``
   When run first time this gathers email addresses from all of your mail.
   This may take a long while to complete -- depends on the amount of email
   you have. Further ``--update``\s are much faster as those just take
   addresses from new mail.

3. Test that it works: run ``/path/to/nottoomuch-addresses.sh notmuchmail``

4. In case you're using emacs mua with notmuch, edit your notmuch
   configuration for emacs (e.g. ``~/.emacs.d/notmuch-config.el`` since
   notmuch 0.22) with the following content:
   ::

      (require 'notmuch-address)
      (setq notmuch-address-command "/path/to/nottoomuch-addresses.sh")

5. Restart emacs notmuch mua (or eval above lines) and start composing
   new mail. When adding recipient to To: field. press TAB after 3
   or more characters have been added. In case you get 2 or more address
   matches, use arrow keys in minibuffer to choose desired recipient...

6. (Optional) the default address completion notmuch emacs mua uses when
   addresses are completed using external command may be hard to use with
   nottoomuch-addresses.
   I've been using `selection-menu.el <selection-menu.rst>`_ happily all the
   time I've been using nottoomuch-addresses.sh. I'd like to know about
   alternatives (ido, ivy, helm) but as it works well enough haven't bothered.

7. Enjoy!

``./nottoomuch-addresses.sh --help``  provides more detailed usage information.
