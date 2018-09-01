#!/bin/sh
JAIL=airsonic
FQDN=airsonic.lan
INTERFACE=bridge0
IP=192.168.1.27
MASK=24
GATEWAY=192.168.1.1
VNET=off

DATASET=/mnt/mypool/media/Music
DATADIR=/mnt/music

if ! [ $(id -u) = 0 ]; then
    echo "This script must be run with root privileges"
    exit 1
fi

PASS=$(openssl rand -base64 24 | grep -o '[[:alnum:]]' | tr -d '\n')

# create the jail with base applications
echo Creating jail "${JAIL}" at ${IP}/${MASK}...
cat <<__EOF__ >/tmp/pkg.json
{
    "pkgs":[
        "nano","bash","wget","ca_root_nss","tomcat8",
        "nasm","binutils","texi2html","frei0r","gmake","pkgconf",
        "perl5-5.26.2","gnutls","freetype2","fontconfig","gmp","ninja",
        "cmake","automake","autoconf","libtool","libiconv","xorg-macros"
    ]
}
__EOF__
iocage create \
    --name "${JAIL}" \
    -r 11.1-RELEASE \
    -p /tmp/pkg.json \
    host_hostname="${JAIL}" \
    vnet="${VNET}" \
    ip4_addr="${INTERFACE}|${IP}/${MASK}" \
    defaultrouter="${GATEWAY}" \
    boot="on"

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
iocage exec ${JAIL} "make config -C /usr/ports/multimedia/ffmpeg"
make_port multimedia/ffmpeg

# set to start on boot
iocage exec ${JAIL} sysrc tomcat8_enable="YES"

# configure tomcat
JAILROOT=/mnt/iocage/jails/${JAIL}/root
TOMCAT=/usr/local/apache-tomcat-8.0
cp tomcat-users.xml tomcat-users.xml.tmp
sed -i '' "s/ADMINPASSWORD/${PASS}/g" tomcat-users.xml.tmp
install -m 400 -o www -g www tomcat-users.xml.tmp ${JAILROOT}/${TOMCAT}/conf/tomcat-users.xml
rm tomcat-users.xml.tmp

# remove default tomcat deployments
iocage exec ${JAIL} rm -rf ${TOMCAT}/webapps/ROOT
iocage exec ${JAIL} rm -rf ${TOMCAT}/webapps/docs
iocage exec ${JAIL} rm -rf ${TOMCAT}/webapps/examples
iocage exec ${JAIL} rm -rf ${TOMCAT}/webapps/host-manager

# setup airsonic directory
iocage exec ${JAIL} mkdir -m 755 -p /var/airsonic/transcode
iocage exec ${JAIL} chown -R www:www /var/airsonic
iocage exec ${JAIL} ln -s /usr/local/bin/ffmpeg /var/airsonic/transcode/ffmpeg

# install airsonic
WAR_URL=https://github.com/airsonic/airsonic/releases/download/v10.1.2/airsonic.war
iocage exec ${JAIL} wget ${WAR_URL} -O ${TOMCAT}/webapps/airsonic.war
iocage exec ${JAIL} chown www:www ${TOMCAT}/webapps/airsonic.war

# map storage
iocage fstab -a ${JAIL} ${DATASET} ${DATADIR} nullfs ro 0 0

# save admin password
echo username=admin > ${JAILROOT}/root/tomcat.password
echo password=${PASS} >> ${JAILROOT}/root/tomcat.password
iocage exec ${JAIL} chmod 400 /root/tomcat.password
echo \!\!\!\!\!\!\!\!\!\!
echo \!\!\!\!\!\!\!\!\!\!
echo See /root/tomcat.password within the jail for the Tomcat admin password
echo \!\!\!\!\!\!\!\!\!\!
echo \!\!\!\!\!\!\!\!\!\!
echo Go to http://${IP}:8080/airsonic and change the Airsonic admin password
echo \!\!\!\!\!\!\!\!\!\!
echo \!\!\!\!\!\!\!\!\!\!

# restart jail to start tomcat and deploy airsonic
iocage restart ${JAIL}
