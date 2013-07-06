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

master
  “release quality” material

dogfood
  bleeding edge / undocument hacks -- branch i use to run my stuff.
  this branch will get **forced updates** often, either when this branch
  is rebased on top of current master or when i amend this to look how
  the outcome looks from a web browser.

df-yymm-1234567
  the **tree** of these branches are kept in sync with **dogfood** branch
  but the history is not altered. the **1234567** is the commit id of
  first commit in these branches after branching from master; i.e. this
  commit should always be available in the git repository. these branches
  are treated like (long lived) topic-branches -- eventually these will
  go away and replaced with newer ones (less non-master commits).

contributing
------------

if anyone ever desires to contribute to this repo, it is easier to deal
with **master** and **df-yymm-1234567** branches than **dogfood**.
i accept patches in links to commit id, as pull requests and as in
patch emails provided by git-format-patch (and git-send-email).

*too ät iki dot fi*

----

ps: guess how many
::

  git commit --amend -C HEAD README.rst && git push --force

lines i've executed in **dogfood** branch so far (HEAD commit contained
changes to ``README.rst`` only).
