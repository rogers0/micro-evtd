TITLE := Micro Event Daemon for Linkstation Pro+Live/Kuro/Terastation ARM series
PROGNAME := micro-evtd

#
# Written by Bob Perry (2007-2009) lb-source@users.sourceforge.net
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

#
# $Id$
#

# To understand makefiles check out:
#   http://www.gnu.org/software/make/manual/
#   http://www.gnu.org/prep/standards/
#
# Especially note the pitfalls inside rules with tabs for commands
# and spaces for make's functions.
# Examples are available in the install and uninstall target here.


# CROSS_COMPILE specifies the prefix used for all executables used
# during compilation. Only gcc and related bin-utils executables
# are prefixed with $(CROSS_COMPILE).
# CROSS_COMPILE can be set on the command line
# make CROSS_COMPILE=arm-none-linux-gnueabi-
# Alternatively CROSS_COMPILE can be set in the environment.
# Default value for CROSS_COMPILE is not to prefix executables.
CROSS_COMPILE ?=

# DESTDIR specifies a prefix for relocations required by build
# roots.  This is not defined in the makefile but the argument can be
# passed to make if needed.
DESTDIR ?=

# EXTRATITLE allows to add an extra string to version display
EXTRATITLE ?=

# SBIN_PREFIX specifies a prefix to the sbin path for relocations.
# This defaults to /usr/local in the makefile but the argument can be
# passed to make if needed.
SBIN_PREFIX ?= /usr/local


# Determine sbin and man path from SBIN_PREFIX for install/uninstall target
SBIN_PREPATH := $(SBIN_PREFIX)
# a single slash is emptied
ifeq (/,$(SBIN_PREPATH))
 SBIN_PREPATH :=
endif
# check against valid values
ifneq (/usr/local,$(SBIN_PREPATH))
 ifneq (/usr,$(SBIN_PREPATH))
  ifneq (,$(SBIN_PREPATH))
   $(error SBIN_PREFIX "$(SBIN_PREFIX)" is not supported. See make help.)
  endif
 endif
endif
#
sbindir := $(SBIN_PREPATH)/sbin

# Determine corresponding man path
ifeq (/usr/local,$(SBIN_PREPATH))
 mandir := /usr/local/share/man
else
 mandir := /usr/share/man
endif

# INITINFO explains how to activate the daemon on different firmwares
 INITINFO1 = "To activate $(PROGNAME) on a Stock Firmware installation:\\n\
Please edit the file \"$(DESTDIR)/etc/init.d/rcS\".\\n\
Create a backup of the original file before editing.\\n\
Comment out calls of miconapl, miconmon.sh and micon_setup.sh.\\n\
Finally add a call of \"/etc/init.d/$(PROGNAME) start\" to it."
 INITINFO2 = "To activate $(PROGNAME) on a *NON* Stock Firmware installation, e.g. Freelink/Debian:\\n\
Add a link to $(PROGNAME) init script in /etc/init.d/rcS\.\\n\
$(LN) -s '../init.d/$(PROGNAME)' '$(DESTDIR)/etc/rcS.d/S70$(PROGNAME)'"

# MANINFO explains how to update the man database
 MANINFO = "To update the db of the man pages call mandb"

# Make variables (CC, etc...)
CC = $(CROSS_COMPILE)gcc
LD = $(CROSS_COMPILE)gcc
CFLAGS ?= -Wall -Os
LDFLAGS ?=
INSTALL ?= install
INSTALL_PROGRAM = $(INSTALL)
INSTALL_DATA = $(INSTALL) -m 644
MKDIR = mkdir -p
STRIP = $(CROSS_COMPILE)strip
LN = ln


# Target-dependent values for special builds
# also allow to merge special builds, e.g. clean.static, all.static.extra
# only shortcoming is that <progname>.static.extra doesn't work
TRGTSUFFIX :=
CPPFLAGS ?=
# --> Static build for the initrd/stock systems
ifneq (,$(filter static %.static,$(MAKECMDGOALS))$(findstring .static.,$(MAKECMDGOALS)))
 TRGTSUFFIX := $(TRGTSUFFIX).static
 override EXTRATITLE += STATIC
 override LDFLAGS += -static
