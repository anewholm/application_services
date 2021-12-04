#!/bin/bash
# Run as root
ip=$1

# When the server starts up it will "start", then "stop"
if [ "$1" == "stop" ]; then
	exit
fi
if [ -z "$ip" ] || [ "$1" == "start" ]; then
	ip=`ifconfig | grep -Eo "inet 192\.168\.[0-9]+\.[0-9]+" | sed "s/.* //g"`
fi

if [ -n "$ip" ]; then
	for filepath in /etc/bind/db.*; do
		if [ "$filepath" != "/etc/bind/db.0" ] \
			&& [ "$filepath" != "/etc/bind/db.127" ] \
			&& [ "$filepath" != "/etc/bind/db.empty" ] \
			&& [ "$filepath" != "/etc/bind/db.local" ] \
			&& [ "$filepath" != "/etc/bind/db.255" ]; 
		then
			hostname=`echo "$filepath" | sed -E 's_.*/db\.__'`
			echo "Updating $hostname to new $ip"
			sudo sed -i -E "s/192.168.[0-9]+\.[0-9]+/$ip/g" $filepath
			# sudo sed -i -E "s/^$hostname\s+192.168.[0-9]+\.[0-9]+/$hostname $ip/g" $filepath
		fi
	done
	sudo service named restart
else
	echo "Error: IP address unknown"
fi
