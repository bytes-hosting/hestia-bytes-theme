<?php
// Body of dashboard.php
use function Hestiacp\quoteshellarg\quoteshellarg;

if (!defined("HSB_LOADED")) {
	http_response_code(404);
	exit();
}
require_once __DIR__ . "/lib.php";

// Without the sidebar theme there are no styles for this page
$hsb_theme = !empty($_SESSION["userTheme"]) ? $_SESSION["userTheme"] : $_SESSION["THEME"] ?? "";
if (!preg_match('/^sidebar(_[a-z0-9]+)?$/i', (string) $hsb_theme)) {
	header("Location: " . $hsb_stock_home);
	exit();
}

/** Runs one of Hestia's list commands and returns its JSON, or [] when it fails. */
function hsb_list(string $command, string ...$args): array {
	$line = HESTIA_CMD . $command;
	foreach ($args as $arg) {
		$line .= " " . quoteshellarg($arg);
	}
	exec($line . " json", $output, $code);
	$data = $code === 0 ? json_decode(implode("", $output), true) : null;
	return is_array($data) ? $data : [];
}

$hsb = hsb_context();

// Services take the longest to collect, so the page asks for them separately
if (($_GET["part"] ?? "") === "services") {
	if (!$hsb["showServer"]) {
		http_response_code(403);
		exit();
	}
	session_write_close();
	header("Content-Type: application/json");
	$out = [];
	foreach (hsb_list("v-list-sys-services") as $key => $service) {
		$out[] = [
			"name" => (string) $key,
			"about" => _((string) ($service["SYSTEM"] ?? "")),
			"running" => ($service["STATE"] ?? "") === "running",
		];
	}
	echo json_encode($out);
	exit();
}

require __DIR__ . "/dashboard-data.php";
render_page($user, $TAB, "../../js/custom_scripts/hestia-sidebar/dashboard-view");
$_SESSION["back"] = $_SERVER["REQUEST_URI"];
