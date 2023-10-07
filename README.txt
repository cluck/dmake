dmake (2.16)
Copyright (C) 2023 Claudio Luck <claudio.luck@datact.ch>

Usage: make TARGET


TARGET is one of:

   init                   Initialize package boiler-plate (makefile+control)
   build                  Build dmakelib_2.16_all.deb
   upload                 Upload dmakelib_2.16_all.deb
   next-version [V=<ver>] Increment Version in DEBIAN/control automatically

 Less often used:

   install-source         Create /etc/apt/sources.list.d/dmake-local.list
   remove-source          Remove /etc/apt/sources.list.d/dmake-local.list
   apt-update             apt-get update just for dmake-local.list
   apt-install            apt-get install -y dmakelib
   config                 Show config (valid {,.,../,../.,~/,~/.,/etc/}dmake.cf)
   info                   Show some package properties, incl. computed versions
   makefile               Create Makefile boilerplate
   control                Create src/DEBIAN/control boilerplate

 Break stuff:

   repo-init              Initialize aptly repository
   repo-show              Show aptly publish list


EXAMPLE ./Makefile:

   VERSION_SCRIPT   = /usr/local/bin/my_script
   VERSION_VARIABLE = MY_SCRIPT_VERSION
   include /usr/local/lib/dmakelib.mk

 .. then create:

   src/DEBIAN/control
   src/usr/local/bin/my_script


EXAMPLE src/DEBIAN/control:

   Package: dmakelib
   Version: 2.16
   Section: utils
   Priority: optional
   Architecture: all
   Maintainer: root <root@localhost>
   Description: dmakelib
   
