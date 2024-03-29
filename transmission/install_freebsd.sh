#!/bin/bash
source ../common/utils.sh

PROP="transmission.properties"

require_root
require_file $PROP
check_blank2 $PROP jail_name jail_fqdn jail_interface jail_ip jail_mask jail_gateway jail_vnet
check_blank2 $PROP mount_src mount_dst mount_mode web_whitelist vpn_user vpn_pass

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

# web interface whitelist
WHITELIST=$(prop $PROP web_whitelist)

# pia vpn credentials
VPNUSER=$(prop $PROP vpn_user)
VPNPASS=$(prop $PROP vpn_pass)

RPCPASS=$(gen_passwd)

# create the jail with base applications
echo Creating jail "${JAIL}" at ${IP}/${MASK}...
cat <<__EOF__ >/tmp/pkg.json
{
    "pkgs":[
        "nano","bash","wget","ca_root_nss","openvpn","transmission-daemon","transmission-web"
    ]
}
__EOF__
iocage create \
    --name "${JAIL}" \
    -r 11.4-RELEASE \
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
iocage start ${JAIL}


# build the rest from ports
#init_ports

TRANSMISSION=/usr/local/etc/transmission/home
OPENVPN=/usr/local/etc/openvpn
IPFWSCRIPT=/usr/local/etc/ipfw.rules

# set sysrc settings
iocage exec ${JAIL} sysrc inet6_enable="NO"
iocage exec ${JAIL} sysrc ip6addrctl_enable="NO"
iocage exec ${JAIL} sysrc transmission_enable="YES"
iocage exec ${JAIL} sysrc transmission_download_dir="${DATADIR}"
#iocage exec ${JAIL} sysrc transmission_flags="--logfile /var/log/transmission/transmission.log"
iocage exec ${JAIL} sysrc openvpn_enable="YES"
iocage exec ${JAIL} sysrc openvpn_configfile="${OPENVPN}/openvpn.conf"
iocage exec ${JAIL} sysrc openvpn_if="tun"
iocage exec ${JAIL} sysrc firewall_enable="YES"
iocage exec ${JAIL} sysrc firewall_script="${IPFWSCRIPT}"

# map storage
iocage exec ${JAIL} mkdir -p ${DATADIR}
iocage fstab -a ${JAIL} ${DATASET} ${DATADIR} nullfs ${DATAMODE} 0 0

# start/stop to generate certain directories, files, etc
iocage exec ${JAIL} service transmission start
iocage exec ${JAIL} service transmission stop

# configure transmission
JAILROOT=/mnt/mypool/iocage/jails/${JAIL}/root
cp settings.json settings.json.tmp
TEMP=$(echo ${DATADIR} | sed "s/\//\\\\\//g")
sed -i '' "s/DATADIR/${TEMP}/g" settings.json.tmp
sed -i '' "s/RPCBINDADDRESS/${IP}/g" settings.json.tmp
sed -i '' "s/RPCPASSWORD/${RPCPASS}/g" settings.json.tmp
sed -i '' "s/RPCHOSTWL/${FQDN}/g" settings.json.tmp
sed -i '' "s/WHITELIST/${WHITELIST}/g" settings.json.tmp
iocage exec ${JAIL} mkdir -p ${TRANSMISSION}
install -m 644 settings.json.tmp ${JAILROOT}/${TRANSMISSION}/settings.json
iocage exec ${JAIL} chown transmission:transmission ${TRANSMISSION}/settings.json
rm settings.json.tmp
iocage exec ${JAIL} "install -d -m 750 -o transmission -g transmission /var/log/transmission/"

# configure openvpn
iocage exec ${JAIL} mkdir -p ${OPENVPN}/pia
iocage exec ${JAIL} wget -q https://www.privateinternetaccess.com/openvpn/openvpn.zip -O ${OPENVPN}/openvpn.zip
iocage exec ${JAIL} unzip ${OPENVPN}/openvpn.zip -d ${OPENVPN}/pia
iocage exec ${JAIL} cp ${OPENVPN}/pia/us_east.ovpn ${OPENVPN}/openvpn.conf
TEMP=$(echo ${OPENVPN} | sed "s/\//\\\\\//g")
iocage exec ${JAIL} sed -i '' "s/auth-user-pass/auth-user-pass ${TEMP}\\/pass.txt/g" ${OPENVPN}/openvpn.conf
iocage exec ${JAIL} sed -i '' "s/ca ca.rsa.2048.crt/ca ${TEMP}\\/ca.rsa.2048.crt/g" ${OPENVPN}/openvpn.conf
iocage exec ${JAIL} sed -i '' "s/crl-verify crl.rsa.2048.pem/crl-verify ${TEMP}\\/crl.rsa.2048.pem/g" ${OPENVPN}/openvpn.conf
iocage exec ${JAIL} "echo keepalive 10 60 >> ${OPENVPN}/openvpn.conf"
iocage exec ${JAIL} cp ${OPENVPN}/pia/ca.rsa.2048.crt ${OPENVPN}
iocage exec ${JAIL} cp ${OPENVPN}/pia/crl.rsa.2048.pem ${OPENVPN}
iocage exec ${JAIL} "echo ${VPNUSER} > ${OPENVPN}/pass.txt"
iocage exec ${JAIL} "echo ${VPNPASS} >> ${OPENVPN}/pass.txt"
iocage exec ${JAIL} chmod 400 ${OPENVPN}/pass.txt
iocage exec ${JAIL} chmod 400 ${OPENVPN}/openvpn.conf

# configure ipfw
install -m 750 -o root -g wheel ipfw.rules ${JAILROOT}/${IPFWSCRIPT}

# start up services
iocage exec ${JAIL} service ipfw start
iocage exec ${JAIL} service openvpn start
iocage exec ${JAIL} service transmission start

# set the rpc password
echo rpcpassword=${RPCPASS} > ${JAILROOT}/root/transmission.password
iocage exec ${JAIL} chmod 400 /root/transmission.password
echo \!\!\!\!\!\!\!\!\!\!
echo \!\!\!\!\!\!\!\!\!\!
echo See /root/transmission.password within the jail for the transmission password
echo \!\!\!\!\!\!\!\!\!\!
echo \!\!\!\!\!\!\!\!\!\!
echo Consider settings the following sysctl tunables on the host
echo "  kern.ipc.maxsockbuf = 5242880"
echo "  net.inet.udp.recvspace = 4194304"
echo \!\!\!\!\!\!\!\!\!\!
echo \!\!\!\!\!\!\!\!\!\!

# restart the whole jail to restart everything
iocage restart ${JAIL}
