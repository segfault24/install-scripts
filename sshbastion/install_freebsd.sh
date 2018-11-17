#!/bin/bash
source ../common/utils.sh

JAIL=bastion
FQDN=bastion.lan
INTERFACE=vnet0
IP=
MASK=24
GATEWAY=192.168.1.1
VNET=on

BASTIONUSER=remoteuser

require_root
check_blank JAIL FQDN INTERFACE IP MASK GATEWAY VNET
check_blank BASTIONUSER

# create the jail with base applications
echo Creating jail "${JAIL}" at ${IP}/${MASK}...
cat <<__EOF__ >/tmp/pkg.json
{
    "pkgs":[
        "nano","bash"
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
    boot="off"
if [[ $? -ne 0 ]]; then
    echo "Failed to create jail ${JAIL}"
    exit 1
fi
rm /tmp/pkg.json

# build the rest from ports
#init_ports
#make_port security/sshguard

IPFWSCRIPT=/usr/local/etc/ipfw.rules

# set sysrc settings
iocage exec ${JAIL} sysrc inet6_enable="NO"
iocage exec ${JAIL} sysrc ip6addrctl_enable="NO"
iocage exec ${JAIL} sysrc sshd_enable="YES"
iocage exec ${JAIL} sysrc firewall_enable="YES"
iocage exec ${JAIL} sysrc firewall_script="${IPFWSCRIPT}"

JAILROOT=/mnt/iocage/jails/${JAIL}/root

# configure sshd
cp sshd_config sshd_config.tmp
sed -i '' "s/SERVERIP/${IP}/g" sshd_config.tmp
install -m 644 -o root -g wheel sshd_config.tmp ${JAILROOT}/etc/ssh/sshd_config
rm sshd_config.tmp

# add user
iocage exec ${JAIL} pw useradd ${BASTIONUSER} -m -s /bin/bash -w random

# configure ipfw
install -m 750 -o root -g wheel ipfw.rules ${JAILROOT}/${IPFWSCRIPT}

# start up services
iocage exec ${JAIL} service sshd start
iocage exec ${JAIL} service ipfw start
