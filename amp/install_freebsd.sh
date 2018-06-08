#!/bin/sh
JAIL=myjail
FQDN=myjail.lan
IP=192.168.1.20
GATEWAY=192.168.1.1

if ! [ $(id -u) = 0 ]; then
	echo "This script must be run with root privileges"
	exit 1
fi

# create the jail with base applications
echo Creating jail "${JAIL}" at ${IP}...
cat <<__EOF__ >/tmp/pkg.json
{
	"pkgs":[
		"nano","bash","wget","curl","sudo",
		"apache24","mysql57-server","php56","mod_php56","php56-mysql","php56-mysqli"
	]
}
__EOF__
iocage create --name "${JAIL}" -r 11.1-RELEASE -p /tmp/pkg.json ip4_addr="${IP}" defaultrouter="${GATEWAY}" boot="on" host_hostname="${JAIL}" vnet="on"
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
make_port databases/php56-pdo databases/php56-pdo_mysql
make_port www/php56-session devel/php56-json devel/phpunit devel/php56-tokenizer
make_port ftp/php56-curl archivers/php56-phar archivers/php56-zlib security/php56-hash
make_port security/php56-filter security/php56-openssl converters/php56-iconv converters/php56-mbstring
make_port textproc/php56-dom textproc/php56-ctype security/py-certbot

# set to start on boot
iocage exec ${JAIL} sysrc mysql_enable="YES"
iocage exec ${JAIL} sysrc apache24_enable="YES"

# configure
JAILROOT=/mnt/iocage/jails/${JAIL}/root
APACHE=/usr/local/etc/apache24
sed -i '' "s/example.com/${FQDN}/g" httpd.conf
sed -i '' "s/example.com/${FQDN}/g" vhosts.conf
install -m 644 -o root -g wheel httpd.conf ${JAILROOT}/${APACHE}
install -m 644 -o root -g wheel vhosts.conf ${JAILROOT}/${APACHE}/Includes
install -m 644 -o root -g wheel php.conf ${JAILROOT}/${APACHE}/Includes

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

# start em up
iocage exec ${JAIL} service apache24 start
iocage exec ${JAIL} service mysql-server start

