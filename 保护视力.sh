#!/bin/sh
eval "export $(egrep -z DBUS_SESSION_BUS_ADDRESS /proc/$(pgrep -u $LOGNAME gnome-session)/environ)";

#Code:
DISPLAY=:0 notify-send "保护视力，休息一下，眺望远处"
