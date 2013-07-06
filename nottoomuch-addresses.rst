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

1. Copy `nottooomuch-addresses.sh <nottoomuch-addresses.sh>`_  to the machine
   you're running notmuch and find suitable location for it.

2. Run ``/path/to/nottoomuch-addresses.sh --update``
   When run first time this gathers email addresses from all of your mail.
   This may take a long while to complete -- depends on the amount of email
   you have. Further --updates are much faster as those just take addresses
   from new mail.

3. Test that it works: run ``/path/to/nottoomuch-addresses.sh notmuchmail``

4. In case you're using emacs mua with notmuch, edit your notmuch
   configuration for emacs with the following content:
   ::

      (require 'notmuch-address)
      (setq notmuch-address-command "/path/to/nottoomuch-addresses.sh")
      (notmuch-address-message-insinuate)

5. Restart emacs notmuch mua (or eval above lines) and start composing
   new mail. When adding recipient to To: field. press TAB after 3
   or more characters have been added. In case you get 2 or more address
   matches, use arrow keys in minibuffer to choose desired recipient...

6. Enjoy!

``./nottoomuch-addresses.sh --help``  provides more detailed usage information.
