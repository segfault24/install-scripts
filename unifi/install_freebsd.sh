#!/bin/sh
JAIL=unifi
FQDN=unifi.lan
INTERFACE=bridge0
IP=192.168.1.32/24
GATEWAY=192.168.1.1
VNET=off

if ! [ $(id -u) = 0 ]; then
    echo "This script must be run with root privileges"
    exit 1
fi

# create the jail with base applications
echo Creating jail "${JAIL}" at ${IP}...
cat <<__EOF__ >/tmp/pkg.json
{
    "pkgs":[
        "nano","bash","llvm40","openjdk8"
    ]
}
__EOF__
iocage create --name "${JAIL}" -r 11.1-RELEASE -p /tmp/pkg.json ip4_addr="${INTERFACE}|${IP}" defaultrouter="${GATEWAY}" boot="on" host_hostname="${JAIL}" vnet="${VNET}"
rm /tmp/pkg.json

# build the rest from ports
echo Building additional packages from ports...
make_port()
{
    for var in "$@"
    do
        iocage exec ${JAIL} make -C /usr/ports/$var install clean BATCH=yes
    done
}
iocage exec ${JAIL} "if [ -z /usr/ports ]; then portsnap fetch extract; else portsnap auto; fi"
make_port net-mgmt/unifi5

# set to start on boot
iocage exec ${JAIL} sysrc unifi_enable="YES"

# restart the whole jail to restart everything
iocage restart ${JAIL}

