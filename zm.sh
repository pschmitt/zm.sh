#!/usr/bin/env bash

set -e

ZM_HOST=localhost
ZM_PORT=10080
ZM_PATH=zm
ZM_SSL=false
QUIET=false

COOKIE_FILE=/tmp/zm.cookie

trap 'rm "$COOKIE_FILE"' SIGINT SIGTERM EXIT

usage() {
    echo "Usage: $(basename $0) [-H HOST] [-P PORT] [-u USERNAME -p PASSWORD] [-z PATH] ACTION"
}

login() {
    curl -qs -d \
        "username=${ZM_USERNAME}&password=${ZM_PASSWORD}&action=login&view=console" \
        -c "$COOKIE_FILE" "${ZM_URL}/index.php" > /dev/null
}

get_version() {
    curl -qs -b "$COOKIE_FILE" "${ZM_URL}/api/host/getVersion.json"
}

get_state() {
    curl -qs -b "$COOKIE_FILE" "${ZM_URL}/api/states.json"
}

get_daemon_state() {
    curl -qs -b "$COOKIE_FILE" "${ZM_URL}/api/host/daemonCheck.json" # | jq '.result'
}

get_monitors() {
    curl -qs -b "$COOKIE_FILE" "${ZM_URL}/api/monitors.json"
}

get_events() {
    curl -qs -b "$COOKIE_FILE" "${ZM_URL}/api/events.json"
}

zm_start() {
    curl -qs -b "$COOKIE_FILE" "${ZM_URL}/api/states/change/start.json"
}

zm_stop() {
    curl -qs -b "$COOKIE_FILE" "${ZM_URL}/api/states/change/stop.json"
}

zm_restart() {
    curl -qs -b "$COOKIE_FILE" "${ZM_URL}/api/states/change/restart.json"
}

zm_status() {
    # pass true as $1 for quiet mode
    if get_daemon_state | grep -q '"result":1'
    then
        if [[ "$1" == true ]]
        then
            echo 1
        else
            echo "ZM daemon is running"
        fi
    else
        if [[ "$1" == true ]]
        then
            echo 0
        else
            echo 'ZM daemon is down!' >&2
        fi
        exit 3
    fi
}

zm_watchdog() {
    while :
    do
        # check state and restart if necessary
        if [[ "$(zm_status true)" != "1" ]]
        then
            if [[ "$QUIET" != "true" ]]
            then
                echo "Zoneminder daemon is stopped. Restarting." >&2
                zm_start
                echo
            else
                zm_start > /dev/null
            fi
        fi
        sleep 10
    done
}

case "$1" in
    h|help|-h|--help)
        usage
        exit 0
    ;;
esac

while getopts ":H:P:u:p:z:sqh" opt; do
    case "$opt" in
        H)
            ZM_HOST="$OPTARG"
            ;;
        P)
            ZM_PORT="$OPTARG"
            ;;
        u)
            ZM_USERNAME="$OPTARG"
            ;;
        p)
            ZM_PASSWORD="$OPTARG"
            ;;
        z)
            ZM_PATH="$OPTARG"
            ;;
        s)
            ZM_SSL=true
            ;;
        q)
            QUIET=true
            ;;
        h)
            usage
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

if [[ "$ZM_SSL" == "true" ]]
then
    ZM_URL="https://${ZM_HOST}:${ZM_PORT}/${ZM_PATH}"
else
    ZM_URL="http://${ZM_HOST}:${ZM_PORT}/${ZM_PATH}"
fi

case "$1" in
    state)
        if [[ -n "$ZM_USERNAME" ]]
        then
            login
        fi
        get_state
        ;;
    daemon-state)
        if [[ -n "$ZM_USERNAME" ]]
        then
            login
        fi
        get_daemon_state
        ;;
    status)
        if [[ -n "$ZM_USERNAME" ]]
        then
            login
        fi
        zm_status "$QUIET"
        ;;
    start)
        if [[ -n "$ZM_USERNAME" ]]
        then
            login
        fi
        zm_start
        ;;
    stop)
        if [[ -n "$ZM_USERNAME" ]]
        then
            login
        fi
        zm_stop
        ;;
    watchdog)
        if [[ -n "$ZM_USERNAME" ]]
        then
            login
        fi
        zm_watchdog
        ;;
    restart)
        if [[ -n "$ZM_USERNAME" ]]
        then
            login
        fi
        zm_restart
        ;;
    monitors)
        if [[ -n "$ZM_USERNAME" ]]
        then
            login
        fi
        get_monitors
        ;;
    events)
        if [[ -n "$ZM_USERNAME" ]]
        then
            login
        fi
        get_events
        ;;
    *)
        usage
        exit 2
        ;;
esac

