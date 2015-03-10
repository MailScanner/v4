#!/bin/sh
### BEGIN INIT INFO
# Provides:          MailScanner
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Controls mailscanner instances
# Description:       MailScanner is a queue-based spam/virus filter
### END INIT INFO

# Author: Andrew Colin Kissa <andrew@topdog.za.net>
# Author: Simon Walter <simon.walter@hp-factory.de>

# PATH should only include /usr
PATH=/usr/sbin:/usr/bin:/bin:/sbin
DESC="mail spam/virus scanner"
NAME=MailScanner
PNAME=mailscanner
DAEMON=/usr/sbin/$NAME
STARTAS=MailScanner
SCRIPTNAME=/etc/init.d/$PNAME
CONFFILE=/etc/MailScanner/MailScanner.conf
QUICKPEEK=/usr/sbin/Quick.Peek

# Exit if the package is not installed
[ -x "$DAEMON" ] || exit 0

run_mailscanner=0
run_nice=0
stopped_lockfile=/var/lock/MailScanner.off

# Read configuration variable file if it is present
[ -r /etc/default/$PNAME ] && . /etc/default/$PNAME

# Load the VERBOSE setting and other rcS variables
. /lib/init/vars.sh

# Define LSB log_* functions.
# Depend on lsb-base (>= 3.0-6) to ensure that this file is present.
. /lib/lsb/init-functions

# Don't start if MailScanner is not configured
if [ $run_mailscanner = 0 ]; then
if [ -z "$satisfy_nitpicking_on_removal" ]; then
cat <<-EOF

Please edit the file /etc/MailScanner/MailScanner.conf according to
your needs.  Then configure exim for use with mailscanner.

After you are done you will have to edit /etc/default/mailscanner as
well. There you will have to set the variable run_mailscanner to 1,
and then type "/etc/init.d/mailscanner start" to start the mailscanner
daemon.

EOF
fi
exit 0
fi

# sanity check for permissions
fail()
{
    echo >&2 "$0: $1"
    exit 1
}

check_dir()
{
    if [ ! -d $1 ]; then
	mkdir -p "$1" || \
	    fail "directory $1: does not exist and cannot be created"
    fi
    actual="$(stat -c %U $1)"
    if [ "$actual" != "$2" ]; then
	chown -R "$2" "$1" || \
	    fail "directory $1: wrong owner (expected $2 but is $actual)"
    fi
#    actual="$(stat -c %G $1)"
#    if [ "$actual" != "$3" ]; then
#	chgrp -R "$3" "$1" || \
#	    fail "directory $1: wrong group (expected $3 but is $actual)"
#    fi
}

user=`${QUICKPEEK} RunAsUser ${CONFFILE}`
group=`${QUICKPEEK} RunAsGroup ${CONFFILE}`
PIDFILE=`${QUICKPEEK} pidfile ${CONFFILE}`

check_dir /var/spool/MailScanner       ${user:-mail} ${group:-mail}
check_dir /var/lib/MailScanner         ${user:-mail} ${group:-mail}
check_dir /var/run/MailScanner         ${user:-mail} ${group:-mail}
check_dir /var/lock/MailScanner ${user:-mail} ${group:-mail}

#
# Function that starts the daemon/service
#
do_start()
{
	# Return
	#   0 if daemon has been started
	#   1 if daemon was already running
	#   2 if daemon could not be started
	start-stop-daemon --start --quiet --startas $STARTAS --pidfile $PIDFILE --test > /dev/null \
		|| return 1
	start-stop-daemon --start --quiet --nicelevel $run_nice --exec $DAEMON --pidfile $PIDFILE -- $DAEMON_ARGS \
		|| return 2

  # Set lockfile to inform cronjobs about the running daemon
	RETVAL="$?"
	if [ $RETVAL -eq 0 ]; then
	    touch /var/lock/mailscanner
	    rm -f $stopped_lockfile
	fi

}

#
# Function that stops the daemon/service
#
do_stop()
{
	# Return
	#   0 if daemon has been stopped
	#   1 if daemon was already stopped
	#   2 if daemon could not be stopped
	#   other if a failure occurred
	start-stop-daemon --stop --quiet --retry=TERM/10/TERM/20 --pidfile $PIDFILE
	RETVAL="$?"
	[ "$RETVAL" = 2 ] && return 2

  # Remove lockfile for cronjobs
	if [ $RETVAL -eq 0 ]; then
	    rm -f /var/lock/mailscanner
	    touch $stopped_lockfile
	fi

	return "$RETVAL"
}

#
# Function that sends a SIGHUP to the daemon/service
#
do_reload() {
	start-stop-daemon --stop --signal 1 --quiet --pidfile $PIDFILE
	return 0
}

case "$1" in
  start)
	[ "$VERBOSE" != no ] && log_daemon_msg "Starting $DESC" "$NAME"
	do_start
	case "$?" in
		0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
		2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
	esac
	;;
  stop)
	[ "$VERBOSE" != no ] && log_daemon_msg "Stopping $DESC" "$NAME"
	do_stop
	case "$?" in
		0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
		2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
	esac
	;;
  reload|force-reload)
	
	log_daemon_msg "Reloading $DESC" "$NAME"
	do_reload
	log_end_msg $?
	;;
  restart)
	log_daemon_msg "Restarting $DESC" "$NAME"
	do_stop
	case "$?" in
	  0|1)
		do_start
		case "$?" in
			0) log_end_msg 0 ;;
			1) log_end_msg 1 ;; # Old process is still running
			*) log_end_msg 1 ;; # Failed to start
		esac
		;;
	  *)
	  	# Failed to stop
		log_end_msg 1
		;;
	esac
	;;
  *)
	echo "Usage: $SCRIPTNAME {start|stop|restart|reload|force-reload}" >&2
	#echo "Usage: $SCRIPTNAME {start|stop|restart|force-reload}" >&2
	exit 3
	;;
esac

:
