#!/bin/bash
source ../common/utils.sh

JAIL=emby
FQDN=emby.lan
INTERFACE=bridge0
IP=
MASK=24
GATEWAY=192.168.1.1
VNET=off

DATASET=/mnt/mypool/media
DATADIR=/mnt/media

require_root
check_blank JAIL FQDN INTERFACE IP MASK GATEWAY VNET
check_blank DATASET DATADIR

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
iocage fstab -a ${JAIL} ${DATASET} ${DATADIR} nullfs ro 0 0

# set to start on boot
iocage exec ${JAIL} sysrc emby_server_enable="YES"

# start up services
iocage exec ${JAIL} service emby-server start

echo \!\!\!\!\!\!\!\!\!\!
echo \!\!\!\!\!\!\!\!\!\!
echo Go to http://${IP}:8096/ and configure Emby
echo \!\!\!\!\!\!\!\!\!\!
echo \!\!\!\!\!\!\!\!\!\!
