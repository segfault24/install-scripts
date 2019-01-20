#!/bin/bash
source ../common/utils.sh

PROP="emby.properties"

require_root
require_file $PROP
check_blank2 $PROP jail_name jail_fqdn jail_interface jail_ip jail_mask jail_gateway jail_vnet
check_blank2 $PROP mount_src mount_dst mount_mode

JAIL=$(prop $PROP jail_name)
FQDN=$(prop $PROP jail_fqdn)
INTERFACE=$(prop $PROP jail_interface)
IP=$(prop $PROP jail_ip)
MASK=$(prop $PROP jail_mask)
GATEWAY=$(prop $PROP jail_gateway)
VNET=$(prop $PROP jail_vnet)

DATASET=$(prop $PROP mount_src)
DATADIR=$(prop $PROP mount_dst)
DATAMODE=$(prop $PROP mount_mode)

# create the jail with base applications
echo Creating jail "${JAIL}" at ${IP}/${MASK}...
cat <<__EOF__ >/tmp/pkg.json
{
    "pkgs":[
        "nano","bash","msbuild","mono","pkgconf","ImageMagick","sqlite3","ffmpeg"
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
make_port multimedia/emby-server

# map storage
iocage fstab -a ${JAIL} ${DATASET} ${DATADIR} nullfs ${DATAMODE} 0 0

# set to start on boot
iocage exec ${JAIL} sysrc emby_server_enable="YES"

# start up services
iocage exec ${JAIL} service emby-server start

echo \!\!\!\!\!\!\!\!\!\!
echo \!\!\!\!\!\!\!\!\!\!
echo Go to http://${IP}:8096/ and configure Emby
echo \!\!\!\!\!\!\!\!\!\!
echo \!\!\!\!\!\!\!\!\!\!
