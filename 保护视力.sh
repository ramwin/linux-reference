#!/bin/sh

echo "$(date) 运行保护视力脚本" >> /tmp/保护视力.log
version=$(lsb_release -d)
if [[ ${version,,} == *"manjaro"* ]]; then
    notify-send "保护视力，休息一下，眺望远处"
else
    exit 400
    echo "系统不是manjaro"
    eval "export $(egrep -z DBUS_SESSION_BUS_ADDRESS /proc/$(pgrep -u $LOGNAME gnome-session)/environ)";
    DISPLAY=:0 notify-send "保护视力，休息一下，眺望远处"
fi
