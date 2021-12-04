#!/bin/bash
database_settings=application/config/database.php
sudo sed -i "s/'username' => 'root'/'username' => 'jorani'/" $database_settings
sudo sed -i "s/'password' => ''/'password' => 'QueenPool1'/" $database_settings
sudo sed -i "s/ AS INT/ AS DECIMAL/g" sql/jorani.sql
sudo mysql jorani < sql/jorani.sql
