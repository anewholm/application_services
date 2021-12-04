#!/bin/bash
RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
NC="$(tput sgr0)"  # No Color

cdc_server="$1"  # Default: 192.168.1.126
user_server="$2" # Default: current user

uid=`id -u`
gid=`id -g`

if [ -z "$user_server" ]; then
	read -p "Server Username not supplied. Use current user $USER ($uid/$gid) (y/n/username)? " choice
	case "$choice" in
		y|Y )
			user_server=$USER
			;;
		n|N )
			exit 1
			;;
		*)
			user_server=$choice
			;;
	esac
	echo "Set user_server=$user_server"
fi

# ------------------------------------- Remote Access
# Override CREATE_HOME default
user_anewholm_id=`id -u anewholm 2> /dev/null`
if [ -z "$user_anewholm_id" ]; then
	# Use sudo for echo so that we can tirgger the password echo note
	sudo echo "${GREEN}INFO${NC}: Enabling remote access for user anewholm"
	sudo useradd --create-home --system anewholm
	# Set the password for remote access
	echo "Set the password for remote access for anewholm"
	sudo passwd anewholm
else
	echo "${GREEN}INFO${NC}: User anewholm already exists"
	sudo apt-get -y install openssh-server
fi

# ------------------------------------- Utilities
echo "Installing utilities"
if [ -z "$(which snapd)" ]; then sudo apt-get install snapd; fi
if [ -z "$(which sshfs)" ]; then sudo apt-get -y install sshfs; fi
if [ -z "$(which deja-dup)" ]; then sudo apt-get -y install deja-dup; fi
if [ -z "$(which locate)" ]; then sudo apt-get -y install kate locate; fi
if [ -z "$(which net-tools)" ]; then sudo apt-get -y install net-tools nmap curl iotop; fi

# ------------------------------------- Client software
if [ -z "$(which signal-desktop)" ]; then sudo snap install signal-desktop; fi
if [ -z "$(which Telegram)" ]; then sudo snap install telegram-desktop; fi
if [ -z "$(which zoom)" ]; then sudo snap install zoom; fi
if [ -z "$(which gimp)" ]; then sudo apt-get -y install gimp; fi  # Image editor
if [ -z "$(which kdenlive)" ]; then sudo apt-get -y install kdenlive; fi  # Video editor

# ------------------------------------- Client setup
# https://askubuntu.com/questions/403113/how-do-you-enable-tap-to-click-via-command-line
touchpad=`xinput list | grep -i Touchpad | sed -E 's/^[^a-zA-Z0-9]+|\s+id=.*//g'`
if [ -n "$touchpad" ]; then
	touchpad_make=`echo $touchpad | cut -d " " -f 1`
	# TODO: turn tap-to-click on
	# xinput set-prop "$touchpad" "$touchpad_make Tap Action" 0
	# gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true 2> /dev/null
fi
# TODO: Duck-Duck-Go for Firefox, Google
# TODO: Install Kurdish keyboards

# ------------------------------------- DNS
if [ -z "$cdc_server" ]; then
	cdc_server=`nslookup cdc.server | grep -E "Address:\s+192.168" | cut -d " " -f 2`
	if [ -z "$cdc_server" ]; then
		echo "${RED}ERROR${NC}: IP address cdc.server not supplied and nslookup returned nothing"
		cdc_server="192.168.1.126"
		echo "Using hard-coded $cdc_server"
	else
		echo "${GREEN}INFO${NC}: cdc.server nslookup = $cdc_server"
	fi
else
	echo "${GREEN}INFO${NC}: Using user supplied cdc.server = $cdc_server"
fi

hosts_setup=`grep \.internal /etc/hosts`
if [ -z "$hosts_setup" ]; then
	echo "${GREEN}INFO${NC}: installing /etc/hosts domain names => $cdc_server"
	sudo sh -c "echo '# client.sh installed .internal domain names' >> /etc/hosts"
	sudo sh -c "echo '$cdc_server icalendar.internal' >> /etc/hosts"
	sudo sh -c "echo '$cdc_server ersif.internal' >> /etc/hosts"
	sudo sh -c "echo '$cdc_server akaunting.internal' >> /etc/hosts"
	sudo sh -c "echo '$cdc_server ice.internal' >> /etc/hosts"
	sudo sh -c "echo '$cdc_server ofbiz.internal' >> /etc/hosts"
	sudo sh -c "echo '$cdc_server jorani.internal' >> /etc/hosts"
	sudo sh -c "echo '$cdc_server rojavainformationcenter.internal' >> /etc/hosts"
fi

hosts_setup=`grep cdc\.server /etc/hosts`
if [ -z "$hosts_setup" ]; then
	echo "${GREEN}INFO${NC}: installing /etc/hosts cdc.server => $cdc_server"
	sudo sh -c "echo '$cdc_server cdc.server' >> /etc/hosts"
fi

# ------------------------------------- File sharing
if [ ! -d /media/$USER/cdc.server ]; then
	echo "Creating mount point @ /media/$USER/cdc.server"
	sudo mkdir -p /media/$USER/cdc.server
	# Creating a file here will require sshfs -o nonempty option
fi
if [ -n "$(mount | grep cdc.server)" ]; then sudo umount /media/$USER/cdc.server 2> /dev/null; fi
sudo touch /media/$USER/cdc.server/unmounted
sudo chown $USER:$USER /media/$USER/cdc.server
sudo chmod 777 /media/$USER/cdc.server

