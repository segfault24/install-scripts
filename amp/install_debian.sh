#!/bin/sh
FQDN=$(hostname --fqdn)
IP=192.168.1.30
GATEWAY=192.168.1.1

exit 1

if ! [ $(id -u) = 0 ]; then
    echo "This script must be run with root privileges"
    exit 1
fi

DB_ROOT_PASSWORD=$(openssl rand -base64 16)

# install base applications
echo Creating jail "${JAIL}" at ${IP}...
apt-get install apache2 mysql-server mysql-client php php-mysql php-curl php-pear

# set to start on boot
systemctl enable mysql
systemctl enable apache2

# configure apache
APACHE=/etc/apache2
rm ${APACHE}/conf-enabled/*
rm ${APACHE}/sites-enabled/*
sed -i '' "s/example.com/${FQDN}/g" httpd-debian.conf
sed -i '' "s/example.com/${FQDN}/g" default-site.conf
TEMP=$(echo ${APACHE} | sed "s/\//\\\\\//g")
sed -i '' "s/APACHEDIR/${TEMP}/g" default-site.conf
install -m 644 -o root -g wheel httpd-debian.conf ${APACHE}/apache2.conf
install -m 644 -o root -g wheel default-site.conf ${APACHE}/sites-enabled

# setup data directory
mkdir -p /srv/www/${FQDN}
chown -R www:www /srv/www
install -m 644 -o www -g www default.php /srv/www/${FQDN}/index.php

# generate self signed cert
SUBJ="/C=US/ST=New\ York/L=New\ York/O=The\ Ether/CN=${FQDN}"
KEYOUT=${APACHE}/ssl/${FQDN}.key
CRTOUT=${APACHE}/ssl/${FQDN}.crt
mkdir -m 700 ${APACHE}/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${KEYOUT} -out ${CRTOUT} -subj ${SUBJ}
chmod 400 ${KEYOUT} ${CRTOUT}

# start up services
systemctl start apache2
systemctl start mysql

# secure mysql installation
mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('${DB_ROOT_PASSWORD}') WHERE User='root';"
mysql -u root -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -u root -e "DROP DATABASE IF EXISTS test;"
mysql -u root -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysqladmin reload

# save the db password(s)
echo ${DB_ROOT_PASSWORD} > /root/db_passwords.txt
echo See /root/db_passwords.txt for DB credentials

