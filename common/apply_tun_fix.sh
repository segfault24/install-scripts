#!/bin/bash

if ! [ $(id -u) = 0 ]; then
    echo "This script must be run with root privileges, exiting..."
    exit 1
fi

/sbin/devfs rule -s 4 show | grep "tun\*"
if [[ $? != 0 ]]; then
    echo "Applying temp devfs fix for tun in jails..."
    /sbin/devfs rule -s 4 add path 'tun*' unhide
else
    echo "The devfs fix is already in place..."
fi