endif
# --> Build for Terastation (see forum thread)
ifneq (,$(filter ts %.ts,$(MAKECMDGOALS))$(findstring .ts.,$(MAKECMDGOALS)))
 TRGTSUFFIX := $(TRGTSUFFIX).ts
 override EXTRATITLE += TS
 override CPPFLAGS += -DTS
endif
# --> Maintainer Test
ifneq (,$(filter test %.test,$(MAKECMDGOALS))$(findstring .test.,$(MAKECMDGOALS)))
 TRGTSUFFIX := $(TRGTSUFFIX).test
 override EXTRATITLE += MAINTAINER TEST
 override CPPFLAGS += -DTEST
endif

# Add extra title to CFLAGS
override EXTRATITLE := $(strip $(EXTRATITLE))
ifneq (,$(EXTRATITLE))
 override CPPFLAGS += -DEXTRATITLE="\"$(EXTRATITLE)\""
endif


# Build variables
PROGDIR := bin$(TRGTSUFFIX)
PROG := $(PROGDIR)/$(PROGNAME)

srcdir := src
SRCS := $(PROGNAME).c
# evtd-common.c
vpath %.c $(srcdir)
vpath %.h $(srcdir)

OBJDIR := obj$(TRGTSUFFIX)
OBJS := $(filter %.c,$(SRCS))
OBJS := $(OBJS:%.c=$(OBJDIR)/%.o)
vpath %.o $(OBJDIR)

DIRS := $(PROGDIR) $(OBJDIR)
DIRS := $(sort $(DIRS))


# Build targets
# --> general build targets
.DEFAULT_GOAL := all

.PHONY: all$(TRGTSUFFIX)
all$(TRGTSUFFIX): $(PROGNAME)

.PHONY: $(PROGNAME)
$(PROGNAME): $(PROG)

.PHONY: static
static: $(PROG)
 # Static build for the initrd/stock systems

.PHONY: clean$(TRGTSUFFIX)
clean$(TRGTSUFFIX):
	-rm -f $(PROG)
	-rm -rf $(DIRS)

# --> general build targets for files and dirs
$(PROG): $(PROGDIR) $(OBJS)
	$(LD) $(LDFLAGS) $(CFLAGS) -o $(PROG) $(OBJS)

$(OBJS): $(OBJDIR)
# evtd-common.h

$(OBJS): $(OBJDIR)/%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(DIRS):
	${MKDIR} $@

# --> daemon specific build targets
.PHONY: ts
ts: $(PROG)
	@echo 'ATTENTION!!! Build for Terastation (see forum thread)'

.PHONY: test
test:  $(PROG)
	@echo 'ATTENTION!!! This build is intended for maintainer use only'


.PHONY: help
help:
	@echo 'Build targets:'
	@echo '  all           - Default target to build $(PROGNAME)'
	@echo '  static        - Link $(PROGNAME) statically for the initrd/stock systems'
	@echo '  ts            - Build $(PROGNAME) for Terastation (-DTS)'
	@echo '  test          - Build $(PROGNAME) for maintainer test (-DTEST)'
	@echo ''
	@echo 'Cleaning targets:'
	@echo '  clean         - Remove generated files'
	@echo ''
	@echo 'Installation targets:'
	@echo '  removeold     - Remove old versions before 3.4 of $(PROGNAME)'
	@echo '                  It is recommended to (re)install afterwards'
	@echo '  install       - Install $(PROGNAME)'
	@echo '  install-strip - Install stripped $(PROGNAME)'
	@echo '  uninstall     - Uninstall $(PROGNAME)'
	@echo ''
	@echo 'Additionally this makefile allows to combine several targets by appending them'
	@echo 'as suffices to the targets all, clean or install.'
	@echo 'Example: the virtual target "all.static.ts" creates a static Terastation build'
	@echo ''
	@echo '$(PROGNAME) is by default installed into the sbin folder of /usr/local.'
	@echo 'Choosing a different sbin folder is supported via $$(SBIN_PREFIX).'
	@echo 'Valid values are:'
	@echo ' Prefix     -> $(PROGNAME) path  -> man path'
	@echo ' <none>     -> /sbin            -> /usr/share/man'
	@echo ' /usr       -> /usr/sbin        -> /usr/share/man'
	@echo ' /usr/local -> /usr/local/sbin  -> /usr/local/share/man'
	@echo ''
	@echo 'Relocation for build roots is supported via $$(DESTDIR).'
	@echo 'Cross compilation is supported via $$(CROSS_COMPILE).'


