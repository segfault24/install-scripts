#!/bin/sh

echo "This script requires sudo privileges to start/stop openvpn"

sudo service openvpn stop
RAWIP=$(wget http://ipinfo.io/ip -qO -)
echo "Insercure: ${RAWIP}"

sudo service openvpn start
VPNIP=$(wget http://ipinfo.io/ip -qO -)
echo "Secure: ${VPNIP}"

