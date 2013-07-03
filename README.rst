nottoomuch
==========

misc material i use with notmuch mail indexer
---------------------------------------------

introduction
============

to be added....

branches in this git repo
-------------------------

the **master** branch contains “production quality” files

the **dogfoog** branch is used by me. that has latest “experimental” stuff.
that branch i rebase at will. you may use that but do not rebase any work
on it.

the **df-yymm-xxxxxxx** branches contains dogfood stuff branched from
master at commit **xxxxxxx**. these will not be rebased but i remove these
branches from time to time. these are rebase-safe (i guess). i personally
use **dogfood** branch for convenience.

----

ps: guess how many
::

  git add README.rst && git commit --amend -C HEAD && git push --force

lines i've executed in **dogfood** branch so far...