.PHONY: installdirs
installdirs:
 # $(PRE_INSTALL)     # Pre-install commands follow.
	@if [ ! -d '$(DESTDIR)$(sbindir)' ] ; then $(MKDIR) '$(DESTDIR)$(sbindir)' ; fi
	@if [ ! -d '$(DESTDIR)/etc/init.d' ] ; then $(MKDIR) '$(DESTDIR)/etc/init.d' ; fi
	@if [ ! -d '$(DESTDIR)/etc' ] ; then $(MKDIR) '$(DESTDIR)/etc' ; fi
	@if [ ! -d '$(DESTDIR)$(mandir)/man5' ] ; then $(MKDIR) '$(DESTDIR)$(mandir)/man5' ; fi
	@if [ ! -d '$(DESTDIR)$(mandir)/man8' ] ; then $(MKDIR) '$(DESTDIR)$(mandir)/man8' ; fi


.PHONY: install$(TRGTSUFFIX)
install$(TRGTSUFFIX): $(PROG) uninstall installdirs
 # $(NORMAL_INSTALL)  # Normal commands follow.
 # Install executable, controller script and event script
	$(INSTALL_PROGRAM) '$(PROG)' '$(DESTDIR)$(sbindir)'
	$(INSTALL_PROGRAM) 'files/microapl' '$(DESTDIR)$(sbindir)'
	$(INSTALL_PROGRAM) 'files/$(PROGNAME).event' '$(DESTDIR)$(sbindir)'

 # Install daemon script
	$(INSTALL_PROGRAM) -T 'files/$(PROGNAME).init' '$(DESTDIR)/etc/init.d/$(PROGNAME)'

 # Install configuration
	$(INSTALL_DATA) 'files/$(PROGNAME).conf' '$(DESTDIR)/etc'

 # Install man pages
	$(INSTALL_DATA) 'files/$(PROGNAME).8' '$(DESTDIR)$(mandir)/man8'
	$(INSTALL_DATA) 'files/$(PROGNAME).event.8' '$(DESTDIR)$(mandir)/man8'
	$(INSTALL_DATA) 'files/microapl.8' '$(DESTDIR)$(mandir)/man8'
	$(INSTALL_DATA) 'files/$(PROGNAME).conf.5' '$(DESTDIR)$(mandir)/man5'

 # $(POST_INSTALL)    # Post-install commands follow.
 # System maintenance
 ifeq (,$(DESTDIR))
	@echo '...Start daemon'
	-/etc/init.d/$(PROGNAME) start
 endif

 # Display activation infos
	@echo -e "$(INITINFO1)"
	@echo -e "$(INITINFO2)"
	@echo -e "$(MANINFO)"


.PHONY: install-strip$(TRGTSUFFIX)
install-strip$(TRGTSUFFIX): install$(TRGTSUFFIX)
	$(STRIP) --strip-unneeded '$(DESTDIR)$(sbindir)/$(PROGNAME)'


