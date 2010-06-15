TITLE=Linkstation/Kuro/Terastation Micro Event daemon

#
# $Id: $
#

# CROSS_COMPILE specifies the prefix used for all executables used
# during compilation. Only gcc and related bin-utils executables
# are prefixed with $(CROSS_COMPILE).
# CROSS_COMPILE can be set on the command line
# make CROSS_COMPILE=arm-none-linux-gnueabi-
# Alternatively CROSS_COMPILE can be set in the environment.
# Default value for CROSS_COMPILE is not to prefix executables.
CROSS_COMPILE	?=

# INSTALL_PATH specifies a prefix for relocations required by build
# roots.  This is not defined in the makefile but the argument can be
# passed to make if needed.
INSTALL_PATH ?=

# SBIN_PREFIX specifies a prefix to the sbin path for relocations.
# This defaults to /usr/local in the makefile but the argument can be
# passed to make if needed.
SBIN_PREFIX ?= /usr/local


# To understand makefiles check out:
#   http://www.gnu.org/software/make/manual/
#
# Especially note the pitfalls inside rules with tabs for commands
# and spaces for make's functions.
# Examples are available in the install and uninstall target here.


# Make variables (CC, etc...)
CC = $(CROSS_COMPILE)gcc
CFLAGS ?= -Wall -s -Os
INSTALL ?= install
INSTALL_PROGRAM = $(INSTALL)
INSTALL_DATA = $(INSTALL) -m 644
MKDIR = mkdir -p
STRIP = $(CROSS_COMPILE)strip
LN = ln

# STOCKINFO is printed if it seems to be a stock installation, where
# /etc/rcS.d/ is normally missing
ifneq (,$(filter install,$(MAKECMDGOALS)))
 STOCKINFO1 = "Looks *LIKE* a Stock Firmware installation:\\n\
Please edit the file \"$(INSTALL_PATH)/etc/init.d/rcS\".\\n\
Create a backup of the original file before editing.\\n\
Comment out calls of miconapl, miconmon.sh and micon_setup.sh.\\n\
Finally add a call of \"/etc/init.d/micro_evtd start\" to it."
 STOCKINFO2 = "If *NOT* a Stock Firmware installation, e.g. Freelink/Debian:\\n\
Add a link to micro_evtd init script in /etc/init.d/rcS\.\\n\
$(LN) -s '../init.d/micro_evtd' '$(INSTALL_PATH)/etc/rcS.d/S70micro_evtd'"
endif

# Determine sbin and man path from SBIN_PREFIX for install/uninstall target
ifneq (,$(filter install uninstall,$(MAKECMDGOALS)))
 SBIN_PREPATH := $(SBIN_PREFIX)
 # a single slash is emptied
 ifeq (/,$(SBIN_PREPATH))
  SBIN_PREPATH :=
 endif
 # check against valid values
 ifneq (/usr/local,$(SBIN_PREPATH))
#  ifneq (/usr,$(SBIN_PREPATH))
#   ifneq (,$(SBIN_PREPATH))
    $(error SBIN_PREFIX "$(SBIN_PREFIX)" is not supported. See make help.)
#   endif
#  endif
 endif
 #
 SBIN_PATH := $(SBIN_PREPATH)/sbin

 # Determine corresponding man path
 ifeq (/usr/local,$(SBIN_PREPATH))
  MAN_PATH := /usr/local/share/man
 else
  MAN_PATH := /usr/share/man
 endif
endif


.PHONY: all
all: micro_evtd

# Try to determine the current revision and if it is modified in any form.
#
# If Subversion is not available or the revision can not be determined
# (e.g. due to source being from an export or tar ball), and...
# a) revision.h does not exist:
#      create revision.h with #undef REVISION
# b) revision.h exists:
#      do nothing, so possible information added by the user is not destroyed
.PHONY: revision
revision:
	@REV= ; \
	if [ -x "`which svn 2>/dev/null`" ] ; \
	 then \
		REV="r$$(svn info -r COMMITTED | awk '/^Revision:/ { print $$2 }')" ; \
		REV2="$$(svnversion)" ; \
		[ "$${REV2: -1:1}" == "M" ] && REV="$${REV}M" ; \
	fi ; \
	if [ -n "$$REV" ] ; \
	 then \
		REV="#define REVISION \"$$REV\"" ; \
	 elif [ ! -f 'revision.h' ] ; \
	  then \
		REV='#undef REVISION' ; \
	fi ; \
	if [ -n "$$REV" ] ; \
	 then \
		grep -e "$$REV" revision.h 1>/dev/null 2>/dev/null || echo "$$REV" >revision.h ; \
	fi

revision.h: revision

micro_evtd: micro_evtd.c version.h revision.h
	$(CC) $(CFLAGS) -o micro_evtd micro_evtd.c
	$(STRIP) --strip-unneeded micro_evtd

.PHONY: static
static: micro_evtd.c version.h
 # Static build for the initrd/stock systems
	$(CC) -static $(CFLAGS) -o micro_evtd micro_evtd.c
	$(STRIP) --strip-unneeded micro_evtd

.PHONY: ts
ts: micro_evtd.c version.h
	$(CC) $(CFLAGS) -o micro_evtd micro_evtd.c -DTS
	$(STRIP) --strip-unneeded micro_evtd

.PHONY: maintainer-test
maintainer-test: micro_evtd.c version.h
	@echo 'This command is intended for maintainer use only'
	$(CC) $(CFLAGS) -o micro_evtd micro_evtd.c -DTEST
	$(STRIP) --strip-unneeded micro_evtd

.PHONY: clean
clean:
	-rm -f micro_evtd

