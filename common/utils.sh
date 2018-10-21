#!/bin/bash

# ensure the script is running as root, otherwise exit
require_root() {
    if ! [ $(id -u) = 0 ]; then
        echo "This script must be run with root privileges, exiting..."
        exit 1
    fi
}

# checks if param exists
check_blank() {
    for var in "$@"; do
        if [[ -z "${!var}" ]]; then
            echo "You must set the script parameter $var"
            exit 1
        fi
    done
}

# generate a password, alphanumeric (~24 characters)
gen_passwd() {
    echo -n $(openssl rand -base64 24 | grep -o '[[:alnum:]]' | tr -d '\n')
}

# load the ports tree if it doesn't already exist, otherwise update it
init_ports() {
    echo Initializing ports tree...
    iocage exec ${JAIL} "if [ -z /usr/ports ]; then portsnap fetch extract; else portsnap auto; fi" > /dev/null
    echo Ports tree intialized
}

# configure port(s)
config_port() {
    for var in "$@"; do
        echo Configuring port $var
        iocage exec ${JAIL} make config -C /usr/ports/$var
    done
}

# batch make and install port(s)
make_port() {
    for var in "$@"; do
        echo Building port $var
        iocage exec ${JAIL} make install clean -C /usr/ports/$var BATCH=yes
    done
}

# escape the given path for use with sed
esc_path() {
    echo -n $(echo -n $1 | sed "s/\//\\\\\//g")
}