.PHONY: uninstall
uninstall:
 # $(PRE_UNINSTALL)     # Pre-uninstall commands follow.
 ifeq (,$(DESTDIR))
	@echo '...Ensure daemon is stopped'
	@if [ -e '/etc/init.d/$(PROGNAME)' ] ; then '/etc/init.d/$(PROGNAME)' stop ; fi
 endif

 # $(NORMAL_UNINSTALL)  # Normal commands follow.
	-rm -f '$(DESTDIR)$(sbindir)/$(PROGNAME)'
	-rm -f '$(DESTDIR)$(sbindir)/microapl'
	-rm -f '$(DESTDIR)$(sbindir)/$(PROGNAME).event'
	-rm -f '$(DESTDIR)/etc/rcS.d/S70$(PROGNAME)'
	-rm -f '$(DESTDIR)/etc/init.d/$(PROGNAME)'
	-rm -f '$(DESTDIR)/etc/$(PROGNAME).conf'
	-rm -f '$(DESTDIR)$(mandir)/man8/$(PROGNAME).8'
	-rm -f '$(DESTDIR)$(mandir)/man8/$(PROGNAME).event.8'
	-rm -f '$(DESTDIR)$(mandir)/man8/microapl.8'
	-rm -f '$(DESTDIR)$(mandir)/man5/$(PROGNAME).conf.5'


.PHONY: removeold
removeold:
 # $(PRE_UNINSTALL)     # Pre-uninstall commands follow.
 ifeq (,$(DESTDIR))
	@echo '...Ensure daemon is stopped'
	@if [ -e '/etc/init.d/micro_evtd' ] ; then '/etc/init.d/micro_evtd' stop ; fi
 endif

 # $(NORMAL_UNINSTALL)  # Normal commands follow.
 # Pathes from 3.4 alpha development
	-rm -f '$(DESTDIR)$(sbindir)/micro_evtd'
	-rm -f '$(DESTDIR)$(sbindir)/microapl'
	-rm -f '$(DESTDIR)$(sbindir)/micro_evtd.event'
	-rm -f '$(DESTDIR)/etc/rcS.d/S70micro_evtd'
	-rm -f '$(DESTDIR)/etc/init.d/micro_evtd'
	-rm -f '$(DESTDIR)/etc/micro_evtd/micro_evtd.conf'
	-rm -f '$(DESTDIR)$(mandir)/man8/micro_evtd.8'
	-rm -f '$(DESTDIR)$(mandir)/man8/micro_evtd.event.8'
	-rm -f '$(DESTDIR)$(mandir)/man8/microapl.8'
	-rm -f '$(DESTDIR)$(mandir)/man5/micro_evtd.conf.5'
 # Pathes from Davy Gravy's hdd image
	-rm -f '$(DESTDIR)/usr/local/sbin/micro_evtd'
	-rm -f '$(DESTDIR)/usr/local/sbin/microapl'
	-rm -f '$(DESTDIR)/etc/micro_evtd/micro_evtd.event'
	-rm -f '$(DESTDIR)/etc/rcS.d/S70micro_evtd'
	-rm -f '$(DESTDIR)/etc/init.d/micro_evtd'
	-rm -f '$(DESTDIR)/etc/micro_evtd/micro_evtd.conf'
	-rm -f '$(DESTDIR)/usr/local/share/man/man8/micro_evtd.8'
	-rm -f '$(DESTDIR)/usr/local/share/man/man1/micro_evtd.1.gz'
	-rm -f '$(DESTDIR)/usr/local/share/man/man8/micro_evtd.event.8'
	-rm -f '$(DESTDIR)/usr/local/share/man/man8/microapl.8'
	-rm -f '$(DESTDIR)/usr/local/share/man/man5/micro_evtd.conf.5'
 # Older versions
	-rm -f '$(DESTDIR)/etc/default/micro_evtd'
	-rm -f '$(DESTDIR)/etc/micro_evtd/Eventscript'
	-rm -f '$(DESTDIR)/usr/sbin/man/man1/micro_evtd.1.gz'
	-rm -f '$(DESTDIR)/usr/local/man/man1/micro_evtd.1.gz'

 # $(POST_UNINSTALL)     # Post-uninstall commands follow.
	-rmdir '$(DESTDIR)/etc/micro_evtd'
