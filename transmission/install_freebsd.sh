#!/bin/sh
JAIL=transmission
FQDN=transmission.lan
INTERFACE=vnet0
IP=192.168.1.24
MASK=24
GATEWAY=192.168.1.1
VNET=on

# dataset location
DATASET=/mnt/mypool/media/New
# mount point within jail
DATADIR=/mnt/downloads
# whitelist for client access
WHITELIST='127.0.0.1,192.168.\*.\*'

# pia vpn credentials
VPNUSER=
VPNPASS=

if ! [ $(id -u) = 0 ]; then
    echo "This script must be run with root privileges"
    exit 1
fi

RPCPASS=$(openssl rand -base64 24 | grep -o '[[:alnum:]]' | tr -d '\n')

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
    -r 11.2-RELEASE \
    -p /tmp/pkg.json \
    host_hostname="${JAIL}" \
    vnet="${VNET}" \
    ip4_addr="${INTERFACE}|${IP}/${MASK}" \
    defaultrouter="${GATEWAY}" \
    boot="off"

rm /tmp/pkg.json

# build the rest from ports
#echo Building additional packages from ports...
#make_port()
#{
#    for var in "$@"
#    do
#        iocage exec ${JAIL} make -C /usr/ports/$var install clean BATCH=yes
#    done
#}
#iocage exec ${JAIL} "if [ -z /usr/ports ]; then portsnap fetch extract; else portsnap auto; fi"
#make_port devel/php-composer

TRANSMISSION=/usr/local/etc/transmission/home
OPENVPN=/usr/local/etc/openvpn
IPFWSCRIPT=/usr/local/etc/ipfw.rules

# set sysrc settings
iocage exec ${JAIL} sysrc inet6_enable="NO"
iocage exec ${JAIL} sysrc ip6addrctl_enable="NO"
iocage exec ${JAIL} sysrc transmission_enable="YES"
iocage exec ${JAIL} sysrc transmission_download_dir="${DATADIR}"
iocage exec ${JAIL} sysrc openvpn_enable="YES"
iocage exec ${JAIL} sysrc openvpn_configfile="${OPENVPN}/openvpn.conf"
iocage exec ${JAIL} sysrc openvpn_if="tun"
iocage exec ${JAIL} sysrc firewall_enable="YES"
iocage exec ${JAIL} sysrc firewall_script="${IPFWSCRIPT}"

# map storage
iocage fstab -a ${JAIL} ${DATASET} ${DATADIR} nullfs rw 0 0

# start/stop to generate certain directories, files, etc
iocage exec ${JAIL} service transmission start
iocage exec ${JAIL} service transmission stop

# configure transmission
JAILROOT=/mnt/iocage/jails/${JAIL}/root
cp settings.json settings.json.tmp
sed -i '' "s/BINDADDRESS/${IP}/g" settings.json.tmp
TEMP=$(echo ${DATADIR} | sed "s/\//\\\\\//g")
sed -i '' "s/DATADIR/${TEMP}/g" settings.json.tmp
sed -i '' "s/RPCPASSWORD/${RPCPASS}/g" settings.json.tmp
sed -i '' "s/RPCHOSTWL/${FQDN}/g" settings.json.tmp
sed -i '' "s/WHITELIST/${WHITELIST}/g" settings.json.tmp
install -m 644 settings.json.tmp ${JAILROOT}/${TRANSMISSION}/settings.json
iocage exec ${JAIL} chown transmission:transmission ${TRANSMISSION}/settings.json
rm settings.json.tmp

# configure openvpn
iocage exec ${JAIL} mkdir -p ${OPENVPN}/pia
iocage exec ${JAIL} wget -q https://www.privateinternetaccess.com/openvpn/openvpn.zip -O ${OPENVPN}/openvpn.zip
iocage exec ${JAIL} unzip ${OPENVPN}/openvpn.zip -d ${OPENVPN}/pia
iocage exec ${JAIL} cp ${OPENVPN}/pia/US\ East.ovpn ${OPENVPN}/openvpn.conf
TEMP=$(echo ${OPENVPN} | sed "s/\//\\\\\//g")
iocage exec ${JAIL} sed -i '' "s/auth-user-pass/auth-user-pass ${TEMP}\\/pass.txt/g" ${OPENVPN}/openvpn.conf
iocage exec ${JAIL} sed -i '' "s/ca ca.rsa.2048.crt/ca ${TEMP}\\/ca.rsa.2048.crt/g" ${OPENVPN}/openvpn.conf
iocage exec ${JAIL} sed -i '' "s/crl-verify crl.rsa.2048.pem/crl-verify ${TEMP}\\/crl.rsa.2048.pem/g" ${OPENVPN}/openvpn.conf
iocage exec ${JAIL} "echo keepalive 10 60 >> ${OPENVPN}/openvpn.conf"
iocage exec ${JAIL} cp ${OPENVPN}/pia/ca.rsa.2048.crt ${OPENVPN}
iocage exec ${JAIL} cp ${OPENVPN}/pia/crl.rsa.2048.pem ${OPENVPN}
iocage exec ${JAIL} "echo ${VPNUSER} > ${OPENVPN}/pass.txt"
iocage exec ${JAIL} "echo ${VPNPASS} >> ${OPENVPN}/pass.txt"
iocage exec ${JAIL} chmod 400 ${OPENVPN}/openvpn.conf

# configure ipfw
install -m 750 -o root -g wheel ipfw.rules ${JAILROOT}/${IPFWSCRIPT}

# copy helper script
install -m 750 -o root -g wheel test_vpn.sh ${JAILROOT}/root

# start up services
#iocage exec ${JAIL} service openvpn start
#iocage exec ${JAIL} service transmission start

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
#iocage restart ${JAIL}
iocage stop ${JAIL}
