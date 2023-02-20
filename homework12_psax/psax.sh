#!/usr/bin/env bash
set -eu

proc_uptime=`cat /proc/uptime | awk -F" " '{print $1}'`
clk_tck=`getconf CLK_TCK`
(
echo "PID|TTY|STAT|TIME|COMMAND";
for pid in `ls /proc | grep -E "^[0-9]+$"`; do
    if [ -d /proc/$pid ]; then
        stat=`</proc/$pid/stat`
        cmd=`echo "$stat" | awk -F" " '{print $2}'`
        state=`echo "$stat" | awk -F" " '{print $3}'`
# tty
        TTY1=`ls -l /proc/$pid/fd/ | grep -E '\/dev\/tty|pts' | cut -d\/ -f3,4 | uniq`
	tty=`awk '{ 
	if ($7 == 0) 
	    { printf "?"} 
	else 
	    { printf "'"$TTY1"'" }}' /proc/$pid/stat`  
       # Time 
        utime=`echo "$stat" | awk -F" " '{print $14}'`
        stime=`echo "$stat" | awk -F" " '{print $15}'`
        ttime=$((utime + stime))
        time=$((ttime / clk_tck)) 
        echo "${pid}|${tty}|${state}|${time}|${cmd}"
    fi
done
) | column -t -s "|"
