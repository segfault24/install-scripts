#!/bin/bash
source ../common/utils.sh

PROP="minecraft.properties"

require_root
require_file $PROP
check_blank2 $PROP jail_name jail_fqdn jail_interface jail_ip jail_mask jail_gateway jail_vnet
#check_blank2 $PROP ext_ssl ext_fqdn

JAIL_VERSION=11.2-RELEASE
JAIL=$(prop $PROP jail_name)
FQDN=$(prop $PROP jail_fqdn)
INTERFACE=$(prop $PROP jail_interface)
IP=$(prop $PROP jail_ip)
MASK=$(prop $PROP jail_mask)
GATEWAY=$(prop $PROP jail_gateway)
VNET=$(prop $PROP jail_vnet)

EXTSSL=$(prop $PROP ext_ssl)
EXTFQDN=$(prop $PROP ext_fqdn)

VANILLAJAR=minecraft-server-12.2.jar
FORGEVER=1.12.2-14.23.5.2836
FORGEJAR=forge-${FORGEVER}-universal.jar
FORGEINSTALLER=forge-${FORGEVER}-installer.jar

# create the jail & install packages
create_jail ${JAIL_VERSION} ${JAIL} ${INTERFACE} ${IP} ${MASK} ${GATEWAY} ${VNET}
install_pkg "bash nano screen openjdk8-jre"

# setup minecraft directories
JAILROOT=/mnt/iocage/jails/${JAIL}/root
VANILLA=/srv/minecraft/vanilla
MODDED=/srv/minecraft/modded

install -m 750 -d ${JAILROOT}/${VANILLA}
install -m 640 src/README ${JAILROOT}/${VANILLA}
install -m 750 src/run-server.sh ${JAILROOT}/${VANILLA}
install -m 750 src/render-map.sh ${JAILROOT}/${VANILLA}
install -m 640 src/mapper.conf ${JAILROOT}/${VANILLA}
install -m 640 lib/${VANILLAJAR} ${JAILROOT}/${VANILLA}
iocage exec ${JAIL} "ln -s ${VANILLA}/${VANILLAJAR} ${VANILLA}/server.jar"

install -m 750 -d ${JAILROOT}/${MODDED}
install -m 750 -d ${JAILROOT}/${MODDED}/mods
install -m 640 src/README ${JAILROOT}/${MODDED}
install -m 750 src/run-server.sh ${JAILROOT}/${MODDED}
install -m 750 src/render-map.sh ${JAILROOT}/${MODDED}
install -m 640 src/mapper.conf ${JAILROOT}/${MODDED}
install -m 640 mods/* ${JAILROOT}/${MODDED}/mods
install -m 640 lib/${FORGEJAR} ${JAILROOT}/${MODDED}
install -m 640 lib/${FORGEINSTALLER} ${JAILROOT}/${MODDED}
iocage exec ${JAIL} "ln -s ${MODDED}/${FORGEJAR} ${MODDED}/server.jar"

# setup www directory
WEBROOT=/srv/www
install -m 750 -d ${JAILROOT}/${WEBROOT}
install -m 640 www/index.html ${JAILROOT}/${WEBROOT}
install -m 640 www/*.png ${JAILROOT}/${WEBROOT}
install -m 750 -d ${JAILROOT}/${WEBROOT}/vanilla
install -m 750 -d ${JAILROOT}/${WEBROOT}/modded

# cron jobs
#2,15,30,45 * * * * /srv/minecraft/vanilla/render-map.sh
#5,20,35,50 * * * * /srv/minecraft/modded/render-map.sh

