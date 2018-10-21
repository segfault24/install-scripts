#!/bin/bash
source ../utils/utils.sh

JAIL=unifi
FQDN=unifi.lan
INTERFACE=bridge0
IP=192.168.1.32
MASK=24
GATEWAY=192.168.1.1
VNET=off

require_root
check_blank JAIL FQDN INTERFACE IP MASK GATEWAY VNET

# create the jail with base applications
echo Creating jail "${JAIL}" at ${IP}/${MASK}...
cat <<__EOF__ >/tmp/pkg.json
{
    "pkgs":[
        "nano","bash","llvm40","openjdk8","snappyjava","mongodb34"
    ]
}
__EOF__
iocage create \
    --name "${JAIL}" \
    -r 11.2-RELEASE \
    -p /tmp/pkg.json \
    host_hostname="${JAIL}" \
    vnet="${VNET}" \
    ip4_addr="${INTERFACE}|${IP}/${MASK}" \
    defaultrouter="${GATEWAY}" \
    boot="on"
if [[ $? -ne 0 ]]; then
    echo "Failed to create jail ${JAIL}"
    exit 1
fi
rm /tmp/pkg.json

# build the rest from ports
init_ports
make_port ports-mgmt/portmaster
make_port net-mgmt/unifi5

# set to start on boot
iocage exec ${JAIL} sysrc unifi_enable="YES"

# restart the whole jail to restart everything
iocage restart ${JAIL}

