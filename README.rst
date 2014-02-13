nottoomuch
==========

misc material i use with notmuch mail indexer


introduction
------------

my personal “extensions” around notmuch mail indexer that are too specific
to be added to http://notmuchmail.org/ wiki, with additional scripts
that aren't feasible to be stored to the wiki.

address completion:

nottoomuch-addresses_ |
selection-menu_

mail delivery:

`startfetchmail <#mail-delivery>`__ |
`md5mda <#mail-delivery>`__

building:

`make-one-notmuch-el <#building>`__


address completion
------------------

nottoomuch-addresses_
  the address completion provider i use to get list of email addresses
  from where email addresses is selected when sending emails.

.. _nottoomuch-addresses: nottoomuch-addresses.rst

selection-menu_
  the address completion tool i use to complete email addresses
  when sending emails.

.. _selection-menu: selection-menu.rst


mail delivery
-------------

startfetchmail_
  the fetchmail startup script i use to get it configured as required
  and to see that startup succeeded (failures due to incorrect password etc).

.. _startfetchmail: startfetchmail.sh

md5mda_
  the mail delivery agent i uset to get mails delivered from fetchmail
  to target directories. mails are finally delivered to subdirs whose first
  2 characters are 2 first hexdigits of the md5sum of the file contents
  and the file name is rest 30 hexdigits of the file md5sum.

  startfetchmail_ provides an example how md5mda_ is used.

.. _md5mda: md5mda.sh


building
--------

make-one-notmuch-el_
  i like to have the notmuch emacs byte-compiled file available as a one
  file which is easy to carry along. this script combines all notmuch .el
  files together (with minor adjustments) in suitable order for
  byte-compilation as one file to succeed. the final ``one-notmuch.elc``
  is somewhat smaller than all notmuch ``.elc`` files separately and
  may even load a bit faster. i've been using this for quite a long time
  and have not had problems -- but ymmv with your different setup in case
  trying this option.

.. _make-one-notmuch-el: make-one-notmuch-el.pl


repository branches
-------------------

in addition to **master** branch i have **dogfood** branch where stuff
may not be as polished as in **master**, and **df-yymm** branch(es) with
same file content as **dogfood** branch. see branches.txt_ for more
information.

.. _branches.txt: branches.txt

contributing
------------

i accept patches in links to commit id, as pull requests and as in
patch emails provided by git-format-patch (and git-send-email).
i probably cherry-pick / rebase any stuff received instead of merging
(and possibly do minor amends) so any pull requests made are to be
manually closed.

see also branches.txt_ for reasons tho choose **master** or **df-yymm**
branch as a (re)base branch...


*too ät iki dot fi*
