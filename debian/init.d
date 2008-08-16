#!/bin/sh
#
# Copyright (c) 2007 Javier Fernandez-Sanguino <jfs@debian.org>
#
# This is free software; you may redistribute it and/or modify
# it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2,
# or (at your option) any later version.
#
# This is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License with
# the Debian operating system, in /usr/share/common-licenses/GPL;  if
# not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA 02111-1307 USA
#
### BEGIN INIT INFO
# Provides:          micro-evtd
# Required-Start:    $local_fs
# Required-Stop:     $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Daemon for Linkstation/Kuro micro controller
# Description:       Micro-evtd is able to control and monitor fans,
#                    various LEDs, system temperature and two buttons. It
#                    can also set the system in standby and wake up on
#                    timed events.
### END INIT INFO

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

DAEMON=/usr/sbin/micro_evtd
NAME=micro-evtd
DESC="Daemon for Linkstation/Kuro micro controller"
LOGDIR=/var/log/micro-evtd

PIDFILE=/var/run/micro_evtd.pid

test -x $DAEMON || exit 0

. /lib/lsb/init-functions

DAEMON_OPTS=""
DIETIME=10
LOGFILE=$LOGDIR/$NAME.log  # Server logfile
STARTTIME=1

# Include defaults if available
if [ -f /etc/default/$NAME ] ; then
	. /etc/default/$NAME
fi


set -e

running_pid() {
# Check if a given process pid's cmdline matches a given name
    pid=$1
    name=$2
    [ -z "$pid" ] && return 1 
    [ ! -d /proc/$pid ] &&  return 1
    cmd=`cat /proc/$pid/cmdline | tr "\000" "\n"|head -n 1 |cut -d : -f 1`
    # Is this the expected server
    [ "$cmd" != "$name" ] &&  return 1
    return 0
}

running() {
# Check if the process is running looking at /proc
# (works for all users)

    # No pidfile, probably no daemon present
    [ ! -f "$PIDFILE" ] && return 1
    pid=`cat $PIDFILE`
    running_pid $pid $DAEMON || return 1
    return 0
}

start_server() {
# Start the process using the wrapper
    start-stop-daemon --start --quiet --pidfile $PIDFILE \
                --exec $DAEMON -- $DAEMON_OPTS
    errcode=$?

    return $errcode
}

stop_server() {
# Stop the process using the wrapper
    start-stop-daemon --stop --quiet --pidfile $PIDFILE \
                --exec $DAEMON
    errcode=$?

    return $errcode
}

reload_server() {
    [ ! -f "$PIDFILE" ] && return 1
    pid=`cat $PIDFILE` # This is the daemon's pid
    # Send a SIGHUP
    kill -1 $pid
    return $?
}

force_stop() {
# Force the process to die killing it manually
	[ ! -e "$PIDFILE" ] && return
	if running ; then
		kill -15 $pid
	# Is it really dead?
		sleep "$DIETIME"s
		if running ; then
			kill -9 $pid
			sleep "$DIETIME"s
			if running ; then
				echo "Cannot kill $NAME (pid=$pid)!"
				exit 1
			fi
		fi
	fi
	rm -f $PIDFILE
}


case "$1" in
  start)
	log_daemon_msg "Starting $DESC" "$NAME"
        # Check if it's running first
        if running ;  then
            log_progress_msg "apparently already running"
            log_end_msg 0
            exit 0
        fi
        if start_server ; then
            [ -n "$STARTTIME" ] && sleep $STARTTIME # Wait some time 
            if  running ;  then
                # It's ok, the server started and is running
                log_end_msg 0
            else
                # It is not running after we did start
                log_end_msg 1
            fi
        else
            # Either we could not start it
            log_end_msg 1
        fi
	;;
  stop)
        log_daemon_msg "Stopping $DESC" "$NAME"
        if running ; then
            # Only stop the server if we see it running
            stop_server
            log_end_msg $?
        else
            # If it's not running don't do anything
            log_progress_msg "apparently not running"
            log_end_msg 0
            exit 0
        fi
        ;;
  force-stop)
        # First try to stop gracefully the program
        $0 stop
        if running; then
            # If it's still running try to kill it more forcefully
            log_daemon_msg "Stopping (force) $DESC" "$NAME"
            force_stop
            log_end_msg $?
        fi
	;;
  restart|force-reload)
        log_daemon_msg "Restarting $DESC" "$NAME"
        stop_server
        # Wait some sensible amount, some server need this
        [ -n "$DIETIME" ] && sleep $DIETIME
        start_server
        [ -n "$STARTTIME" ] && sleep $STARTTIME
        running
        log_end_msg $?
	;;
  status)

        log_daemon_msg "Checking status of $DESC" "$NAME"
        if running ;  then
            log_progress_msg "running"
            log_end_msg 0
        else
            log_progress_msg "apparently not running"
            log_end_msg 1
            exit 1
        fi
        ;;
  reload)
        log_warning_msg "Reloading $NAME daemon: not implemented, as the daemon"
        log_warning_msg "cannot re-read the config file (use restart)."
        ;;
  *)
	N=/etc/init.d/$NAME
	echo "Usage: $N {start|stop|force-stop|restart|force-reload|status}" >&2
	exit 1
	;;
esac

exit 0
