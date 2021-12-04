<?php
  // --------------------------------------- Backup system
  $backups_mysql = 'bad';
  $latest_backup_date_string = NULL;
  $backup_dir_akaunting = '/var/lib/automysqlbackup/daily/akaunting';
  $backups = @scandir($backup_dir_akaunting); // SCANDIR_SORT_ASCENDING
  if ($backups && count($backups)) {
    $backup_latest = end($backups);
    $backup_parts = explode('_', $backup_latest);
    if (count($backup_parts) > 1) {
        $latest_backup_DateTime = new DateTime($backup_parts[1]);
        $today = new DateTime();
        $days_old = $today->diff($latest_backup_DateTime)->format("%a");
        $latest_backup_date = $latest_backup_DateTime->format('Y-M-d');
        $latest_backup_date_string = "@ <b><i style='color:#44aa44'>$latest_backup_date</i></b>, ";
        $latest_backup_date_string .= $days_old ? "$days_old days old" : "today";
        if ($days_old < 10) $backups_mysql = 'good';
    }
  }

  // --------------------------------------- Process existence
  $processes = explode( "\n", shell_exec("ps -A"));
  array_shift($processes); // Header
  foreach ($processes as &$process) {
  	$process_a = explode(' ', $process);
  	$process = end($process_a);
  }
  $apache2 = in_array('apache2', $processes) ? 'good' : 'bad';
  $mysql   = in_array('mysqld',  $processes) ? 'good' : 'bad';
  $bind9   = in_array('named',   $processes) ? 'good' : 'bad';
  $ssh     = in_array('sshd',    $processes) ? 'good' : 'bad';
  $backups_file  = in_array('deja-dup-monito',    $processes) ? 'good' : 'bad';
  $noip    = in_array('noip2',    $processes) ? 'good' : 'bad';

  // --------------------------------------- VPN
  # expressvpn does not play nicely with www-data user
  $vpn_location = shell_exec("expressvpn status | head -n 1 2> echo | rev | cut -d ' ' -f 1 | rev");
  $vpn = in_array('expressvpnd', $processes) ? 'good' : 'bad';

  // --------------------------------------- DNS probing
  $ip_akaunting_ddns = trim(shell_exec('nslookup akaunting.ddns.net localhost | grep -E "Address: .*" | sed "s/.* //g"'));
  $ip_akaunting_internal = trim(shell_exec('nslookup akaunting.internal localhost | grep -E "Address: .*" | sed "s/.* //g"'));
  $ip_self = trim(shell_exec('ifconfig | grep -Eo "inet 192\.168\.[0-9]+\.[0-9]+" | sed "s/.* //g"'));
  $ip_lookup = $ip_akaunting_ddns == $ip_self ? 'good' : 'bad';

  $ip_nameserver = trim(shell_exec('systemd-resolve --status | grep "DNS Servers:" | sed -E "s/DNS Servers: //" | sed -E "s/\s+/ /g"'));
  $ip_dns_status = $ip_self == $ip_nameserver ? 'good' : 'bad';

  // --------------------------------------- ifconfig
  if (1) { // Time consuming
    $ip_router = trim(shell_exec("ip -j -p r | grep '\"gateway\"' | sed -E 's/\s+\"gateway\":\s+//' | sed -E 's/[,\" ]+//g' | sed -E 's/\s+/ /g'"));
    $router_http_port = shell_exec("nmap $ip_router | grep '80/tcp'");
    $router_https_port = shell_exec("nmap $ip_router | grep '443/tcp'");
    $router_url = $router_http_port ? "http://$ip_router/" : NULL;
    $router_url = $router_https_port ? "https://$ip_router/" : $router_url;
    $router_link = $router_url ? "<a target='_blank' href='$router_url'>router admin</a>" : 'no router admin';
    $router_http_status = $router_http_port || $router_https_port ? 'good' : 'bad';

    if ($router_url) {
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $router_url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
        $response = curl_exec($ch);
    }
  }
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <title>Server system</title>
    <style type="text/css" media="screen">
			body, html {
				padding: 0px;

				font-family: Verdana, sans-serif;
				font-size: 11pt;
			}
			ul {
				list-style-type:none;
			}
			h1 {
				background: #000;
				color: #fff;
				padding: 0pt 20pt;
				margin: 0px;
			}
			h2 {
				padding:0pt;
			}
			h2,h3,h4 {
				margin: 10px 0pt 0px 0px;
			}
			p {
				margin: 0pt 0pt 5pt 0pt;
			}
			ul {
				margin: 0pt 0pt 0pt 5pt;
				padding: 0pt 0pt 0pt 15pt;
			}
			.health-good:before {
				content: "✔ ";
			}
			.health-bad:before {
				content: "✘ ";
			}
			.health-bad {
				color: red;
				font-weight: bold;
			}
    </style>
  </head>

  <body>
  	<h2>Setup</h2>
  	<ul>
	  	<li>This Server IP: <b><?php print($ip_self);?></b></li>
	  	<li>Akaunting DNS: <b><?php print($ip_akaunting_internal);?></b></li>
	  	<li>Akaunting DDNS: <b><?php print($ip_akaunting_ddns);?></b></li>
	  	<li>Router (gateway): <b><?php print($ip_router);?></b></li>
	  	<li>NameServer: <b><?php print($ip_nameserver);?></b></li>
	  	<li class="health-<?php print($router_http_status);?>"><?php print($router_link);?></li>
	</ul>
  	<h2>Service diagnostics</h2>
	<ul>
	  	<li class="health-<?php print($ip_lookup);?>">Local Bind9 DNS lookup</li>
	  	<li class="health-<?php print($ip_dns_status);?>">Router DNS setup</li>
    	<li class="health-<?php print($apache2);?>">Apache</li>
    	<li class="health-<?php print($mysql);?>">MySQL</li>
  		<li class="health-<?php print($bind9);?>">Bind9 DNS</li>
  		<li class="health-<?php print($noip);?>">No-IP DDNS update</li>
  		<li class="health-<?php print($ssh);?>">SSH</li>
  		<li class="health-<?php print($backups_file);?>">Déjà Dup File backups</li>
  		<li class="health-<?php print($backups_mysql);?>">MySQL backups <?php print($latest_backup_date_string);?></li>
  		<li class="health-<?php print($vpn);?>">VPN <?php print($vpn_location);?></li>
  	</ul>
  </body>
</html>
