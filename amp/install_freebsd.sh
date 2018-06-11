#!/bin/sh
JAIL=myjail
FQDN=myjail.lan
INTERFACE=bridge1
IP=192.168.1.30/24
GATEWAY=192.168.1.1
VNET=off

if ! [ $(id -u) = 0 ]; then
    echo "This script must be run with root privileges"
    exit 1
fi

DB_ROOT_PASSWORD=$(openssl rand -base64 16)

# create the jail with base applications
echo Creating jail "${JAIL}" at ${IP}...
cat <<__EOF__ >/tmp/pkg.json
{
    "pkgs":[
        "nano","bash","wget","curl","sudo","apache24","mod_php72","mysql57-server",
        "php72","php72-ctype","php72-curl","php72-dom","php72-filter","php72-hash",
        "php72-iconv","php72-json","php72-mbstring","php72-mysqli","php72-openssl",
        "php72-pdo","php72-pdo_mysql","php72-phar","php72-session","php72-tokenizer",
        "php72-xmlwriter","php72-zlib"
    ]
}
__EOF__
iocage create --name "${JAIL}" -r 11.1-RELEASE -p /tmp/pkg.json ip4_addr="${INTERFACE}|${IP}" defaultrouter="${GATEWAY}" boot="on" host_hostname="${JAIL}" vnet="${VNET}"
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
#make_port databases/php56-pdo databases/php56-pdo_mysql
#make_port www/php56-session devel/php56-json devel/phpunit devel/php56-tokenizer
#make_port ftp/php56-curl archivers/php56-phar archivers/php56-zlib security/php56-hash
#make_port security/php56-filter security/php56-openssl converters/php56-iconv converters/php56-mbstring
#make_port textproc/php56-dom textproc/php56-ctype security/py-certbot

# set to start on boot
iocage exec ${JAIL} sysrc mysql_enable="YES"
iocage exec ${JAIL} sysrc apache24_enable="YES"

# configure apache
JAILROOT=/mnt/iocage/jails/${JAIL}/root
APACHE=/usr/local/etc/apache24
iocage exec ${JAIL} mkdir -m 755 ${APACHE}/conf-enabled
iocage exec ${JAIL} mkdir -m 755 ${APACHE}/sites-enabled
sed -i '' "s/example.com/${FQDN}/g" httpd-freebsd.conf
sed -i '' "s/example.com/${FQDN}/g" default-site.conf
TEMP=$(echo ${APACHE} | sed "s/\//\\\\\//g")
sed -i '' "s/APACHEDIR/${TEMP}/g" default-site.conf
iocage exec ${JAIL} mv ${APACHE}/Includes/* ${APACHE}/conf-enabled
iocage exec ${JAIL} rmdir ${APACHE}/Includes
install -m 644 -o root -g wheel httpd-freebsd.conf ${JAILROOT}/${APACHE}/httpd.conf
install -m 644 -o root -g wheel default-site.conf ${JAILROOT}/${APACHE}/sites-enabled

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

# secure mysql installation
iocage exec ${JAIL} mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('${DB_ROOT_PASSWORD}') WHERE User='root';"
iocage exec ${JAIL} mysql -u root -e "DELETE FROM mysql.user WHERE User='';"
iocage exec ${JAIL} mysql -u root -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
iocage exec ${JAIL} mysql -u root -e "DROP DATABASE IF EXISTS test;"
iocage exec ${JAIL} mysql -u root -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
iocage exec ${JAIL} mysqladmin reload

# save the db password(s)
iocage exec ${JAIL} echo ${DB_ROOT_PASSWORD} > /root/db_passwords.txt
echo See /root/db_passwords.txt for DB credentials

