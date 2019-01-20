#!/bin/bash
source ../common/utils.sh

PROP="amp.properties"

require_root
require_file $PROP
check_blank2 $PROP jail_name jail_fqdn jail_interface jail_ip jail_mask jail_gateway jail_vnet

JAIL=$(prop $PROP jail_name)
FQDN=$(prop $PROP jail_fqdn)
INTERFACE=$(prop $PROP jail_interface)
IP=$(prop $PROP jail_ip)
MASK=$(prop $PROP jail_mask)
GATEWAY=$(prop $PROP jail_gateway)
VNET=$(prop $PROP jail_vnet)

DB_ROOT_PASSWORD=$(gen_passwd)

# create the jail with base applications
echo Creating jail "${JAIL}" at ${IP}/${MASK}...
cat <<__EOF__ >/tmp/pkg.json
{
    "pkgs":[
        "nano","bash","wget","curl","sudo","apache24","mod_php72","mariadb102-server",
        "php72","php72-ctype","php72-curl","php72-dom","php72-filter","php72-hash",
        "php72-iconv","php72-json","php72-mbstring","php72-mysqli","php72-openssl",
        "php72-pdo","php72-pdo_mysql","php72-phar","php72-session","php72-tokenizer",
        "php72-xmlwriter","php72-zlib"
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
    boot="on"
if [[ $? -ne 0 ]]; then
    echo "Failed to create jail ${JAIL}"
    exit 1
fi
rm /tmp/pkg.json

# set to start on boot
iocage exec ${JAIL} sysrc mysql_enable="YES"
iocage exec ${JAIL} sysrc apache24_enable="YES"

# configure apache
JAILROOT=/mnt/iocage/jails/${JAIL}/root
APACHE=/usr/local/etc/apache24
iocage exec ${JAIL} mkdir -m 755 ${APACHE}/conf-enabled
iocage exec ${JAIL} mkdir -m 755 ${APACHE}/sites-enabled
cp httpd-freebsd.conf httpd-freebsd.conf.tmp
cp default-site.conf default-site.conf.tmp
sed -i '' "s/example.com/${FQDN}/g" httpd-freebsd.conf.tmp
sed -i '' "s/example.com/${FQDN}/g" default-site.conf.tmp
TEMP=$(echo ${APACHE} | sed "s/\//\\\\\//g")
sed -i '' "s/APACHEDIR/${TEMP}/g" default-site.conf.tmp
iocage exec ${JAIL} mv ${APACHE}/Includes/* ${APACHE}/conf-enabled
iocage exec ${JAIL} rmdir ${APACHE}/Includes
install -m 644 -o root -g wheel httpd-freebsd.conf.tmp ${JAILROOT}/${APACHE}/httpd.conf
install -m 644 -o root -g wheel default-site.conf.tmp ${JAILROOT}/${APACHE}/sites-enabled/default-site.conf
rm httpd-freebsd.conf.tmp default-site.conf.tmp

# setup data directory
iocage exec ${JAIL} mkdir -p /srv/www/${FQDN}
iocage exec ${JAIL} chown -R www:www /srv/www
install -m 644 -o www -g www default.php ${JAILROOT}/srv/www/${FQDN}/index.php

# generate self signed cert
SUBJ="/C=US/ST=New\ York/L=New\ York/O=The\ Ether/CN=${FQDN}"
KEYOUT=${APACHE}/ssl/${FQDN}.key
CRTOUT=${APACHE}/ssl/${FQDN}.crt
iocage exec ${JAIL} mkdir -m 700 ${APACHE}/ssl
iocage exec ${JAIL} "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${KEYOUT} -out ${CRTOUT} -subj ${SUBJ}"
iocage exec ${JAIL} chmod 400 ${KEYOUT} ${CRTOUT}

# start up services
iocage exec ${JAIL} service apache24 start
iocage exec ${JAIL} service mysql-server start

# set the root db pass and save it
iocage exec ${JAIL} mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}'";
echo [mysql] > ${JAILROOT}/root/.my.cnf
echo password=${DB_ROOT_PASSWORD} >> ${JAILROOT}/root/.my.cnf
iocage exec ${JAIL} chmod 400 /root/.my.cnf
echo See /root/.my.cnf for root password to mysql

# secure mysql installation
iocage exec ${JAIL} mysql -u root -e "DELETE FROM mysql.user WHERE User='';"
iocage exec ${JAIL} mysql -u root -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
iocage exec ${JAIL} mysql -u root -e "DROP DATABASE IF EXISTS test;"
iocage exec ${JAIL} mysql -u root -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"

# restart the whole jail to restart everything
iocage restart ${JAIL}

