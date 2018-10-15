#!/bin/bash

sudo devfs rule -s 4 show | grep "tun\*"
if [[ $? != 0 ]]; then
    echo "Applying temp devfs fix before jail start..."
    sudo devfs rule -s 4 add path 'tun*' unhide
else
    echo "The devfs fix is already in place..."
fi
sudo iocage start transmission
