#!/bin/bash
# echo "Disabling the PHP version check"
#if [ -f vendor/composer/platform_check.php ]; then
#	sed -i "s/!(PHP_VERSION_ID/!(1000/" vendor/composer/platform_check.php
#else
#	echo "${RED}Error${NC}: vendor/composer/platform_check.php not found for disabling the PHP version check"
#fi

# Allow editing of the .env file
sudo touch .env
sudo chown www-data:www-data .env
sudo chmod u+w .env

# Help for next time...
echo "Akaunting needs php 8.0"
echo "It also needs to write its .env (or rm the one we just made)"
echo "And to write to storage and sub-folders"
echo "Check its custom log file for write errors: sudo cat /var/log/apache2/akaunting.internal.log"
read -p "ok?"
