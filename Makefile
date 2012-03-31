TITLE=Linkstation/Kuro Micro Event daemon

all: micro_evtd

static: micro_evtd.c version.h
	# Static build for the initrd/stock systems
	gcc -static -Wall -s -Os -o micro_evtd micro_evtd.cpp

micro_evtd: micro_evtd.c version.h
	gcc -Wall -s -Os -o micro_evtd micro_evtd.c

ts: micro_evtd.c version.h
	gcc -Wall -s -Os -o micro_evtd micro_evtd.c -DTS

clean: micro_evtd
	-rm -f micro_evtd
	-rm -f /etc/init.d/micro_evtd
	-rm -f /usr/sbin/man/man1/micro_evtd.1.gz
	-rm -f /etc/default/micro_evtd
	-rm -f /etc/micro_evtd/EventScript
	-rm -f /usr/local/sbin/micro_evtd
	-rm -f /usr/local/man/man1/micro_evtd.1.gz
	-rm -f /usr/local/sbin/microapl

install: micro_evtd
	#
	# ENSURE DAEMON IS STOPPED
	if [ -e /etc/init.d/micro_evtd ]; then /etc/init.d/micro_evtd stop ; fi
	-rm -f /etc/init.d/micro_evtd
	if [ -e /usr/bin/strip ]; then strip --strip-unneeded micro_evtd ; fi
	cp Install/micro_evtd /etc/init.d/.
	chmod +x /etc/init.d/micro_evtd

	#
	# Transfer controller script
	-cp Install/microapl /usr/local/sbin/.

	#
	# ENSURE LOCAL DIRECTORY EXISTS
	if [ ! -d /usr/local ]; then mkdir /usr/local ; fi
	if [ ! -d /usr/local/sbin ]; then mkdir /usr/local/sbin ; fi

	#
	# UPDATE EXECUTABLE WITH TARGET BUILD
	-cp micro_evtd /usr/local/sbin/.

	#
	# ENSURE STORAGE AVAILABLE
	if [ ! -d /etc/micro_evtd ]; then mkdir /etc/micro_evtd ; fi

	#
	# TRANSFER EVENT SCRIPT
	-cp Install/EventScript /etc/micro_evtd/.
	-chmod +x /etc/micro_evtd/*

	#
	# ENSURE DEFAULT AVAILABLE
	if [ ! -d /etc/default ]; then mkdir /etc/default ; fi
	if [ ! -e /etc/default/micro_evtd ]; then \
	cp Install/micro_evtd.sample /etc/default/micro_evtd ; else \
	cp Install/micro_evtd.sample /etc/default/micro_evtd.sample ; fi

	#
	# ENSURE LOCAL MAN AVAILABLE
	if [ ! -d /usr/local/man ]; then mkdir /usr/local/man ; fi
	if [ ! -d /usr/local/man/man1 ]; then mkdir /usr/local/man/man1 ; fi
	-rm -f /usr/sbin/man/man1/micro_evtd.1.gz
	-cp Install/micro_evtd.1.gz /usr/local/man/man1/.

	-/etc/init.d/micro_evtd start
