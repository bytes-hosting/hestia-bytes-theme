<?php
// DEV ONLY: opens a session without a password. Never ship this file.
$_SERVER["HESTIA"] = "/usr/local/hestia";
$path = parse_url($_SERVER["REQUEST_URI"], PHP_URL_PATH);
if (preg_match('/\.(css|js|svg|png|woff2|ico)$/', $path)) {
	return;
}
// Opening the panel with ?as= switches account; other requests keep the cookie
foreach (["as" => "admin", "theme" => "sidebar", "lang" => "uk", "look" => ""] as $k => $default) {
	$v = $_GET[$k] ?? ($_COOKIE["dev_$k"] ?? $default);
	${"dev_$k"} = preg_replace("/[^a-z0-9_]/i", "", $v);
	setcookie("dev_$k", ${"dev_$k"}, ["path" => "/"]);
}
if (preg_match("#^/(login|reset)/#", $path) && !isset($_GET["loginas"])) {
	// These pages run without a user
	session_id("devlogin");
	session_start();
	$_SESSION = ["THEME" => $dev_theme, "language" => $dev_lang];
	session_write_close();
	return;
}
if ($dev_as === "nobody") {
	return; // signed out
}
session_id("dev" . $dev_as);
session_start();
$_SESSION = [
	"user" => $dev_as, "userContext" => $dev_as === "admin" ? "admin" : "user", "look" => $dev_look,
	"token" => "devtoken", "VERSION" => "dev", "language" => $dev_lang, "userTheme" => $dev_theme,
	"userSortOrder" => "name", "LAST_ACTIVITY" => time(), "INACTIVE_SESSION_TIMEOUT" => 60,
	"DISABLE_IP_CHECK" => "yes",
] + $_SESSION;
session_write_close();
