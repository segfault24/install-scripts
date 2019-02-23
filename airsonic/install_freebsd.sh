#!/bin/bash
source ../common/utils.sh

PROP="airsonic.properties"

require_root
require_file $PROP
check_blank2 $PROP jail_name jail_fqdn jail_interface jail_ip jail_mask jail_gateway jail_vnet
check_blank2 $PROP mount_src mount_dst mount_mode ext_ssl ext_fqdn

JAIL_VERSION=11.2-RELEASE
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

EXTSSL=$(prop $PROP ext_ssl)
EXTFQDN=$(prop $PROP ext_fqdn)

PASS=$(gen_passwd)

# create the jail & install packages
create_jail ${JAIL_VERSION} ${JAIL} ${INTERFACE} ${IP} ${MASK} ${GATEWAY} ${VNET}
install_pkg "tomcat8"

# ffmpeg build & run dependencies
install_pkg "nasm binutils frei0r gmake pkgconf libiconv perl5 fontconfig freetype2 gmp gnutls"
install_pkg "libxcb opus libtheora libvorbis libvpx nginx"
#sub dep?: texi2html cmake automake autoconf libtool xorg-macros
init_ports
config_port multimedia/ffmpeg
make_port multimedia/ffmpeg

# set to start on boot
iocage exec ${JAIL} sysrc tomcat8_enable="YES"
iocage exec ${JAIL} sysrc nginx_enable="YES"

# configure tomcat
JAILROOT=/mnt/iocage/jails/${JAIL}/root
TOMCAT=/usr/local/apache-tomcat-8.0
cp tomcat-users.xml tomcat-users.xml.tmp
sed -i '' "s/ADMINPASSWORD/${PASS}/g" tomcat-users.xml.tmp
install -m 400 -o www -g www tomcat-users.xml.tmp ${JAILROOT}/${TOMCAT}/conf/tomcat-users.xml
rm tomcat-users.xml.tmp

# configure nginx
NGINX=/usr/local/etc/nginx
cp nginx.conf nginx.conf.tmp
sed -i '' "s/SERVERNAME/${EXTFQDN}/g" nginx.conf.tmp
install -m 640 -o root -g wheel nginx.conf.tmp ${JAILROOT}/${NGINX}/nginx.conf
rm nginx.conf.tmp

#if [ $EXTSSL -eq "letsencrypt" ]
#then
#  iocage exec ${JAIL} "pkg install -y py27-certbot"
#  iocage exec ${JAIL}
#else
  # generate self signed cert
  SUBJ="/C=US/ST=New\ York/L=New\ York/O=The\ Ether/CN=${EXTFQDN}"
  KEYOUT=${NGINX}/key.pem
  CRTOUT=${NGINX}/cert.pem
  iocage exec ${JAIL} "openssl req -x509 -nodes -days 1095 -newkey rsa:2048 -keyout ${KEYOUT} -out ${CRTOUT} -subj ${SUBJ}"
  iocage exec ${JAIL} chmod 400 ${KEYOUT} ${CRTOUT}
#fi

# remove default tomcat deployments
iocage exec ${JAIL} rm -rf ${TOMCAT}/webapps/ROOT
iocage exec ${JAIL} rm -rf ${TOMCAT}/webapps/docs
iocage exec ${JAIL} rm -rf ${TOMCAT}/webapps/examples
iocage exec ${JAIL} rm -rf ${TOMCAT}/webapps/host-manager

# setup airsonic directory
iocage exec ${JAIL} mkdir -m 755 -p /var/airsonic/transcode
iocage exec ${JAIL} chown -R www:www /var/airsonic
iocage exec ${JAIL} ln -s /usr/local/bin/ffmpeg /var/airsonic/transcode/ffmpeg
iocage exec ${JAIL} "install -m 750 -o www -g www -d /var/music"

# install airsonic
WAR_URL=https://github.com/airsonic/airsonic/releases/download/v10.2.1/airsonic.war
iocage exec ${JAIL} wget ${WAR_URL} -O ${TOMCAT}/webapps/airsonic.war
iocage exec ${JAIL} chown www:www ${TOMCAT}/webapps/airsonic.war

# map storage
iocage fstab -a ${JAIL} ${DATASET} ${DATADIR} nullfs ${DATAMODE} 0 0

# save admin password
echo username=admin > ${JAILROOT}/root/tomcat.password
echo password=${PASS} >> ${JAILROOT}/root/tomcat.password
iocage exec ${JAIL} chmod 400 /root/tomcat.password
echo \!\!\!\!\!\!\!\!\!\!
echo \!\!\!\!\!\!\!\!\!\!
echo See /root/tomcat.password within the jail for the Tomcat admin password
echo \!\!\!\!\!\!\!\!\!\!
echo \!\!\!\!\!\!\!\!\!\!
echo "Go change the Airsonic admin password"
echo "      local: https://${IP}/airsonic"
echo "   external: https://${FQDN}/airsonic"
echo \!\!\!\!\!\!\!\!\!\!
echo \!\!\!\!\!\!\!\!\!\!

# restart jail to start tomcat and deploy airsonic
iocage restart ${JAIL}
