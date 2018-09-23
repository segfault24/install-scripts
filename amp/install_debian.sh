#!/bin/sh
FQDN=

if [ -z ${FQDN} ]; then
    echo The Fully Qualified Domain Name \(FQDN\) of the default website must
    echo be filled in at the top of this script \(ex. www.mywebsite.com\)
    exit 1
fi

if ! [ $(id -u) = 0 ]; then
    echo "This script must be run with root privileges"
    exit 1
fi

DB_ROOT_PASSWORD=$(openssl rand -base64 16)

# install base applications
echo Installing base applications...
apt-get -y install apache2 mariadb-server mysql-client php php-mysql php-curl php-pear

# set to start on boot
systemctl enable apache2
systemctl enable mariadb
systemctl stop apache2
systemctl stop mariadb

# configure apache
APACHE=/etc/apache2
rm ${APACHE}/conf-enabled/*
rm ${APACHE}/sites-enabled/*
rm ${APACHE}/sites-available/*
cp httpd-debian.conf httpd-debian.conf.tmp
cp default-site.conf default-site.conf.tmp
sed -i "s/example.com/${FQDN}/g" httpd-debian.conf.tmp
sed -i "s/example.com/${FQDN}/g" default-site.conf.tmp
TEMP=$(echo ${APACHE} | sed "s/\//\\\\\//g")
sed -i "s/APACHEDIR/${TEMP}/g" default-site.conf.tmp
install -m 644 -o root -g root httpd-debian.conf.tmp ${APACHE}/apache2.conf
install -m 644 -o root -g root default-site.conf.tmp ${APACHE}/sites-available/default-site.conf
a2ensite default-site
rm httpd-debian.conf.tmp default-site.conf.tmp

# setup data directory
mkdir -p /srv/www/${FQDN}
chown -R www-data:www-data /srv/www
install -m 644 -o www-data -g www-data default.php /srv/www/${FQDN}/index.php

# generate self signed cert
SUBJ="/C=US/ST=New\ York/L=New\ York/O=The\ Ether/CN=${FQDN}"
KEYOUT=${APACHE}/ssl/${FQDN}.key
CRTOUT=${APACHE}/ssl/${FQDN}.crt
mkdir -m 700 ${APACHE}/ssl
openssl req -newkey rsa:2048 -nodes -x509 -keyout "${KEYOUT}" -out "${CRTOUT}" -subj "${SUBJ}"
chmod 400 ${KEYOUT} ${CRTOUT}

# start up services
systemctl start apache2
systemctl start mariadb

# set the root db pass and save it
mysql -u root -e "USE mysql; UPDATE user SET password=PASSWORD('${DB_ROOT_PASSWORD}') WHERE User='root' AND Host='localhost'; FLUSH PRIVILEGES;"
echo [mysql] > /root/.my.cnf
echo password=${DB_ROOT_PASSWORD} >> /root/.my.cnf
chmod 400 /root/.my.cnf
echo see /root/.my.cnf for root password to mariadb

# secure mysql installation
mysql -u root -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -u root -e "DROP DATABASE IF EXISTS test;"
mysql -u root -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"

# restart everything to be sure
systemctl restart apache2
systemctl restart mariadb

