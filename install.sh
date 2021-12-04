#!/bin/bash
# Run as root
#if [[ $EUID -ne 0 ]]; then
#   echo "This script must be run as root"
#   exit 1
#fi

RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
NC="$(tput sgr0)"  # No Color

if [ ! -d applications ]; then
    echo "${RED}Error${NC}: This install script should be run in an install directory with ./applications/<name>/*.zip"
    exit 1
fi

option=`echo "$1" | tr '[:upper:]' '[:lower:]'`  # Lower case
pwd_dir=`pwd`

# --------------------------- env
release=`lsb_release -rs`
distro=`lsb_release -is`
if [ "$distro" == "Ubuntu" ]; then
    if [ "$release" == "20.04" ] || [ "$release" == "21.10" ]; then 
        echo "${GREEN}INFO${NC}: $distro $release supported"
    else
        echo "${RED}Error${NC}: Release $release not supported. Continuing anyway..."
    fi
else
    echo "${RED}Error${NC}: Distro $distro not supported. Continuing anyway..."
fi

# --------------------------- help
if [ "$option" = "--help" ] || [ "$option" = "help" ] || [ "$option" = "-h" ]; then
	echo "Usage: ./install.sh [command]"
	echo "commands:"
	echo "  help           show this help"
	echo "  all            install all commands below (default)"
	echo "  min            install minimum: without apache multi-PHP FPM, and only php8.0 and applications"
	echo "  servers        web server, mysql"
	echo "  applications   applications/<application name> into /var/www/<domain name> and associated setup"
	echo "  DNS            Bind9 local DNS services so others can see the applications on the local network"
	echo "  NoIP           Auto-external IP update service for NoIP.net"
	echo "explicit installs, not included in all:"
	echo "  VPN            Install ExpressVPN.com Virtual private networking for external access"
	echo "additional package installs:"
	echo "  ssh, java-8, file and database backups"
	exit 0
fi

