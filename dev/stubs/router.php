<?php
// Emulates the index/static rules of Hestia's nginx for the built-in PHP server
$root = "/usr/local/hestia/web";
$path = parse_url($_SERVER["REQUEST_URI"], PHP_URL_PATH);
$file = $root . $path;
if (is_dir($file)) {
	$file = rtrim($file, "/") . "/index.php";
}
if (!is_file($file)) {
	http_response_code(404);
	exit("404 $path");
}
$types = [
	"css" => "text/css", "js" => "text/javascript", "svg" => "image/svg+xml", "png" => "image/png",
	"woff2" => "font/woff2", "ico" => "image/x-icon", "json" => "application/json",
];
$ext = pathinfo($file, PATHINFO_EXTENSION);
if ($ext !== "php") {
	header("Content-Type: " . ($types[$ext] ?? "application/octet-stream"));
	readfile($file);
	exit();
}
$_SERVER["SCRIPT_FILENAME"] = $file;
// Hestia's CSRF check compares these; behind a published port they differ from the container's own
$_SERVER["DOCUMENT_URI"] = substr($file, strlen($root));
$_SERVER["SERVER_PORT"] = parse_url("http://" . ($_SERVER["HTTP_HOST"] ?? ""), PHP_URL_PORT) ?: "8084";
chdir(dirname($file));
require $file;
