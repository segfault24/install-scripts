#!/bin/bash

if ! [ $(id -u) = 0 ]; then
    echo "This script must be run with root privileges, exiting..."
    exit 1
fi

RULE=$(/sbin/devfs rule -s 4 show | grep -m 1 "tun\*" | cut -d ' ' -f 1)
if [[ -z $RULE ]]; then
    echo "The devfs fix is not in place..."
else
    echo $RULE
    echo "Removing temp devfs fix for tun in jails..."
    /sbin/devfs rule -s 4 del $RULE
fi
