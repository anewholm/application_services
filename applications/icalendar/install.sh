#!/bin/bash
# Passwords for webdav access, normally QueenPool1
echo "Passwords for webdav access already included in ZIP in .webdav_login"
echo "# sudo htpasswd -c .webdav_login webdav_calendar"
sudo chmod u+w calendars
sudo chmod a+r .webdav_login

echo "Allow hierarchical calendar folders"
sudo sed -i -e "s/#\s*'recursive_path'\s*=>\s*'yes'/'recursive_path'\s*=>\s*'yes'/" config.inc.php

echo "Tidying up calendars/ folder"
sudo rm -rf calendars/recur_tests
sudo rm calendars/publish_log.txt
sudo rm calendars/Work.ics calendars/Home.ics calendars/US\ Holidays.ics

sudo systemctl restart apache2.service

echo "Allow recovery from unaccessible calendars"
sudo sed -i -e "s#if ($$ifile == FALSE) exit#if ($$ifile == FALSE) continue; //exit#" functions/ical_parser.php
sudo sed -i -e "s#if ($$ifile == FALSE) exit#if ($$ifile == FALSE) continue; //exit#" functions/calendar_functions.php
sudo sed -i -e "s#if ($$ifile == FALSE) exit#if ($$ifile == FALSE) return;   //exit#" functions/parse/parse_tzs.php

echo "Need to place this debugging info in to /var/www/icalendar.internal/functions/parse/parse_tzs.php"
#			// Debug
#			$begin_daylight_0 = (count($begin_daylight) ? array_values($begin_daylight)[0] : "");
#			$begin_daylight_0_nice = substr($begin_daylight_0, 4, 2) . '/' . substr($begin_daylight_0, 6, 2);
#			$begin_std_0 = (count($begin_std) ? array_values($begin_std)[0] : "");
#			$begin_std_0_nice = substr($begin_std_0, 4, 2) . '/' . substr($begin_std_0, 6, 2);
#			echo "<!-- $tz_id ($st_name): STD:$offset_s @ $begin_std_0_nice => DST:$offset_d @ $begin_daylight_0_nice -->\n";
#			// Reset ready. Important if the next VTIMEZONE does not have DST
#			unset($offset_s, $offset_d, $begin_daylight, $begin_std, $st_name, $dt_name);

echo "Need to place this debugging info in to /var/www/icalendar.internal/functions/is_daylight.php"
#			case 'Asia/Damascus': // Moved by Tekoşîn so that DST is calculated
#			case 'EET':

echo "Need to place this debugging info in to /var/www/icalendar.internal/functions/calendar_functions.php"
# $cal_displayname_tmp = preg_replace('#^./calendars/|\.ics$#g', '', $cal_filelist[$search_idx]);

exit 1
