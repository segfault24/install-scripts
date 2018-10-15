#!/bin/sh

service openvpn stop
RAWIP=$(wget http://ipinfo.io/ip -qO -)
echo "Insecure: ${RAWIP}"

service openvpn start
VPNIP=$(wget http://ipinfo.io/ip -qO -)
echo "Secure: ${VPNIP}"

