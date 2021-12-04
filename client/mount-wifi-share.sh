#!/bin/bash
# Run from crontab every 5 seconds
RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
NC="$(tput sgr0)"  # No Color

server=cdc.server
if [ -z "$(mount | grep $server)" ]; then
	echo "Server $server not mounted, checking network availability...";
	response=`ping -c 1 $server | grep "bytes from $server"`
	if [ -n "$response" ]; then
		echo "${GREEN}INFO${NC}: Successful ping response from server, mounting /etc/fstab sshfs entries";
		sh client-network-automount.sh
	else
		echo "${RED}ERROR${NC}: No bytes returned from $server. Cancelling"
	fi
fi
