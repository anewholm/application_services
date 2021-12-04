<?php
$user = $_GET['user'];
$ip = $_GET['ip'];
print("Registered $user with $ip NOT");

print('<h2>hosts</h2>');
$contents = @file_get_contents('/var/www/html/hosts');
print("<pre>$contents</pre>");
?>