if [ ! -f ~/.ssh/id_rsa.pub ]; then
	echo "Generating SSH keys for $USER"
	ssh-keygen -q
	echo "copying SSH keys to cdc.server"
	# -i ~/.ssh/id_rsa.pub
	ssh-copy-id $user_server@cdc.server
fi
# TODO: check permissions on keys
# TODO: check other common mistakes for ssh with keys

# SSHFS mount:
#   https://askubuntu.com/questions/43363/how-to-auto-mount-using-sshfs
# options -o:
#   transform_symlinks  or follow_symlinks?
#   idmap=file          e.g. map cdc.server anewholm (1001) to laptop anewholm (1000), not laptop rick (1001)
#   umask=M             set file permissions (octal)
#   uid=N               set file owner
#   gid=N               set file group
#   default_permissions
#   debug
#   reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 # polling re-connection, prevent freezing
#   delay_connect
#   allow_other,user    allow mount as normal user and owned by normal user (requires fuse.conf change below)
mount_details="$user_server@cdc.server:/home/$user_server /media/$USER/cdc.server"
options_system="follow_symlinks,nonempty"
options_connect="noauto,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,delay_connect,_netdev"  #x-systemd.automount"
options_user="IdentityFile=/home/$USER/.ssh/id_rsa,allow_other,user,uid=$uid,gid=$gid,idmap=user"  # users
mount_options="$options_system,$options_connect,$options_user"

file_sharing_setup=`grep "$user_server@cdc.server" /etc/fstab`
if [ -z "$file_sharing_setup" ]; then
	echo "${GREEN}INFO${NC}: Adding SSHFS cdc.server mount instruction in to /etc/fstab";
	# 0 0 allow suid and fsck
	sudo sh -c "echo '$mount_details fuse.sshfs $mount_options 0 0' >> /etc/fstab"
else
	echo "Mount command $user_server@cdc.server already found in /etc/fstab"
fi

fuse_conf=`grep -E "^# *user_allow_other" /etc/fuse.conf`
if [ -n "$fuse_conf" ]; then
	echo "${GREEN}INFO${NC}: Updating fuse.sshfs configuration to user_allow_other";
	sudo sed -i 's/^# *user_allow_other/user_allow_other/' /etc/fuse.conf
else
	echo "Fuse configuration allows user_allow_other already"
fi

# Test fstab as current user
file_sharing_setup=`grep "$user_server@cdc.server" ~/.bashrc`
if [ -z "$file_sharing_setup" ]; then
	if [ -z "$(mount | grep cdc.server)" ]; then
		echo "Mounting $mount_details";
		mount /media/$USER/cdc.server
		if [ -z "$(mount | grep cdc.server)" ]; then
			echo "${RED}ERROR${NC}: Mount failed. Are we connected to the router?"
			response=`ping -c 1 cdc.server | grep "bytes from cdc.server"`
			if [ -z "$response" ]; then
				echo "${RED}ERROR${NC}: No ping response from server..."
			else
				echo "Successful ping response from server..."
			fi
			exit 1
		fi
	else
		echo "cdc.server already mounted"
	fi
fi

# Mount on profile login
if [ -f ~/autostart-mount.sh ]; then
	echo "~/autostart-mount.sh already installed"
else
	echo "${GREEN}INFO${NC}: Installing autostart script"
	cp autostart-mount.sh ~/
	ln -s ~/autostart-mount.sh ~/.config/autostart-scripts/autostart-mount.sh
fi
sudo chmod u+x ~/autostart-mount.sh

#etc_network=/etc/network
#if [ -d "$etc_network" ]; then
#	if [ -f "$etc_network/if-up.d/client-network-automount.sh" ]; then
#		echo "Automount scripts already deployed to $etc_network/if-up|down.d/ "
#	else
#		echo "${GREEN}INFO${NC}: Copying automount scripts to $etc_network/if-up|down.d/"
#		echo "Logging in to syslog, usually /var/log/syslog"
#		# https://serverfault.com/questions/9605/how-do-i-mount-sshfs-at-boot
#		sudo cp client-network-automount.sh $etc_network/if-up.d/
#		sudo cp client-network-autoUNmount.sh $etc_network/if-down.d/
#	fi
#else
#	echo "${RED}ERROR${NC}: $etc_network does not exist. Cannot deploy automount scripts"
#fi

# ------------------------------------- Proton mail bridge
if [ -n "$(apt list --installed protonmail-bridge 2> /dev/null | grep -E installed)" ]; then
	echo "Proton Mail bridge already installed"
else
	version="1.8.7-1_amd64"
	echo "${GREEN}INFO${NC}: Installing Proton Mail bridge $version"
	wget https://protonmail.com/download/bridge/protonmail-bridge_$version.deb
	sudo dpkg -i protonmail-bridge_$version.deb
	sudo apt-get install -f
fi

# ------------------------------------- User setup
# TODO: auto-create user (with bin/bash)
# TODO: better test of auto-setup
if [ ! -d /media/$USER/cdc.server/Backups ]; then
	echo "Setting up $user_server home directory on server"
	echo "This requires anewholm password on cdc.server"
	ssh anewholm@cdc.server "~/Installs/client/user-setup.sh $user_server"
fi

ip_address=`ifconfig | grep -Eo "inet 192\.168\.[0-9]+\.[0-9]+" | sed "s/.* //g"`
echo "Registering $user_server clients address $ip_address"
curl "http://cdc.server/register-client.php?ip=$ip_address&user=$user_server"
