#!/bin/bash
source ../common/utils.sh

PROP="unifi.properties"

require_root
require_file $PROP
check_blank2 $PROP jail_name jail_fqdn jail_interface jail_ip jail_mask jail_gateway jail_vnet

JAIL=$(prop $PROP jail_name)
FQDN=$(prop $PROP jail_fqdn)
INTERFACE=$(prop $PROP jail_interface)
IP=$(prop $PROP jail_ip)
MASK=$(prop $PROP jail_mask)
GATEWAY=$(prop $PROP jail_gateway)
VNET=$(prop $PROP jail_vnet)

# create the jail with base applications
echo Creating jail "${JAIL}" at ${IP}/${MASK}...
cat <<__EOF__ >/tmp/pkg.json
{
    "pkgs":[
        "nano","bash","openjdk8","snappyjava","mongodb36","llvm10"
    ]
}
__EOF__
iocage create \
    --name "${JAIL}" \
    -r 12.2-RELEASE \
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
make_port net-mgmt/unifi6

# set to start on boot
iocage exec ${JAIL} sysrc unifi_enable="YES"

# restart the whole jail to restart everything
iocage restart ${JAIL}

