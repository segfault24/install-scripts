#!/bin/bash
source ../common/utils.sh

PROP="jenkins.properties"

require_root
require_file $PROP
check_blank2 $PROP jail_name jail_fqdn jail_interface jail_ip jail_mask jail_gateway jail_vnet

JAIL_VERSION=11.2-RELEASE
JAIL=$(prop $PROP jail_name)
FQDN=$(prop $PROP jail_fqdn)
INTERFACE=$(prop $PROP jail_interface)
IP=$(prop $PROP jail_ip)
MASK=$(prop $PROP jail_mask)
GATEWAY=$(prop $PROP jail_gateway)
VNET=$(prop $PROP jail_vnet)

PASS=$(gen_passwd)

# create the jail & install packages
create_jail ${JAIL_VERSION} ${JAIL} ${INTERFACE} ${IP} ${MASK} ${GATEWAY} ${VNET}
install_pkg nano bash jenkins git ant \
    php72 php72-ctype php72-curl php72-dom php72-filter php72-hash \
    php72-iconv php72-json php72-mbstring php72-mysqli php72-openssl \
    php72-pdo php72-pdo_mysql php72-phar php72-session php72-tokenizer \
    php72-xmlwriter php72-zlib
init_ports
make_port devel/php-composer

# set to start on boot
iocage exec ${JAIL} sysrc jenkins_enable="YES"

# start jenkins
service jenkins start

echo \!\!\!\!\!\!\!\!\!\!
echo See /usr/local/jenkins/secrets/initialAdminPassword within the jail for the Jenkins admin password
echo \!\!\!\!\!\!\!\!\!\!
echo \!\!\!\!\!\!\!\!\!\!
echo "Go finish setting up Jenkins and change the admin password"
echo "      local: http://${IP}:8180/jenkins"
echo \!\!\!\!\!\!\!\!\!\!
echo \!\!\!\!\!\!\!\!\!\!
