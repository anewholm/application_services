#!/bin/bash
expressvpn disconnect
expressvpn refresh

# Only specific locations work from Rojava?
locations=`expressvpn list all | tail -n+4 | cut -d " " -f 1`
# locations=`cat /etc/vpnlocations`
location_count=`echo "$locations" | wc -l`
location_line=$(( $RANDOM % $location_count + 1 ))
sed_command="$location_line!d"
vpn=`echo "$locations" | sed $sed_command`
echo "Location hoping to $vpn ($location_line)"

expressvpn connect $vpn
