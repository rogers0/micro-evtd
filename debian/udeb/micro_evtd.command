#!/bin/sh

# Wrapper script for micro-evtd to execute single commands.
# If called with -t, it only tests if the device is supported.

DAEMON=/usr/sbin/micro_evtd
MICROAPL=/usr/sbin/microapl
PIDFILE=/var/run/micro_evtd.pid

micro_evtd_start() {
	micro_evtd >/dev/null & disown
	# Allow time to startup
	sleep 1
	pid=$(pidof micro_evtd)

	if [ "$pid" ]; then
		echo $pid
		return 0
	fi
	return 1
}

# Lights up INFO LED or turns it off.
led_control() {
	if [ "$1" == "on" ]; then
		$MICROAPL led_set_on_off info
	else
		$MICROAPL led_set_on_off off
	fi
}

play_tune() {
	$MICROAPL bz_melody $1 30
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
	start)
		# Start micro_evtd if not already running, exit with failure
		# if start failed
		[ -z "$(pidof micro_evtd)" ] || micro_evtd_start || exit 1
		;;
	stop)
		micro_evtd_stop
		;;
	command)
		case "$2" in
			beep)
				play_tune "b4"
				;;
			led)
				led_control "$3"
				;;
			play)
				play_tune "$3"
				;;
			*)
				;;
		esac
		;;
	*)
		;;
esac

exit 0
