<?php
$ip_self = shell_exec('ifconfig | grep -Eo "inet 192\.168\.[0-9]+\.[0-9]+" | sed "s/.* //g"');

if ($ip_self) {
	$ip_self_parts = explode('.', $ip_self);
	if (count($ip_self_parts) == 4) {
		$ip_self_C = "$ip_self_parts[0].$ip_self_parts[1].$ip_self_parts[2]"; // 192.168.1
		$ip_D_scan_range = '0-255';
		$ip_scan_range = "$ip_self_C.$ip_D_scan_range";
		print("<h1>Scanning $ip_scan_range ...</h1>");
		flush();
		$nmap = shell_exec("nmap $ip_scan_range");
		$nmap_lines = explode("\n", $nmap);
		print("<ul>");
		$machine_name = NULL;
		foreach ($nmap_lines as $nmap_line) {
			// Nmap scan report for rojava.router (192.168.1.1)
			// Nmap scan report for 192.168.1.12
			$scan = 'Nmap scan report for ';
			if (substr($nmap_line, 0, strlen($scan)) == $scan ) {
				if ($machine_name) print('</ul></li>');
				$machine_name = substr($nmap_line, strlen($scan) + 1);
				$ports = array();
				print("<li>$machine_name<ul>");
			}

			// All 1000 scanned ports on 192.168.1.38 are closed
			$scan = 'All 1000 scanned ports'; // on 192.168.1.38 are closed
			if (substr($nmap_line, 0, strlen($scan)) == $scan ) {
				if ($machine_name) print('</ul></li>');
			}

			// 53/tcp open domain
			// 19101/tcp filtered unknown
			// All 1000 scanned ports on 192.168.1.38 are closed
			$scan = '#([0-9]+)/([a-zA-Z0-9]+)\s+([a-zA-Z0-9]+)\s+([a-zA-Z0-9]+)#'; // on 192.168.1.38 are closed
			if (preg_match($scan, $nmap_line, $matches)) {
				$port = $matches[1];
				$protocol = $matches[2];
				$state = $matches[3];
				$name = $matches[4];
				print("<li>$port/$protocol $state $name</li>");
				array_push($ports, $name);
			}

			// PORT STATE SERVICE
			// Host is up (0.021s latency).
		}
		if ($machine_name) print('</ul></li>');
		print("</ul>");
	} else {
		print("IP address [$ip_self] invalid");
	}
} else {
	print("Unable to ascertain IP address");
}
