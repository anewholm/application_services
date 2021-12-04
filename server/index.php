<?php
if (isset($_GET['info'])) {
	phpinfo();
	exit();
}

$phpversion_info = explode('.', phpversion());
$phpversion = "$phpversion_info[0].$phpversion_info[1]";
$ip_self = shell_exec('ifconfig | grep -Eo "inet 192\.168\.[0-9]+\.[0-9]+" | sed "s/.* //g"');
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <title>Rojava Server system</title>
    <style type="text/css" media="screen">
			body {
				padding: 0px;
				font-family: Verdana, sans-serif;
				font-size: 11pt;
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
			li {
				margin: 4px;
			}

			#diagnostics {
				float:right;
				border:none;
				height:800pt;
				width:40%;
				background:
			}
			.title-links, .title-links a {
				font-weight:normal;
				font-size:12pt;
				color: #fff;
			}
			.up {
				color: white;
				background-color: green;
				border-radius: 10px;
				padding: 2px;
			}
			.down {
				color: white;
				background-color: red;
				border-radius: 10px;
				padding: 2px;
			}
    </style>
  </head>
  <body>
    <div class="main_page">
    	<h1>Welcome to a Rojavan Server system
				<span class="title-links">
					<a href="?info">info</a> php version <?php print($phpversion);?>
					| <a href="nmap.php">nmap</a>
				</span>
			</h1>

    	<iframe id="diagnostics" src="diagnostics.php"></iframe>

    	<h2>People</h2>
    	<a href="mailto:heval.tekosin@yahoo.com">heval.tekosin@yahoo.com</a> - Email me with any questions!

    	<h2>Installed Web Applications</h2>
    	<ul>
            <?php
                $dir = '/var/www';
                foreach (scandir($dir) as $filename) {
                    $path = realpath($dir . DIRECTORY_SEPARATOR . $filename);
                    if (is_dir($path) && $filename != "." && $filename != ".." && $filename != "html") {
												$domain_name = $filename;
												$is_internal = strstr($domain_name, '.internal');
												$domain_parts = explode('.', $domain_name);
												$name = ucfirst($domain_parts[0]);

												// Are we up?
												$url = "http://$domain_name/";
												$ch = curl_init($url);
												@curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
												@curl_setopt($ch, CURLOPT_TIMEOUT, 10);
												@curl_setopt($ch, CURLOPT_HEADER, true);  // we want headers
												@curl_setopt($ch, CURLOPT_NOBODY, true);  // we don't need body
												$output = curl_exec($ch);
												$httpcode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
												curl_close($ch);
												$up = ($httpcode != 500 ? 'up' : 'down');

												print("<li><b><a target='_blank' href='http://$filename/'>$name</a></b>");
												print(" <b class='$up'>$up</b> ");
												if ($desc = shell_exec("grep desc=.* $path/install.options | sed 's/desc=//g'"))
													print($desc);
												if ($login = shell_exec("grep login=.* $path/install.options | sed 's/login=//g'"))
													print("<br/><b>login: $login</b>");
												print("</li>");
                    }
                }
	    	?>
        </ul>
    	<p>To add a new PHP web or java TomCat web application:
    	<ul>
            <li>create a new directory <b>~/Installs/ApplicationServices/applications/</b>&lt;application name&gt;</li>
            <li>download the ZIP file for the new application there</li>
            <li>open a terminal (Ctrl+Alt+T)</li>
            <li>change to the <b>~/Installs/ApplicationServices/</b> directory</li>
            <li>run <b><i>sudo</i> ./install</b> script again as root</li>
            <li>reload this page</li>
            <li>access the application above</li>
            <li>you may need to setup or configure the application specific database connection settings</li>
        </ul>
        </p>

    	<h2>Server Documentation</h2>
    	<p>This server was installed using the <a target="_blank" href="install.sh">install script</a>.</p>

    	<h3>VPN (recommended)</h3>
    	<p>For security, location hiding and external access to this server we recommend using a VPN. <a target="_blank" href="https://www.expressvpn.com/">Express VPN</a>. Sign up for an account and then setup your router according to the instructions. Please email support above if you need help with payment or setup.</p>

    	<h3>WiFi router setup for office DNS Application access like <a target="_blank" href="http://akaunting.internal/">http://akaunting.internal/</a></h3>
        <p>For local DNS nameservices, so that all other devices connected to the WiFi, including phones, can see the Applications on this server, the router DNS servers need to be changed below. This can often be found under LAN (Local Area Network), DHCP or Network. Set <b>Primary DNS: <?php print($ip_self);?></b></p>
        <p>For external visibility, so that people outside the office on the Internet can see the Applications on this server, a VPN is recommended above. However, if DDNS is desired and possible, the router <b>DMZ or forwarding for port 80 (HTTP)</b> must be set to <b><?php print($ip_self);?></b> also. However, in Rojava this often will not work because of the ISP router configuration between the outside Internet and the actual final router.</p>

    	<h3>Bind9 local DNS, Apache2 webserver and MYSQL database server infrastructure</h3>
    	<p>MySQL can be managed through <a target="_blank" href="http://localhost/phpmyadmin/">phpmyadmin</a></p>
    	<p>Bind9 DNS server translates domain names, like akaunting.ddns.net, to IP addresses, like <?php print($ip_self);?>, on this server. WiFi routers can be setup to use this DNS server thus making all the local domain names defined here available generally to devices in the office that use that router.</p>
    	<p>In order to add names: run the command <b>domain-add &lt;domain name&gt;</b>. Administrator privileges required. This will:
    	<ul>
    		<li>created a new zone file db.&lt;domain name&gt; in the /etc/bind/ directory</li>
    		<li>setup a virtual host in the Apache webserver</li>
    		<li>create an empty MySQL database and user named with the first, significant part of the domain name</li>
    		<li>restart the relevant services</li>
    		<li>and run tests</li>
    	</ul></p>

    	<h3>DDNS and router setup for remote access</h3>
    	<p>Log in to the <a href="https://my.noip.com/#!/dynamic-dns">No-IP DDNS account</a> to add domains to access this server from external</a>. However, in Rojava this often will not work because of the ISP router configuration between the outside Internet and the actual final router.</p>
    	<h3>SSH and SCP remote control and file copying</h3>
    	<p>Go to sftp://&lt;linux username&gt;@<?php print($ip_self);?> in your favourite Linux file manager.</p>

    	<h3>Automated Backups</h3>
    	<p>Manual database backups can be made through <a target="_blank" href="http://localhost/phpmyadmin/">phpmyadmin</a>. Automatic MySQL backups can be done in <a href="https://www.jotform.com/blog/how-to-backup-mysql-database/">several different ways</a>. We use <a target="_blank" href="https://www.ducea.com/2006/05/27/backup-your-mysql-databases-automatically-with-automysqlbackup/">AutoMySQLBackup</a> which is configured by <b>/etc/default/automysqlbackup</b> to backup to <b>/var/lib/automysqlbackup/</b> daily with <b>/etc/cron.daily/automysqlbackup</b>.</p>
    	<p><a target="_blank" href="https://wiki.gnome.org/Apps/DejaDup/Details">Déjà Dup</a> backup utility is installed but not active. Please ask tech support for advise on where to backup.</p>

    	<h3>OS Auto-security updates with Live Patch enabled</h3>
    	<p>See the local Ubuntu LivePatch and online Ubuntu One account.</p>

    	<h2>TO DO</h2>
    	<ul>
    		<li>Update nameserver DNS records when IP address changes live with <b>/etc/dhcp/dhclient-enter-hooks.d/</b></li>
	    	<li>Virus and StrongPity detection on Bind 9 using airmon and dual adapters</li>
	    	<li>Central server administration - servers inform central of their location or periodically check for instructions</li>
    	</ul>
    </div>
  </body>
</html>

