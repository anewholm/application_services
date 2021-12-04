#!/bin/bash
# Enable database config file
sudo touch app/config.php
sudo chmod 777 app/config.php
sudo chown www-data:www-data app/config.php

# Enable app/data storage
sudo chmod 777 app/data

sudo systemctl restart apache2.service

# Help for next time...
echo "ICE works with any php"
echo "It also needs to write its app/config.php, BUT if it is there, it won't go to its app/install process"
echo "Check its custom log file for write errors: sudo cat /var/log/apache2/ice.internal.log"
read -p "ok?"

