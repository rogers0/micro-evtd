TITLE=Linkstation/Kuro/Terastation Micro Event daemon

all: micro_evtd

static: micro_evtd.c version.h
	# Static build for the initrd/stock systems
	gcc -static -Wall -s -Os -o micro_evtd micro_evtd.c

micro_evtd: micro_evtd.c version.h
	gcc -Wall -s -Os -o micro_evtd micro_evtd.c

ts: micro_evtd.c version.h
	gcc -Wall -s -Os -o micro_evtd micro_evtd.c -DTS

clean: micro_evtd
	-rm -f micro_evtd
	-rm -f /etc/init.d/micro_evtd
	-rm -f /etc/default/micro_evtd
	-rm -f /etc/micro_evtd/EventScript
	-rm -f /usr/local/sbin/micro_evtd
	-rm -f /usr/local/man/man8/micro_evtd.8
	-rm -f /usr/local/man/man8/micro_evtd.event.8
	-rm -f /usr/local/man/man8/microapl.8
	-rm -f /usr/local/man/man5/micro_evtd.conf.5
	-rm -f /usr/local/sbin/microapl

install: micro_evtd
	#
	# ENSURE DAEMON IS STOPPED
	if [ -e /etc/init.d/micro_evtd ]; then /etc/init.d/micro_evtd stop ; fi
	-rm -f /etc/init.d/micro_evtd
	if [ -e /usr/bin/strip ]; then strip --strip-unneeded micro_evtd ; fi
	-cp Install/micro_evtd.init /etc/init.d/micro_evtd
	-chmod +x /etc/init.d/micro_evtd

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
	# TRANSFER EVENT SCRIPT AND CONFIGURATION
	-cp Install/micro_evtd.event /etc/micro_evtd/.
	-chmod +x /etc/micro_evtd/micro_evtd.event
	-cp Install/micro_evtd.conf /etc/micro_evtd/.

	#
	# ENSURE LOCAL MAN AVAILABLE
	if [ ! -d /usr/local/man ]; then mkdir /usr/local/man ; fi
	if [ ! -d /usr/local/man/man5 ]; then mkdir /usr/local/man/man5 ; fi
	if [ ! -d /usr/local/man/man8 ]; then mkdir /usr/local/man/man8 ; fi
	-cp Install/micro_evtd.8 /usr/local/man/man8/.
	-cp Install/micro_evtd.event.8 /usr/local/man/man8/.
	-cp Install/microapl.8 /usr/local/man/man8/.
	-cp Install/micro_evtd.conf.5 /usr/local/man/man5/.
	if [ -e /usr/bin/mandb ]; then /usr/bin/mandb ; fi
	
	-/etc/init.d/micro_evtd start