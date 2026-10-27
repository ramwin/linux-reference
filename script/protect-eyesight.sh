#!/usr/bin/sh

echo "$(date) 运行保护视力脚本" >> /tmp/保护视力.log
version=$(lsb_release -d)
date=`date`
if [[ ${version,,} == *"manjaro"* ]]; then
    export DISPLAY=:0
    # notify-send "保护视力，休息一下，眺望远处"
    message="${date}"
    DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus notify-send  "眺望一下远处" "$message"
else
    exit 400
    echo "系统不是manjaro"
    eval "export $(egrep -z DBUS_SESSION_BUS_ADDRESS /proc/$(pgrep -u $LOGNAME gnome-session)/environ)";
    DISPLAY=:0 notify-send "保护视力，休息一下，眺望远处"
fi
