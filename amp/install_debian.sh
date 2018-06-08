#!/bin/sh
FQDN=myhost.lan
IP=192.168.1.20
GATEWAY=192.168.1.1

exit 1

if ! [ $(id -u) = 0 ]; then
	echo "This script must be run with root privileges"
	exit 1
fi

# create the jail with base applications
echo Creating jail "${JAIL}" at ${IP}...
apt-get install apache2 mysql-server mysql-client php php-mysql php-curl php-pear
a2enmod rewrite deflate

# set to start on boot
systemctl enable mysql
systemctl enable apache2

# configure
APACHE=/etc/apache2
sed -i '' "s/example.com/${FQDN}/g" httpd.conf
sed -i '' "s/example.com/${FQDN}/g" vhosts.conf
install -m 644 -o root -g wheel httpd.conf ${APACHE}/apache2.conf
install -m 644 -o root -g wheel vhosts.conf ${APACHE}/Includes/

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

# start em up
systemctl start apache2
systemctl start mysql

