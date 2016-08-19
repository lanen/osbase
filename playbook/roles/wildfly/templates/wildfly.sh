#!/bin/sh
#
# WildFly control script
#
# chkconfig: - 80 20
# description: WildFly startup script
# processname: wildfly
#

# Source function library.
. /etc/init.d/functions

# Load Java configuration.
. /etc/profile.d/java.sh

JBOSS_CONF="{{ wildfly_home }}/conf/{{ app_name }}-{{ app_port }}.conf"


if [ -r "$JBOSS_CONF" ];then
    . "${JBOSS_CONF}"
else
    echo "Can not find the conf file."
    echo "exit."
    exit 44
fi

export JBOSS_HOME
export JBOSS_PIDFILE

# Startup mode script
if [ "$JBOSS_MODE" = "standalone" ]; then
    JBOSS_SCRIPT=$JBOSS_HOME/bin/standalone.sh
    if [ -z "$JBOSS_CONFIG" ]; then
        JBOSS_CONFIG=standalone.xml
    fi
else
    JBOSS_SCRIPT=$JBOSS_HOME/bin/domain.sh
    if [ -z "$JBOSS_DOMAIN_CONFIG" ]; then
        JBOSS_DOMAIN_CONFIG=domain.xml
    fi
    if [ -z "$JBOSS_HOST_CONFIG" ]; then
        JBOSS_HOST_CONFIG=host.xml
    fi
fi

prog='wildfly'

start() {
    echo -n "Starting $prog: "
    if [ -f $JBOSS_PIDFILE ]; then
        read ppid < $JBOSS_PIDFILE
        if [ `ps --pid $ppid 2> /dev/null | grep -c $ppid 2> /dev/null` -eq '1' ]; then
            echo -n "$prog is already running"
            failure
    echo
        return 1
    else
        rm -f $JBOSS_PIDFILE
    fi
    fi
    mkdir -p $(dirname $JBOSS_CONSOLE_LOG)
    cat /dev/null > $JBOSS_CONSOLE_LOG

    mkdir -p $(dirname $JBOSS_PIDFILE)
    chown $JBOSS_USER $(dirname $JBOSS_PIDFILE) || true

    if [ ! -z "$JBOSS_USER" ]; then
        if [ "$JBOSS_MODE" = "standalone" ]; then
            if [ -r /etc/rc.d/init.d/functions ]; then
                daemon --user $JBOSS_USER LAUNCH_JBOSS_IN_BACKGROUND=1 JBOSS_PIDFILE=$JBOSS_PIDFILE $JBOSS_SCRIPT -c $JBOSS_CONFIG $JBOSS_OPTS >> $JBOSS_CONSOLE_LOG 2>&1 &
            else
                su - $JBOSS_USER -c "LAUNCH_JBOSS_IN_BACKGROUND=1 JBOSS_PIDFILE=$JBOSS_PIDFILE $JBOSS_SCRIPT -c $JBOSS_CONFIG $JBOSS_OPTS" >> $JBOSS_CONSOLE_LOG 2>&1 &
            fi
        else
            if [ -r /etc/rc.d/init.d/functions ]; then
                daemon --user $JBOSS_USER LAUNCH_JBOSS_IN_BACKGROUND=1 JBOSS_PIDFILE=$JBOSS_PIDFILE $JBOSS_SCRIPT --domain-config=$JBOSS_DOMAIN_CONFIG --host-config=$JBOSS_HOST_CONFIG $JBOSS_OPTS >> $JBOSS_CONSOLE_LOG 2>&1 &
            else
                su - $JBOSS_USER -c "LAUNCH_JBOSS_IN_BACKGROUND=1 JBOSS_PIDFILE=$JBOSS_PIDFILE $JBOSS_SCRIPT --domain-config=$JBOSS_DOMAIN_CONFIG --host-config=$JBOSS_HOST_CONFIG $JBOSS_OPTS" >> $JBOSS_CONSOLE_LOG 2>&1 &
            fi
        fi
    fi

    count=0
    launched=false

    until [ $count -gt $STARTUP_WAIT ]
    do
        grep 'WFLYSRV0025:' $JBOSS_CONSOLE_LOG > /dev/null
        if [ $? -eq 0 ] ; then
            launched=true
            break
        fi
        sleep 1
        let count=$count+1;
    done

    touch $JBOSS_LOCKFILE
    success
    echo
    return 0
}
stop() {
    echo -n $"Stopping $prog: "
    count=0;

    if [ -f $JBOSS_PIDFILE ]; then
        read kpid < $JBOSS_PIDFILE
        let kwait=$SHUTDOWN_WAIT

        # Try issuing SIGTERM
        kill -15 $kpid
        until [ `ps --pid $kpid 2> /dev/null | grep -c $kpid 2> /dev/null` -eq '0' ] || [ $count -gt $kwait ]
            do
            sleep 1
            let count=$count+1;
        done

        if [ $count -gt $kwait ]; then
            kill -9 $kpid
        fi
    fi
    rm -f $JBOSS_PIDFILE
    rm -f $JBOSS_LOCKFILE
    success
    echo
}

status() {
    if [ -f $JBOSS_PIDFILE ]; then
        read ppid < $JBOSS_PIDFILE
        if [ `ps --pid $ppid 2> /dev/null | grep -c $ppid 2> /dev/null` -eq '1' ]; then
            echo "$prog is running (pid $ppid)"
            return 0
        else
            echo "$prog dead but pid file exists"
            return 1
        fi
    fi
    echo "$prog is not running"
    return 3
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        $0 stop
        $0 start
        ;;
    status)
        status
        ;;
    *)
        ## If no parameters are given, print which are avaiable.
        echo "Usage: $0 {start|stop|status|restart|reload}"
        exit 1
        ;;
esac

