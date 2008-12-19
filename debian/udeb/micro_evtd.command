#!/bin/sh

# Wrapper script for micro-evtd to execute single commands.
# If called with -t, it only tests if the device is supported.

DAEMON=/usr/sbin/micro_evtd
MICROAPL="/usr/sbin/microapl -a"
PIDFILE=/var/run/micro_evtd.pid

micro_evtd_start() {
	$DAEMON >/dev/null & disown
	# Allow time to startup
	sleep 1
	pid=$(cat $PIDFILE)

	if [ "$pid" ]; then
		echo $pid
		return 0
	fi
	return 1
}

# Test if device is supported
machine=`sed -n '/Hardware/ {s/^Hardware\s*:\s//;p}' /proc/cpuinfo`
case $machine in
	"Buffalo Linkstation Pro/Live" | "Buffalo/Revogear Kurobox Pro")
	# Success or continue
	[ "$1" == "-t" ] && exit 0 || true ;;
	*)
	# Failure Silently exit
	[ "$1" == "-t" ] && exit 1 || exit 0 ;;
esac

# Execute commands here
case "$1" in
	finish)
		$MICROAPL led_set_blink power
		$MICROAPL led_set_code_information 15
		;;
	init)
		$MICROAPL led_set_blink 0
		$MICROAPL bz_melody 30 b4 || true
		;;
	start)
		# Start micro_evtd if not already running, exit with failure
		# if start failed
		[ -z "$(pidof micro_evtd)" ] || micro_evtd_start || exit 1
		;;
	startup)
		$MICROAPL led_set_blink power
		;;
	stop)
		kill -TERM $(cat $PIDFILE)
		;;
	*)
		;;
esac

exit 0
