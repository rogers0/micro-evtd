TITLE := Micro Event Daemon for Linkstation Pro+Live/Kuro/Terastation
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

# INSTALL_PATH specifies a prefix for relocations required by build
# roots.  This is not defined in the makefile but the argument can be
# passed to make if needed.
INSTALL_PATH ?=

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
SBIN_PATH := $(SBIN_PREPATH)/sbin

# Determine corresponding man path
ifeq (/usr/local,$(SBIN_PREPATH))
 MAN_PATH := /usr/local/share/man
else
 MAN_PATH := /usr/share/man
endif

# STOCKINFO is printed if it seems to be a stock installation, where
# /etc/rcS.d/ is normally missing
 STOCKINFO1 = "Looks *LIKE* a Stock Firmware installation:\\n\
Please edit the file \"$(INSTALL_PATH)/etc/init.d/rcS\".\\n\
Create a backup of the original file before editing.\\n\
Comment out calls of miconapl, miconmon.sh and micon_setup.sh.\\n\
Finally add a call of \"/etc/init.d/$(PROGNAME) start\" to it."
 STOCKINFO2 = "If *NOT* a Stock Firmware installation, e.g. Freelink/Debian:\\n\
Add a link to $(PROGNAME) init script in /etc/init.d/rcS\.\\n\
$(LN) -s '../init.d/$(PROGNAME)' '$(INSTALL_PATH)/etc/rcS.d/S70$(PROGNAME)'"


# Make variables (CC, etc...)
CC = $(CROSS_COMPILE)gcc
LD = $(CROSS_COMPILE)gcc
CFLAGS ?= -Wall -Os
LDFLAGS ?= -Wall -s
INSTALL ?= install
INSTALL_PROGRAM = $(INSTALL)
INSTALL_DATA = $(INSTALL) -m 644
MKDIR = mkdir -p
STRIP = $(CROSS_COMPILE)strip
LN = ln


# Target-dependent values for special builds
# also allow to merge special builds, e.g. clean.static, all.static.extra
# only shortcoming is that <progname>.static.extra doesn't work
PREFIX :=
# --> Static build for the initrd/stock systems
ifneq (,$(filter static %.static,$(MAKECMDGOALS))$(findstring .static.,$(MAKECMDGOALS)))
 PREFIX := $(PREFIX).static
 override EXTRATITLE += STATIC
 override LDFLAGS += -static
endif
# --> Build for Terastation (see forum thread)
ifneq (,$(filter ts %.ts,$(MAKECMDGOALS))$(findstring .ts.,$(MAKECMDGOALS)))
 PREFIX := $(PREFIX).ts
 override EXTRATITLE += TS
 override CFLAGS += -DTS
endif
# --> Maintainer Test
ifneq (,$(filter test %.test,$(MAKECMDGOALS))$(findstring .test.,$(MAKECMDGOALS)))
 PREFIX := $(PREFIX).test
 override EXTRATITLE += MAINTAINER TEST
 override CFLAGS += -DTEST
endif

# Add extra title to CFLAGS
override EXTRATITLE := $(strip $(EXTRATITLE))
ifneq (,$(EXTRATITLE))
 override CFLAGS += -DEXTRATITLE="\"$(EXTRATITLE)\""
endif


# Build variables
BINDIR := bin$(PREFIX)
PROG := $(BINDIR)/$(PROGNAME)

SRCDIR := src
SRCS := $(PROGNAME).c
# evtd-common.c
vpath %.c $(SRCDIR)
vpath %.h $(SRCDIR)

OBJDIR := obj$(PREFIX)
OBJS := $(filter %.c,$(SRCS))
OBJS := $(OBJS:%.c=$(OBJDIR)/%.o)
vpath %.o $(OBJDIR)

DIRS := $(BINDIR) $(OBJDIR)
DIRS := $(sort $(DIRS))


# Build targets
# --> general build targets
.DEFAULT_GOAL := all

.PHONY: all$(PREFIX)
all$(PREFIX): $(PROGNAME)

.PHONY: $(PROGNAME)
$(PROGNAME): $(PROG)

.PHONY: static
static: $(PROG)
 # Static build for the initrd/stock systems

.PHONY: clean$(PREFIX)
clean$(PREFIX):
	-rm -f $(PROG)
	-rm -rf $(DIRS)

