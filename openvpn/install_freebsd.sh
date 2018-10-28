#!/bin/bash
source ../common/utils.sh

JAIL=openvpn
FQDN=openvpn.lan
INTERFACE=vnet0
IP=
MASK=24
GATEWAY=192.168.1.1
VNET=on

CLIENTNET=192.168.2.0
CLIENTMASK=255.255.255.0
CLIENTDNS=192.168.1.1

require_root
check_blank JAIL FQDN INTERFACE IP MASK GATEWAY VNET
check_blank CLIENTNET CLIENTMASK CLIENTDNS

# create the jail with base applications
echo Creating jail "${JAIL}" at ${IP}/${MASK}...
cat <<__EOF__ >/tmp/pkg.json
{
    "pkgs":[
        "nano","bash","openvpn"
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
    boot="on" \
    allow_tun="1"
if [[ $? -ne 0 ]]; then
    echo "Failed to create jail ${JAIL}"
    exit 1
fi
rm /tmp/pkg.json

# build the rest from ports
#init_ports

JAILROOT=/mnt/iocage/jails/${JAIL}/root
OPENVPN=/usr/local/etc/openvpn
IPFWSCRIPT=/usr/local/etc/ipfw.rules

# set sysrc settings
iocage exec ${JAIL} sysrc openvpn_enable="YES"
iocage exec ${JAIL} sysrc openvpn_configfile="${OPENVPN}/server.conf"
iocage exec ${JAIL} sysrc openvpn_if="tun"
iocage exec ${JAIL} sysrc firewall_enable="YES"
iocage exec ${JAIL} sysrc firewall_script="${IPFWSCRIPT}"

# generate ca and server certs
iocage exec ${JAIL} cp -r /usr/local/share/easy-rsa /root
install -m 400 -o root -g wheel vars ${JAILROOT}/root/easy-rsa
iocage exec ${JAIL} "cd /root/easy-rsa && ./easyrsa.real init-pki"
iocage exec ${JAIL} "cd /root/easy-rsa && ./easyrsa.real build-ca nopass"
iocage exec ${JAIL} "cd /root/easy-rsa && ./easyrsa.real build-server-full server nopass"

# configure openvpn
cp server.conf server.conf.tmp
sed -i '' "s/CLIENTNET/${CLIENTNET}/g" server.conf.tmp
sed -i '' "s/CLIENTMASK/${CLIENTMASK}/g" server.conf.tmp
sed -i '' "s/CLIENTDNS/${CLIENTDNS}/g" server.conf.tmp
sed -i '' "s/SERVERIP/${IP}/g" server.conf.tmp
iocage exec ${JAIL} mkdir -p ${OPENVPN}
install -m 400 -o root -g wheel server.conf.tmp ${JAILROOT}/${OPENVPN}/server.conf
iocage exec ${JAIL} "openssl dhparam 2048 -out ${OPENVPN}/dh2048.pem"
iocage exec ${JAIL} openvpn --genkey --secret ${OPENVPN}/ta.key
iocage exec ${JAIL} cp /root/easy-rsa/pki/ca.crt ${OPENVPN}
iocage exec ${JAIL} cp /root/easy-rsa/pki/private/server.key ${OPENVPN}
iocage exec ${JAIL} cp /root/easy-rsa/pki/issued/server.crt ${OPENVPN}

# configure ipfw
install -m 750 -o root -g wheel ipfw.rules ${JAILROOT}/${IPFWSCRIPT}

# start up services
iocage exec ${JAIL} service openvpn start
iocage exec ${JAIL} service ipfw start
