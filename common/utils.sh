#!/bin/bash

# get property from file (ex:  echo $(prop 'amp.properties' 'apache.user')  )
prop() {
    grep "${2}" ${1} | cut -d'=' -f2
}

# ensure the script is running as root, otherwise exit
require_root() {
    if ! [ $(id -u) = 0 ]; then
        echo "This script must be run with root privileges, exiting..."
        exit 1
    fi
}

# ensure the given file exists
require_file() {
    if [ ! -f $1 ]; then
        echo "The file '$1' does not exist, exiting..."
        exit 1
    fi
}

# checks if param exists
check_blank() {
    for var in "$@"; do
        if [[ -z "${!var}" ]]; then
            echo "You must set the script parameter '$var', exiting..."
            exit 1
        fi
    done
}

# checks if the property is set
check_blank2() {
    for var in "${@:2}"; do
        if [[ -z "$(prop $1 $var)" ]]; then
            echo "You must set the property '$var', exiting..."
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
    iocage exec ${JAIL} "make install clean -C /usr/ports/ports-mgmt/portmaster BATCH=yes"
    echo Ports tree intialized
}

# configure port(s)
config_port() {
    for var in "$@"; do
        echo Configuring port $var
        iocage exec ${JAIL} "make config -C /usr/ports/$var"
    done
}

# batch make and install port(s)
make_port() {
    for var in "$@"; do
        echo Building port $var
        iocage exec ${JAIL} "make install clean -C /usr/ports/$var BATCH=yes"
        #iocage exec ${JAIL} "portmaster --packages -y /usr/ports/$var"
    done
}

# install from packages
install_pkg() {
    iocage exec ${JAIL} "pkg install -q -y $@"
}

# escape the given path for use with sed
esc_path() {
    echo -n $(echo -n $1 | sed "s/\//\\\\\//g")
}

# create jail from parameters
#  1: release
#  2: jail name
#  3: interface
#  4: ip
#  5: mask (subnet)
#  6: gateway
#  7: vnet
# ex: create_jail 11.2-RELEASE testjail bridge0 192.168.6.60 24 192.168.6.1 off
create_jail() {
    if [[ $# -ne 7 ]]; then
        echo "create_jail requires 7 parameters"
        exit 1
    fi

    echo "Creating jail \"$2\" at ${IP}/${MASK}..."
    echo '{"pkgs":["nano","bash","wget","ca_root_nss"]}' > /tmp/${2}-pkg.json
    iocage create \
        --name "$2" \
        -r "$1" \
        -p /tmp/${2}-pkg.json \
        host_hostname="$2" \
        vnet="$7" \
        ip4_addr="$3|$4/$5" \
        defaultrouter="$6" \
        boot="on"
    if [[ $? -ne 0 ]]; then
        rm /tmp/${2}-pkg.json
        echo "Failed to create jail \"$2\", exiting..."
        exit 1
    else
        rm /tmp/${2}-pkg.json
    fi
}