# --> general build targets for files and dirs
$(PROG): $(BINDIR) $(OBJS)
	$(LD) $(LDFLAGS) -o $(PROG) $(OBJS)
	$(STRIP) --strip-unneeded $(PROG)

$(OBJS): $(OBJDIR)
# evtd-common.h

$(OBJS): $(OBJDIR)/%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

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
	@echo '  all        - Default target to build $(PROGNAME)'
	@echo '  static     - Link $(PROGNAME) statically for the initrd/stock systems'
	@echo '  ts         - Build $(PROGNAME) for Terastation (-DTS)'
	@echo '  test       - Build $(PROGNAME) for maintainer test (-DTEST)'
	@echo ''
	@echo 'Cleaning targets:'
	@echo '  clean      - Remove generated files'
	@echo ''
	@echo 'Installation targets:'
	@echo '  removeold  - Remove old versions before 3.4 of $(PROGNAME)'
	@echo '               It is recommended to (re)install afterwards'
	@echo '  install    - Install $(PROGNAME)'
	@echo '  uninstall  - Uninstall $(PROGNAME)'
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
	@echo 'Relocation for build roots is supported via $$(INSTALL_PATH).'
	@echo 'Cross compilation is supported via $$(CROSS_COMPILE).'


.PHONY: install$(PREFIX)
install$(PREFIX): $(PROG) uninstall
 # Install executable, controller script and event script
	@if [ ! -d '$(INSTALL_PATH)$(SBIN_PATH)' ] ; then $(MKDIR) '$(INSTALL_PATH)$(SBIN_PATH)' ; fi
	$(INSTALL_PROGRAM) '$(PROG)' '$(INSTALL_PATH)$(SBIN_PATH)'
	$(INSTALL_PROGRAM) 'files/microapl' '$(INSTALL_PATH)$(SBIN_PATH)'
	$(INSTALL_PROGRAM) 'files/$(PROGNAME).event' '$(INSTALL_PATH)$(SBIN_PATH)'

 # Install daemon script
	@if [ ! -d '$(INSTALL_PATH)/etc/init.d' ] ; then $(MKDIR) '$(INSTALL_PATH)/etc/init.d' ; fi
	$(INSTALL_PROGRAM) -T 'files/$(PROGNAME).init' '$(INSTALL_PATH)/etc/init.d/$(PROGNAME)'

 # Install configuration
	@if [ ! -d '$(INSTALL_PATH)/etc' ] ; then $(MKDIR) '$(INSTALL_PATH)/etc' ; fi
	$(INSTALL_DATA) 'files/$(PROGNAME).conf' '$(INSTALL_PATH)/etc'

 # Install man pages
	@if [ ! -d '$(INSTALL_PATH)$(MAN_PATH)/man5' ] ; then $(MKDIR) '$(INSTALL_PATH)$(MAN_PATH)/man5' ; fi
	@if [ ! -d '$(INSTALL_PATH)$(MAN_PATH)/man8' ] ; then $(MKDIR) '$(INSTALL_PATH)$(MAN_PATH)/man8' ; fi
	$(INSTALL_DATA) 'files/$(PROGNAME).8' '$(INSTALL_PATH)$(MAN_PATH)/man8'
	$(INSTALL_DATA) 'files/$(PROGNAME).event.8' '$(INSTALL_PATH)$(MAN_PATH)/man8'
	$(INSTALL_DATA) 'files/microapl.8' '$(INSTALL_PATH)$(MAN_PATH)/man8'
	$(INSTALL_DATA) 'files/$(PROGNAME).conf.5' '$(INSTALL_PATH)$(MAN_PATH)/man5'

 # System maintenance
 ifeq (,$(INSTALL_PATH))
	@echo '...Update the man database'
	-mandb

	@echo '...Start daemon'
	-/etc/init.d/$(PROGNAME) start
 endif

 # Add to SysVInit system
	@if [ -d '$(INSTALL_PATH)/etc/rcS.d' ] ; \
	 then \
		$(LN) -s '../init.d/$(PROGNAME)' '$(INSTALL_PATH)/etc/rcS.d/S70$(PROGNAME)' ; \
	 else \
		echo -e "$(STOCKINFO1)" ; \
		echo -e "$(STOCKINFO2)" ; \
	fi


