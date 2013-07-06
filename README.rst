nottoomuch
==========

misc material i use with notmuch mail indexer


introduction
------------

my personal “extensions” around notmuch mail indexer that are too specific
to be added to http://notmuchmail.org/ wiki, with additional scripts
that aren't feasible to be stored to the wiki.

`nottooomuch-addresses <nottoomuch-addresses.rst>`_

branches in this git repo
-------------------------

the **master** branch contains “production quality” files

the **dogfoog** branch is used by me. that has latest “experimental” stuff.
that branch i rebase at will. it can be used by anyone who doesn't get
scared by forced updates. also rebasing work on that may be somewhat more
complicated than with branches whose remote-tracking branch keeps its history.

the **df-yymm-1234567** branches contains dogfood stuff branched from
master, first non-master commit being **1234567**. these will not be
rebased but i remove these branches from time to time (presumably seldom).
these are more rebase-safe than **dogfood**.

----

ps: guess how many
::

  git commit --amend -C HEAD README.rst && git push --force

lines i've executed in **dogfood** branch so far (HEAD commit contained
changes to ``README.rst`` only).