.PHONY: install
install: micro_evtd uninstall
 # Install executable and controller script
	@if [ ! -d '$(INSTALL_PATH)$(SBIN_PATH)' ] ; then $(MKDIR) '$(INSTALL_PATH)$(SBIN_PATH)' ; fi
	$(INSTALL_PROGRAM) 'micro_evtd' '$(INSTALL_PATH)$(SBIN_PATH)'
	$(INSTALL_PROGRAM) 'Install/microapl' '$(INSTALL_PATH)$(SBIN_PATH)'

 # Install daemon script
	@if [ ! -d '$(INSTALL_PATH)/etc/init.d' ] ; then $(MKDIR) '$(INSTALL_PATH)/etc/init.d' ; fi
	$(INSTALL_PROGRAM) -T 'Install/micro_evtd.init' '$(INSTALL_PATH)/etc/init.d/micro_evtd'

 # Install event script and configuration
	@if [ ! -d '$(INSTALL_PATH)/etc/micro_evtd' ] ; then $(MKDIR) '$(INSTALL_PATH)/etc/micro_evtd' ; fi
	$(INSTALL_PROGRAM) 'Install/micro_evtd.event' '$(INSTALL_PATH)/etc/micro_evtd'
	$(INSTALL_DATA) 'Install/micro_evtd.conf' '$(INSTALL_PATH)/etc/micro_evtd'

 # Install man pages
	@if [ ! -d '$(INSTALL_PATH)$(MAN_PATH)/man5' ] ; then $(MKDIR) '$(INSTALL_PATH)$(MAN_PATH)/man5' ; fi
	@if [ ! -d '$(INSTALL_PATH)$(MAN_PATH)/man8' ] ; then $(MKDIR) '$(INSTALL_PATH)$(MAN_PATH)/man8' ; fi
	$(INSTALL_DATA) 'Install/micro_evtd.8' '$(INSTALL_PATH)$(MAN_PATH)/man8'
	$(INSTALL_DATA) 'Install/micro_evtd.event.8' '$(INSTALL_PATH)$(MAN_PATH)/man8'
	$(INSTALL_DATA) 'Install/microapl.8' '$(INSTALL_PATH)$(MAN_PATH)/man8'
	$(INSTALL_DATA) 'Install/micro_evtd.conf.5' '$(INSTALL_PATH)$(MAN_PATH)/man5'

 # System maintenance
 ifeq (,$(INSTALL_PATH))
	@echo '...Update the man database'
	-mandb

	@echo '...Start daemon'
	-/etc/init.d/micro_evtd start
 endif

 # Add to SysVInit system
	@if [ -d '$(INSTALL_PATH)/etc/rcS.d' ] ; \
	 then \
		$(LN) -s '../init.d/micro_evtd' '$(INSTALL_PATH)/etc/rcS.d/S70micro_evtd' ; \
	 else \
		echo -e "$(STOCKINFO1)" ; \
		echo -e "$(STOCKINFO2)" ; \
	fi


.PHONY: uninstall
uninstall:
 ifeq (,$(INSTALL_PATH))
	@echo '...Ensure daemon is stopped'
	@if [ -e '/etc/init.d/micro_evtd' ] ; then '/etc/init.d/micro_evtd' stop ; fi
 endif
	-rm -f '$(INSTALL_PATH)$(SBIN_PATH)/micro_evtd'
	-rm -f '$(INSTALL_PATH)$(SBIN_PATH)/microapl'
	-rm -f '$(INSTALL_PATH)/etc/init.d/micro_evtd'
	-rm -f '$(INSTALL_PATH)/etc/rcS.d/S70micro_evtd'
	-rm -f '$(INSTALL_PATH)/etc/micro_evtd/micro_evtd.event'
	-rm -f '$(INSTALL_PATH)/etc/micro_evtd/micro_evtd.conf'
	-rm -f '$(INSTALL_PATH)$(MAN_PATH)/man8/micro_evtd.8'
	-rm -f '$(INSTALL_PATH)$(MAN_PATH)/man8/micro_evtd.event.8'
	-rm -f '$(INSTALL_PATH)$(MAN_PATH)/man8/microapl.8'
	-rm -f '$(INSTALL_PATH)$(MAN_PATH)/man5/micro_evtd.conf.5'

.PHONY: help
help:
	@echo 'Cross compilation is supported via $$(CROSS_COMPILE).'
	@echo ''
	@echo 'Cleaning targets:'
	@echo '  clean           - Remove generated files'
	@echo ''
	@echo 'Other generic targets:'
	@echo '  all             - Build all targets marked with [*]'
	@echo '* micro_evtd      - Build micro_evtd normally'
	@echo '  static          - Build micro_evtd statically for the initrd/stock systems'
	@echo '  ts              - Build micro_evtd for Terastation'
	@echo '  maintainer-test - Build micro_evtd for maintainer test'
	@echo ''
	@echo ''
	@echo 'Installation targets:'
	@echo '  install         - Install micro_evtd'
	@echo '  uninstall       - Uninstall micro_evtd'
	@echo ''
	@echo 'micro_evtd is by default installed into the sbin folder of /usr/local.'
#	@echo 'Choosing a different sbin folder is supported via $$(SBIN_PREFIX).'
#	@echo 'Valid values are:'
#	@echo ' Prefix     -> micro_evtd path  -> man path'
#	@echo ' <none>     -> /sbin            -> /usr/share/man'
#	@echo ' /usr       -> /usr/sbin        -> /usr/share/man'
#	@echo ' /usr/local -> /usr/local/sbin  -> /usr/local/share/man'
	@echo ''
	@echo 'Relocation for build roots is supported via $$(INSTALL_PATH).'