if [ "$option" = "purge" ]; then
	echo "--------------------------- Purge"
	read -p "${GREEN}CONFIRM${NC}: Remove all installed packages (Y/n)? " choice
	case "$choice" in
		y|Y )
			sudo service apache2 stop 2> /dev/null
			sudo apt-get -y --purge remove apache2
			echo "Removing apache directories"
			sudo rm -rf /etc/apache2 /usr/lib/apache2 /usr/include/apache2

			sudo apt-get -y --purge remove php php-common
			sudo apt-get -y --purge remove libapache2-mod-php php-gd php-curl php-mysql php-bcmath
			php_version=7.4
			echo "Removing PHP $php_version"
			sudo systemctl stop php$php_version-fpm
			sudo apt-get -y remove --purge php$php_version php$php_version-fpm php$php_version-mysql libapache2-mod-php$php_version
			php_version=8.0
			echo "Removing PHP $php_version"
			sudo systemctl stop php$php_version-fpm
			sudo apt-get -y remove --purge php$php_version php$php_version-fpm php$php_version-mysql libapache2-mod-php$php_version
			sudo rm -rf /etc/php /usr/lib/php /etc/phpmyadmin

			sudo service named stop 2> /dev/null
			sudo apt-get -y --purge remove bind9 bind9utils bind9-doc dnsutils
			# Not removed because not empty
			sudo rm -rf /var/cache/bind /etc/bind

			sudo service mysql stop 2> /dev/null
			sudo apt-get -y --purge remove mysql-server phpmyadmin automysqlbackup
			sudo rm -rf /var/lib/automysqlbackup

			sudo service vsftpd stop 2> /dev/null
			sudo apt-get -y --purge remove openjdk-8-jdk vsftpd gradle

			sudo apt-get -y autoremove

			;;
	esac

	echo "Websites:"
	for filepath in /var/www/*.internal; do
		domain_name=`echo "$filepath" | cut -d "/" -f 4`
		domain_part_name=`echo "$domain_name" | cut -d "." -f 1`
		read -p "${GREEN}CONFIRM${NC}: Remove $domain_name (Y/n)? " choice
			case "$choice" in
				y|Y )
					sudo rm -rf $filepath
					if [ -n "$(which mysql)" ]; then sudo mysql -e "drop database $domain_part_name"; fi
				;;
		esac
	done

	exit 0
fi

if [ -z "$option" ] || [ "$option" = "all" ]; then
	echo "--------------------------- Utilities"
	echo "${GREEN}INFO${NC}: Installing/updating base utilities if not present"
	sudo apt-get -y install kate locate
	sudo apt-get -y install net-tools nmap curl iotop
	sudo apt-get -y install git
	# sudo apt-get -y install default-jdk  # Disabled in preference for Java 8 below
	sudo apt-get -y install openjdk-8-jdk
	sudo apt-get -y install gradle  # OfBiz
	# Backup
	sudo apt-get -y install deja-dup
	# Access
	sudo apt-get -y install openssh-server
fi

if [ "$option" = "vpn" ]; then
	echo "--------------------------- VPN"
	installed=`apt list --installed expressvpn 2> /dev/null | grep -E installed`
	if [ -n "$installed" ]; then
			echo "${GREEN}INFO${NC}: ExpressVPN already installed"
	else
			echo "Installing ExpressVPN"
			sudo apt-get -y install openvpn openvpn-systemd-resolved
			sudo apt-get -y install expressvpn
			echo "ExpressVPN activation code: EGXRCJDOGCYNYGCXXUEP4T2"
			expressvpn activate
			expressvpn connect smart
			echo "ExpressVPN auto_connect on reboot"
			expressvpn preferences set auto_connect true

			if [ -z `grep expressvpn /etc/crontab` ]; then
					# Location hop every 30 minutes
					echo "ExpressVPN location hoping every 30 minutes in crontab"
					sudo cp smartexpressvpn.sh /usr/sbin/
					sudo cp vpnlocations /etc/default/
					sudo echo "0,15,30,45 *   * * * root /usr/sbin/smartexpressvpn.sh" >> /etc/crontab
			fi
			expressvpn status
	fi
fi

if [ ! "$option" = "min" ]; then
    echo "--------------------------- Information"
    # For System Tray status indicators for VPN health
    # further setup is required if the user wants:
    # Right-click on the empty system tray icon and assign to the appropriate script as desired
    installed=`apt list --installed indicator-sysmonitor 2> /dev/null | grep -E installed`
    if [ -n "$installed" ]; then
            echo "${GREEN}INFO${NC}: indicator-sysmonitor already installed"
    else
        sudo add-apt-repository -y ppa:fossfreedom/indicator-sysmonitor
        sudo apt-get -y install indicator-sysmonitor
    fi
fi

if [ ! "$option" = "min" ]; then
    echo "--------------------------- File Servers"
    echo "${GREEN}INFO${NC}: Installing file server support"
    installed=`apt list --installed libapache2-mod-authnz-external 2> /dev/null | grep -E installed`
    if [ -n "$installed" ]; then
        echo "HTTP local account authentication (instead of htpasswd)"
        # https://serverfault.com/questions/45278/authenticate-in-apache-via-system-account
        sudo apt-get install libapache2-mod-authnz-external pwauth
        sudo a2enmod authnz_external
    fi

    installed=`apt list --installed vsftpd 2> /dev/null | grep -E installed`
    if [ -n "$installed" ]; then
        echo "FTP server"
        sudo apt-get -y install vsftpd
        config_ftp=/etc/vsftpd.conf
        if [ ! -f "$config_ftp" ]; then
            config_ftp=/etc/vsftpd/vsftpd.conf
        fi
        if [ -f "$config_ftp" ]; then
            sudo cp $config_ftp $config_ftp.orig
            sudo sed -i -E 's/^#?\s*anonymous_enable=YES/anonymous_enable=NO/g' $config_ftp
            sudo sed -i -E 's/^#?\s*local_enable=NO/local_enable=YES/g' $config_ftp
            sudo sed -i -E 's/^#?\s*write_enable=NO/write_enable=YES/g' $config_ftp
            sudo sed -i -E 's/^#?\s*listen=YES/listen=NO/g' $config_ftp
        else
            echo "${RED}Error${NC}: FTP configuration file not found $config_ftp"
        fi
        if [ -n "$(which ufw)" ]; then sudo ufw allow 20:21/tcp; fi
    fi

    installed=`apt list --installed nfs-kernel-server 2> /dev/null | grep -E installed`
    if [ -n "$installed" ]; then
        echo "NFS"
        sudo apt-get -y install nfs-kernel-server
    fi

    installed=`apt list --installed sshfs 2> /dev/null | grep -E installed`
    if [ -n "$installed" ]; then
        echo "SSHFS"
        sudo apt-get -y install sshfs
    fi
fi

if [ ! "$option" = "min" ]; then
    if [ -z "$option" ] || [ "$option" = "all" ] || [ "$option" = "dns" ]; then
        echo "--------------------------- Bind9 DNS"
        if [ -f /etc/bind/named.conf.options ]; then
                echo "${GREEN}INFO${NC}: Bind9 already installed"
        else
                echo "Installing Bind9"
                sudo apt-get -y install bind9 bind9utils bind9-doc dnsutils
                if [ -n "$(which ufw)" ]; then sudo ufw allow Bind9; fi  # Firewall
                sudo chmod o+w /etc/bind
                sudo ln -s /etc/init.d/update_dns.sh /etc/rc3.d/S02update_dns  # After networking
                sudo ln -s /etc/init.d/update_dns.sh /etc/rc4.d/S02update_dns
                sudo cp dhclient-enter-hook-update_dns /etc/dhcp/dhclient-enter-hooks.d/update_dns.sh
                sudo service named restart
                echo "Adding DNS update script to init.d"
                sudo cp update_dns.sh /etc/init.d/
        fi
        sudo ./update_dns.sh
        # No clobber template install
        sudo cp -n templates/named.* /etc/bind/
        sudo cp -n templates/db.* /etc/bind/
    fi
fi

echo "--------------------------- Utilities"
if [ -f /usr/local/bin/domain-add ]; then
    echo "${GREEN}INFO${NC}: Utilities already installed. Updating..."
fi
sudo cp utilities/* /usr/local/bin/

if [ -z "$option" ] || [ "$option" = "all" ] || [ "$option" = "noip" ]; then
	echo "--------------------------- DDNS"
	if [ -f /usr/local/etc/no-ip2.conf ]; then
			echo "${GREEN}INFO${NC}: NoIP already installed"
	else
			echo "Installing NoIP"
			sudo cp no-ip2.conf /usr/local/etc/
			sudo cp noip2 /usr/local/bin/
			sudo chmod oa+rw /usr/local/etc/no-ip2.conf
			sudo cp noip2.sh /etc/init.d/
			sudo ln -s /etc/init.d/noip2.sh /etc/rc1.d/K01noip2
			sudo ln -s /etc/init.d/noip2.sh /etc/rc3.d/S01noip2
			sudo ln -s /etc/init.d/noip2.sh /etc/rc4.d/S01noip2
			sudo ln -s /etc/init.d/noip2.sh /etc/rc6.d/K01noip2
			sudo /etc/init.d/noip2.sh start
	fi
fi

if [ -z "$option" ] || [ "$option" = "all" ] || [ "$option" = "servers" ]; then
	echo "--------------------------- Web and Database infrastructure"
	installed=`apt list --installed apache2 2> /dev/null | grep -E installed`
	if [ -n "$installed" ]; then
			echo "${GREEN}INFO${NC}: Apache already installed"
	else
		sudo apt-get -y install apache2 software-properties-common
		echo "Enabling rewrite and .htaccess"
		sudo a2enmod rewrite
		sudo sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf

        if [ ! "$option" = "min" ]; then
            echo "Enabling apache2 mods for multi-version PHP"
            sudo apt-get -y install libapache2-mod-fcgid
            sudo a2enmod actions fcgid alias proxy_fcgi setenvif
        fi
	fi

	# Webdav infrastructure
    if [ ! "$option" = "min" ]; then
        echo "Enabling webdav and auth_digest in Apache2"
        sudo a2enmod dav
        sudo a2enmod dav_fs
        sudo a2enmod auth_digest
    fi

    if [ ! "$option" = "min" ]; then
        php_version=7.4  # --------------------------------------------------------------
        installed=`apt list --installed php$php_version 2> /dev/null | grep -E installed`
        if [ -n "$installed" ]; then
                echo "${GREEN}INFO${NC}: PHP $php_version already installed"
        else
                echo "Installing PHP $php_version"
                sudo apt-get -y remove --purge libapache2-mod-php$php_version 2> /dev/null
                sudo apt-get -y install php$php_version php$php_version-mysql libapache2-mod-php$php_version
                sudo apt-get -y install php$php_version-gd php$php_version-curl php$php_version-bcmath php$php_version-xml php$php_version-zip php$php_version-mbstring

                sudo a2enmod php$php_version
                if [ ! "$option" = "min" ]; then
                    echo "Installing PHP$php_version FPM"
                    sudo apt-get -y install php$php_version-fpm
                    sudo a2enconf php$php_version-fpm
                    sudo systemctl start php$php_version-fpm
                    active=`sudo systemctl status php$php_version-fpm | grep "Active: active (running)"`
                    if [ -z "$active" ]; then echo "php$php_version-fpm service failed to start"; exit 1; fi
                fi
        fi
        # Turn error reporting on for apache and php
        echo "Turn error reporting on for apache2 and php $php_version"
        if [ -f /etc/php/$php_version/apache2/php.ini ]; then
            sudo sed -i 's/display_errors = Off/display_errors = On/g' /etc/php/$php_version/apache2/php.ini
            sudo sed -i 's/display_startup_errors = Off/display_startup_errors = On/g' /etc/php/$php_version/apache2/php.ini
        else
            echo "${RED}Error${NC}: /etc/php/$php_version/apache2/php.ini not found, exiting"
            exit 1
        fi
    fi

	php_version=8.0  # --------------------------------------------------------------
	installed=`apt list --installed php$php_version 2> /dev/null | grep -E installed`
	if [ -n "$installed" ]; then
			echo "${GREEN}INFO${NC}: PHP $php_version already installed"
	else
			echo "Installing PHP $php_version (from ppa:ondrej/php)"
			# Just released so we need a PPA
			sudo add-apt-repository -y ppa:ondrej/php
			sudo apt update
			sudo apt-get -y remove --purge libapache2-mod-php$php_version 2> /dev/null
			sudo apt-get -y install php$php_version php$php_version-mysql libapache2-mod-php$php_version
			sudo apt-get -y install php$php_version-gd php$php_version-curl php$php_version-bcmath php$php_version-xml php$php_version-zip php$php_version-mbstring
                
			sudo a2enmod php$php_version
            if [ ! "$option" = "min" ]; then
                echo "Installing PHP$php_version FPM"
                sudo apt-get -y install php$php_version-fpm
                sudo a2enconf php$php_version-fpm
                sudo systemctl start php$php_version-fpm
                active=`sudo systemctl status php$php_version-fpm | grep "Active: active (running)"`
                if [ -z "$active" ]; then echo "php$php_version-fpm service failed to start"; exit 1; fi
            fi
	fi
	echo "Turn error reporting on for apache2 and php $php_version"
	if [ -f /etc/php/$php_version/apache2/php.ini ]; then
		sudo sed -i 's/display_errors = Off/display_errors = On/g' /etc/php/$php_version/apache2/php.ini
		sudo sed -i 's/display_startup_errors = Off/display_startup_errors = On/g' /etc/php/$php_version/apache2/php.ini
	else
		echo "${RED}Error${NC}: /etc/php/$php_version/apache2/php.ini not found, exiting"
		exit 1
	fi

	# No clobber template install
	sudo cp -n templates/*.conf /etc/apache2/sites-available/

	installed=`apt list --installed mysql-server 2> /dev/null | grep -E installed`
	if [ -n "$installed" ]; then
			echo "${GREEN}INFO${NC}: MySQL already installed"
	else
			sudo apt-get -y install mysql-server

			# Unattended phpmyadmin install
			APP_PASS="QueenPool1"
			ROOT_PASS="QueenPool1"
			APP_DB_PASS="QueenPool1"
			sudo sh -c "echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | debconf-set-selections"
			sudo sh -c "echo 'phpmyadmin phpmyadmin/app-password-confirm password $APP_PASS' | debconf-set-selections"
			sudo sh -c "echo 'phpmyadmin phpmyadmin/mysql/admin-pass password $ROOT_PASS' | debconf-set-selections"
			sudo sh -c "echo 'phpmyadmin phpmyadmin/mysql/app-pass password $APP_DB_PASS' | debconf-set-selections"
			sudo sh -c "echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' | debconf-set-selections"
			sudo apt-get -y install phpmyadmin

			if [ -f /etc/phpmyadmin/apache.conf ]; then
				included=`grep phpmyadmin /etc/apache2/apache2.conf`
				if [ -n "$included" ]; then
					echo "phpmyadmin already enabled in apache2"
				else
					echo "Enabling phpmyadmin on http://localhost/phpmyadmin/"
					sudo sh -c "echo 'Include /etc/phpmyadmin/apache.conf' >> /etc/apache2/apache2.conf"
				fi
			else
				echo "${RED}Error${NC}: Cannot Enable phpmyadmin because /etc/phpmyadmin/apache.conf not found"
			fi
	fi

	if [ "$option" = "min" ]; then
        echo "${RED}WARNING${NC}: Not installing MySQL auto backup"
	else
        installed=`apt list --installed automysqlbackup 2> /dev/null | grep -E installed`
        if [ -n "$installed" ]; then
                echo "${GREEN}INFO${NC}: MySQL auto backup already installed"
        else
                echo "${GREEN}INFO${NC}: Installing MySQL auto backup"
                sudo apt-get -y install automysqlbackup
                sudo chmod -R o+rx /var/lib/automysqlbackup
                # Allow read of backup directories
                sudo sed -i -E 's_^#POSTBACKUP=_POSTBACKUP=_' /etc/default/automysqlbackup
                sudo cp mysql-backup-post /etc/
        fi
    fi
fi

if [ ! "$option" = "min" ]; then
    echo "--------------------------- PHP utilities"
    composer_version=`composer --version 2> /dev/null | cut -d " " -f 3 | cut -d "." -f 1`
    if [ "$composer_version" == "2" ]; then
        echo "${GREEN}INFO${NC}: Composer 2 already installed"
    else
        echo "${GREEN}INFO${NC}: Installing Composer 2"
        sudo apt-get -y install php-curl 2> /dev/null  # Composer really needs this so repeat it
        sudo apt -y remove composer
        php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
        php -r "if (hash_file('sha384', 'composer-setup.php') === '756890a4488ce9024fc62c56153228907f1545c228516cbf63f885e036d37e9a59d27d63f46af1d4d07ee0f76181c7d3') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
        sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
        php -r "unlink('composer-setup.php');"
    fi
fi

if [ -z "$option" ] || [ "$option" = "min" ] || [ "$option" = "all" ] || [ "$option" = "applications" ]; then
	echo "--------------------------- Install applications"
	echo "Restarting apache2 before applications installed"
	sudo service apache2 restart
	if [ -f /var/www/html/index.php ]; then
			echo "${GREEN}INFO${NC}: http://localhost/ already installed"
	else
			echo "${GREEN}INFO${NC}: Installing http://localhost/ server details"
			sudo mv /var/www/html/index.html /var/www/html/index_old.html 2> /dev/null
			sudo cp -r server/. /var/www/html/
			sudo cp install.sh /var/www/html/
	fi

	for filepath in applications/*; do
			application_name=`echo $filepath | sed 's_.*/__'`
			domain_name="$application_name.internal"
			document_root="/var/www/$domain_name"
			install_no=`grep install=no $filepath/install.options 2> /dev/null`
			php_version=`grep php_version= $filepath/install.options 2> /dev/null | cut -d "=" -f 2`
			template=`grep template= $filepath/install.options 2> /dev/null | cut -d "=" -f 2`
			if [ -z "$template" ]; then template="DEFAULT"; fi  # placeholder

			if [ -z "$install_no" ]; then
                    # Option min only supports php 8.0
                    if [ ! "$option" == "min" ] || [ "$php_version" == "8.0" ]; then
                        if [ -d "$document_root" ]; then
                                echo "${GREEN}INFO${NC}: $application_name already installed"
                        else
                                echo "---------------- Installing $application_name under domain $domain_name"
                                # Will create a /var/www/<document_root> owned by root
                                # Will use installed current PHP version if none sent
                                domain-add $domain_name $php_version $template $option # option = min?
                                if [ -f "$filepath/apache.conf" ]; then
                                    echo "Using custom application $domain_name.conf"
                                    sudo cp $filepath/apache.conf /etc/apache2/sites-available/$domain_name.conf
                                fi

                                # Temporary take control of the $document_root while installing
                                sudo chown -R $USER $document_root
                                sudo chgrp -R $USER $document_root

                                # Unzipping
                                filepath_zips=`ls -A1 $filepath/*.zip 2> /dev/null`
                                if [ -n "$filepath_zips" ]; then
                                        for filepath_zip in $filepath/*.zip; do
                                                zipfilename=`echo $filepath_zip | sed 's_.*/__'`
                                                echo "Unzipping $zipfilename into $document_root"
                                                unzip -q $filepath_zip -d $document_root
                                        done
                                else
                                        # GIT
                                        # .git files have the format: uri [release name]
                                        filepath_gits=`ls -A1 $filepath/*.git 2> /dev/null`
                                        if [ -n "$filepath_gits" ]; then
                                                for filepath_git in $filepath/*.git; do
                                                        git_uri=`cat $filepath_git | sed -E 's/ .*$//'`
                                                        git_release=`cat $filepath_git | sed -E 's/^.* //'`
                                                        echo "Processing $git_uri"
                                                        git clone --recurse-submodules $git_uri $document_root
                                                        if [ -n "$git_release" ]; then
                                                                echo "Checking out release $git_release"
                                                                # Cannot find how to use a different working directory with checkouts
                                                                # tried --git-dir and --work-dir
                                                                cd $document_root
                                                                git checkout -q $git_release
                                                                cd $pwd_dir
                                                        else
                                                                git_release="main"  # Used below for ZIP file label
                                                        fi

                                                        # ZIP the distribution up for faster install next time
                                                        # Switch to DOCUMENT_ROOT so that zip file is relative
                                                        cd $document_root
                                                        zip -q -r $pwd_dir/$filepath/git_checkout_$git_release.zip .
                                                        cd $pwd_dir
                                                done
                                        fi
                                fi

                                # Sometimes the ZIPs contain a single top level folder
                                document_root_files=`ls -A1 $document_root`
                                document_root_file_count=`ls -A1 $document_root | wc -l`
                                if [ "$document_root_file_count" == "1" ]; then
                                        echo "Only one top level folder in the document_root from the unzip. Moving all the contents to the top level..."
                                        # This will throw errors because it tries to move . and ..
                                        mv -f $document_root/$document_root_files/{.,}*  $document_root 2> /dev/null
                                        rmdir $document_root/$document_root_files
                                fi

                                # Overwrite any unzipped content, e.g. configuration files
                                # the . syntax is to ensure that hidden files are also copied
                                cp -r $filepath/. $document_root

                                # Composer updates
                                if [ -f "$document_root/composer.json" ]; then
                                        echo "Composer JSON found, installing"
                                        if [ ! -d "$document_root/vendor" ]; then
                                            mkdir $document_root/vendor
                                        fi
                                        chmod a+w $document_root/vendor
                                        echo "If this has dependency problems consider using the --ignore-platform-reqs flag"
                                        # composer update --working-dir=$document_root --ignore-platform-reqs
                                        composer update --working-dir=$document_root --ignore-platform-reqs
                                fi

                                echo "Changing ownerships to www-data and removing write permissions"
                                chmod -R oa-w $document_root  # Deny write to Others and All
                                chmod -R u+w  $document_root  # Allow write to www-data
                                sudo chgrp -R www-data $document_root
                                sudo chown -R www-data $document_root

                                if [ -d "$document_root/public" ]; then
                                        echo "Making public/ directory writeable"
                                        sudo chmod -R u+w $document_root/public
                                        sudo chmod u+x $document_root/public
                                fi

                                if [ -d "$document_root/storage" ]; then
                                        echo "Making storage/ directory writeable"
                                        sudo chmod -R u+w $document_root/storage
                                        sudo chmod u+x $document_root/storage
                                fi

                                if [ -d "$document_root/files" ]; then
                                        echo "Making files/ directory writeable"
                                        sudo chmod -R u+w $document_root/files
                                        sudo chmod u+x $document_root/files
                                fi

                                if [ -f "$filepath/install.sh" ]; then
                                        echo "Running custom ./install.sh script with working directory $document_root"
                                        cd $document_root
                                        $pwd_dir/$filepath/install.sh
                                        cd $pwd_dir
                                fi

                                echo "You may still need to setup the PHP database names and logins in one of the below files"
                                echo "Or maybe go to http://$domain_name/ for setup"
                        fi

                        # Test the site
                        response_code=`curl -Iq http://$domain_name/ 2> /dev/null | head -n 1 | cut -d " " -f 2`
                        if [ "$response_code" == "500" ]; then
                            if [ -f /var/log/apache2/$domain_name.log ]; then
                                sudo tail /var/log/apache2/$domain_name.log
                            else
                                echo "${RED}Error${NC}: /var/log/apache2/$domain_name.log not found"
                            fi
                            read -p "${RED}Error${NC}: Response code $response_code. Continue (Y/n)? " choice
                            case "$choice" in
                                n|N )
                                    exit 1
                                    ;;
                            esac
                        fi

                        # Test the PHP
                        sudo cp phpinfo_hidden.php $document_root
                        site_php_version=`curl -q http://$domain_name/phpinfo_hidden.php 2> /dev/null | grep -Eo "PHP Version [0-9]+\.[0-9]+" | cut -d " " -f 3`
                        if [ -z "$site_php_version" ]; then
                            echo "${RED}Error${NC}: Site failed to load phpinfo_hidden.php"
                            read -p "Continue (Y/n)? " choice
                            case "$choice" in
                                n|N )
                                    exit 1
                                    ;;
                            esac
                        else
                            if [ -z "$php_version" ]; then
                                echo "Site up and running with PHP $site_php_version"
                            else
                                if [ "$site_php_version" == "$php_version" ]; then
                                    echo "Site up and running with PHP $site_php_version same as install.options PHP $php_version"
                                else
                                    echo "${RED}Error${NC}: Site reports PHP $site_php_version but install.options reports $php_version"
                                    read -p "Continue (Y/n)? " choice
                                    case "$choice" in
                                        n|N )
                                            exit 1
                                            ;;
                                    esac
                                fi
                            fi
                        fi
                        sudo rm $document_root/phpinfo_hidden.php
                    fi
			fi
	done
fi

echo "Restarting apache2 after applications installed"
sudo service apache2 restart

syntax_ok=`apachectl configtest 2>&1 | grep "Syntax OK"`
if [ -z "$syntax_ok" ]; then
	echo "${RED}ERROR${NC}: Apache2 configuration errors:"
	apachectl configtest
fi
