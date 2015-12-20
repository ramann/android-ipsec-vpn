#!/system/bin/sh
#
# This script inserts a couple of iptables rules to drop outbound non-VPN/tethering traffic. My strongswan server is configured to assign my phone the virtual IP 10.11.12.13.
# This runs at boot using the SManager app (select "Su" and "Boot"). The VPN server IP must be provided as an argument
#
VPN_SERVER=$1

iptables -I OUTPUT ! -s 10.11.12.13 ! -d $VPN_SERVER -j DROP
iptables -I OUTPUT ! -s 10.11.12.13 ! -d $VPN_SERVER -j LOG --log-prefix "NOT-VPN-RELATED "
iptables -I OUTPUT -o rndis0 -s 192.168.42.129 -d 192.168.42.2 -j ACCEPT

