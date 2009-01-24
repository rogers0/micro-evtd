TITLE=Linkstation/Kuro/Terastation Micro Event daemon

CC ?=gcc
INSTPATH=/usr/local/sbin
CFLAGS=-Wall -s -Os -o

all: micro_evtd

static: micro_evtd.c version.h
	# Static build for the initrd/stock systems
	$(CC) -static $(CFLAGS) micro_evtd micro_evtd.c

micro_evtd: micro_evtd.c version.h
	$(CC) $(CFLAGS) micro_evtd micro_evtd.c

ts: micro_evtd.c version.h
	$(CC) $(CFLAGS) micro_evtd micro_evtd.c -DTS

maintainer-test: micro_evtd.c version.h
	@echo "This command is intended for maintainer use only"
	$(CC) $(CFLAGS) micro_evtd micro_evtd.c -DTEST
	
clean: micro_evtd
	-rm -f /etc/init.d/micro_evtd
	-rm -f /etc/micro_evtd/micro_evtd.conf
	-rm -f /etc/micro_evtd/micro_evtd.event
	-rm -f $(INSTPATH)/micro_evtd
	-rm -f $(INSTPATH)/microapl
	-rm -f /usr/local/man/man8/micro_evtd.8
	-rm -f /usr/local/man/man8/micro_evtd.event.8
	-rm -f /usr/local/man/man8/microapl.8
	-rm -f /usr/local/man/man5/micro_evtd.conf.5
	-rm -f $(INSTPATH)/microapl

.PHONY: install clean

install: micro_evtd
	@echo "...ENSURE DAEMON IS STOPPED"
	@if [ -e /etc/init.d/micro_evtd ]; then /etc/init.d/micro_evtd stop ; fi
	-rm -f /etc/init.d/micro_evtd
	@if [ -e /usr/bin/strip ]; then strip --strip-unneeded micro_evtd ; fi
	-cp -f Install/micro_evtd.init /etc/init.d/micro_evtd
	-chmod +x /etc/init.d/micro_evtd

	@echo "...ENSURE LOCAL DIRECTORY EXISTS"
	@if [ ! -d /usr/local ]; then mkdir /usr/local ; fi
	@if [ ! -d $(INSTPATH) ]; then mkdir $(INSTPATH) ; fi

	@echo "...TRANSFER CONTROLLER SCRIPT"
	-cp -f Install/microapl $(INSTPATH)/.
	@echo "..Ensure all users can run this"
	-chmod a+x $(INSTPATH)/microapl

	@echo "...UPDATE EXECUTABLE WITH TARGET BUILD"
	-cp -f micro_evtd $(INSTPATH)/.

	@echo "...ENSURE STORAGE AVAILABLE"
	@if [ ! -d /etc/micro_evtd ]; then mkdir /etc/micro_evtd ; fi

	@echo "...TRANSFER EVENT SCRIPT AND CONFIGURATION"
	-cp -f Install/micro_evtd.event /etc/micro_evtd/.
	-chmod +x /etc/micro_evtd/micro_evtd.event
	-cp Install/micro_evtd.conf /etc/micro_evtd/.

	@echo "...ENSURE LOCAL MAN AVAILABLE"
	@if [ ! -d /usr/local/man ]; then mkdir /usr/local/man ; fi
	@if [ ! -d /usr/local/man/man5 ]; then mkdir /usr/local/man/man5 ; fi
	@if [ ! -d /usr/local/man/man8 ]; then mkdir /usr/local/man/man8 ; fi
	-cp Install/micro_evtd.8 /usr/local/man/man8/.
	-cp Install/micro_evtd.event.8 /usr/local/man/man8/.
	-cp Install/microapl.8 /usr/local/man/man8/.
	-cp Install/micro_evtd.conf.5 /usr/local/man/man5/.
	@echo "..Update the man database"
	@if [ -e /usr/bin/mandb ]; then /usr/bin/mandb ; fi
	
	-/etc/init.d/micro_evtd start
