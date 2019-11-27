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

mail sending:

nottoomuch-emacs-mailto_ |
`nottoomuch-xdg-email <#mail-sending>`__

mail delivery:

`startfetchmail <#mail-delivery>`__ |
`md5mda <#mail-delivery>`__

remote access:

nottoomuch-remote_

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


mail sending
------------

nottoomuch-emacs-mailto_
  send mail from e.g. following mailto: link in web browsers,
  using notmuch emacs client.

.. _nottoomuch-emacs-mailto: nottoomuch-emacs-mailto.rst

nottoomuch-xdg-email_
  wrap ``xdg-email`` with this (by putting this as ``xdg-email`` in
  ``$PATH`` before the system one) so that nottoomuch-emacs-mailto_
  is used as the mailer.

.. _nottoomuch-xdg-email: nottoomuch-xdg-email.sh


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


remote access
-------------

nottoomuch-remote_
  access notmuch on remote machine using ssh without passwordless login
  requirement.

.. _nottoomuch-remote: nottoomuch-remote.rst


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

.. _make-one-notmuch-el: build/make-one-notmuch-el.pl


work in progress
----------------

some code that has not reached suitable maturity state (I am using to
distribute changes to many dev machines) or is lacking reasonable
ux/documentation, is located in `wip/ <wip/>`__ subdictory.


contributing
------------

anything can be sent digitally to the email address below, or the ways
any particular code repository interfaces provide (in case i receive
email notication). thanks for all contributions i've received so far.

how contributions appear to the repository is another issue. in any
case proper attribution is given in all cases (preferably as commit
author but sometimes in other ways...).


*too ät iki dot fi*
