#!/bin/sh
JAIL=airsonic
FQDN=airsonic.lan
INTERFACE=bridge0
IP=192.168.1.27
MASK=24
GATEWAY=192.168.1.1
VNET=off

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
        "nano","bash","wget","ca_root_nss","tomcat8"
    ]
}
__EOF__
iocage create --name "${JAIL}" -r 11.1-RELEASE -p /tmp/pkg.json ip4_addr="${INTERFACE}|${IP}/${MASK}" defaultrouter="${GATEWAY}" boot="on" host_hostname="${JAIL}" vnet="${VNET}"
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

# set to start on boot
iocage exec ${JAIL} sysrc tomcat8_enable="YES"

# configure tomcat
JAILROOT=/mnt/iocage/jails/${JAIL}/root
TOMCAT=/usr/local/apache-tomcat-8.0
cp tomcat-users.xml tomcat-users.xml.tmp
sed -i '' "s/ADMINPASSWORD/${PASS}/g" tomcat-users.xml.tmp
install -m 400 -o www -g www tomcat-users.xml.tmp ${JAILROOT}/${TOMCAT}/conf/tomcat-users.xml
rm tomcat-users.xml.tmp

# setup data directory
iocage exec ${JAIL} mkdir -m 755 /var/airsonic
iocage exec ${JAIL} chown -R www:www /var/airsonic

# install airsonic
WAR_URL=https://github.com/airsonic/airsonic/releases/download/v10.1.2/airsonic.war
iocage exec ${JAIL} wget ${WAR_URL} -O ${TOMCAT}/webapps/airsonic.war
iocage exec ${JAIL} chown www:www ${TOMCAT}/webapps/airsonic.war

# remove default tomcat deployments
iocage exec ${JAIL} rm -rf ${TOMCAT}/webapps/ROOT
iocage exec ${JAIL} rm -rf ${TOMCAT}/webapps/docs
iocage exec ${JAIL} rm -rf ${TOMCAT}/webapps/examples

# start up services
iocage exec ${JAIL} service tomcat8 start

# deploy airsonic
iocage exec ${JAIL} wget -O - -q http://admin:${PASS}@${IP}:8080/manager/text/deploy?path=/airsonic&war=file:/${TOMCAT}/webapps/airsonic.war

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

# restart the whole jail to restart everything
iocage restart ${JAIL}
