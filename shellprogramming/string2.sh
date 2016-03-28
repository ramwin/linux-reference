#!/bin/bash
# Xiang Wang @ 2016-03-27 20:49:17

x=$(/sbin/ifconfig)
echo $x
y=${x#*inet addr:}
y=${x#*lo *inet addr:}
y=${y%% *}

echo {a..z}
for n in {0..5}
do
    echo $n
done