.PHONY: uninstall
uninstall:
 ifeq (,$(INSTALL_PATH))
	@echo '...Ensure daemon is stopped'
	@if [ -e '/etc/init.d/$(PROGNAME)' ] ; then '/etc/init.d/$(PROGNAME)' stop ; fi
 endif
	-rm -f '$(INSTALL_PATH)$(SBIN_PATH)/$(PROGNAME)'
	-rm -f '$(INSTALL_PATH)$(SBIN_PATH)/microapl'
	-rm -f '$(INSTALL_PATH)$(SBIN_PATH)/$(PROGNAME).event'
	-rm -f '$(INSTALL_PATH)/etc/rcS.d/S70$(PROGNAME)'
	-rm -f '$(INSTALL_PATH)/etc/init.d/$(PROGNAME)'
	-rm -f '$(INSTALL_PATH)/etc/$(PROGNAME).conf'
	-rm -f '$(INSTALL_PATH)$(MAN_PATH)/man8/$(PROGNAME).8'
	-rm -f '$(INSTALL_PATH)$(MAN_PATH)/man8/$(PROGNAME).event.8'
	-rm -f '$(INSTALL_PATH)$(MAN_PATH)/man8/microapl.8'
	-rm -f '$(INSTALL_PATH)$(MAN_PATH)/man5/$(PROGNAME).conf.5'


.PHONY: removeold
removeold:
 ifeq (,$(INSTALL_PATH))
	@echo '...Ensure daemon is stopped'
	@if [ -e '/etc/init.d/micro_evtd' ] ; then '/etc/init.d/micro_evtd' stop ; fi
 endif
 # Pathes from 3.4 alpha development
	-rm -f '$(INSTALL_PATH)$(SBIN_PATH)/micro_evtd'
	-rm -f '$(INSTALL_PATH)$(SBIN_PATH)/microapl'
	-rm -f '$(INSTALL_PATH)$(SBIN_PATH)/micro_evtd.event'
	-rm -f '$(INSTALL_PATH)/etc/rcS.d/S70micro_evtd'
	-rm -f '$(INSTALL_PATH)/etc/init.d/micro_evtd'
	-rm -f '$(INSTALL_PATH)/etc/micro_evtd/micro_evtd.conf'
	-rm -f '$(INSTALL_PATH)$(MAN_PATH)/man8/micro_evtd.8'
	-rm -f '$(INSTALL_PATH)$(MAN_PATH)/man8/micro_evtd.event.8'
	-rm -f '$(INSTALL_PATH)$(MAN_PATH)/man8/microapl.8'
	-rm -f '$(INSTALL_PATH)$(MAN_PATH)/man5/micro_evtd.conf.5'
 # Pathes from Davy Gravy's hdd image
	-rm -f '$(INSTALL_PATH)/usr/local/sbin/micro_evtd'
	-rm -f '$(INSTALL_PATH)/usr/local/sbin/microapl'
	-rm -f '$(INSTALL_PATH)/etc/micro_evtd/micro_evtd.event'
	-rm -f '$(INSTALL_PATH)/etc/rcS.d/S70micro_evtd'
	-rm -f '$(INSTALL_PATH)/etc/init.d/micro_evtd'
	-rm -f '$(INSTALL_PATH)/etc/micro_evtd/micro_evtd.conf'
	-rm -f '$(INSTALL_PATH)/usr/local/share/man/man8/micro_evtd.8'
	-rm -f '$(INSTALL_PATH)/usr/local/share/man/man1/micro_evtd.1.gz'
	-rm -f '$(INSTALL_PATH)/usr/local/share/man/man8/micro_evtd.event.8'
	-rm -f '$(INSTALL_PATH)/usr/local/share/man/man8/microapl.8'
	-rm -f '$(INSTALL_PATH)/usr/local/share/man/man5/micro_evtd.conf.5'
 # Older versions
	-rm -f '$(INSTALL_PATH)/etc/default/micro_evtd'
	-rm -f '$(INSTALL_PATH)/etc/micro_evtd/Eventscript'
	-rm -f '$(INSTALL_PATH)/usr/sbin/man/man1/micro_evtd.1.gz'
	-rm -f '$(INSTALL_PATH)/usr/local/man/man1/micro_evtd.1.gz'
 #
	-rmdir '$(INSTALL_PATH)/etc/micro_evtd'
