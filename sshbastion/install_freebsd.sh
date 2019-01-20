#!/bin/bash
source ../common/utils.sh

PROP="sshbastion.properties"

require_root
require_file $PROP
check_blank2 $PROP jail_name jail_fqdn jail_interface jail_ip jail_mask jail_gateway jail_vnet
check_blank2 $PROP bastion_user

JAIL=$(prop $PROP jail_name)
FQDN=$(prop $PROP jail_fqdn)
INTERFACE=$(prop $PROP jail_interface)
IP=$(prop $PROP jail_ip)
MASK=$(prop $PROP jail_mask)
GATEWAY=$(prop $PROP jail_gateway)
VNET=$(prop $PROP jail_vnet)

BASTIONUSER=$(prop $PROP bastion_user)

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
iocage exec ${JAIL} pw useradd ${BASTIONUSER} -m -s /usr/local/bin/bash -w random

# configure ipfw
install -m 750 -o root -g wheel ipfw.rules ${JAILROOT}/${IPFWSCRIPT}

# start up services
iocage exec ${JAIL} service sshd start
iocage exec ${JAIL} service ipfw start
