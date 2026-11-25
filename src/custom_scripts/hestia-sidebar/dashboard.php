<?php
/**
 * Dashboard page. Goes through Hestia's main.php, so sign-in, session and CSRF checks
 * are the same as for any other page. Reads only, changes nothing.
 *
 * People land here right after signing in, so this file stays tiny: whatever breaks in
 * the files below, the visitor gets the stock first page. The query string keeps
 * hsb_is_landing() from sending them back here.
 */
$TAB = "DASHBOARD";
include $_SERVER["DOCUMENT_ROOT"] . "/inc/main.php";

defined("HSB_LOADED") || define("HSB_LOADED", true);
$hsb_stock_home =
	($_SESSION["userContext"] === "admin" && empty($_SESSION["look"]) ? "/list/user/" : "/list/web/") . "?hsb=0";
$hsb_level = ob_get_level();
ob_start();
try {
	require __DIR__ . "/dashboard-main.php";
} catch (Throwable $e) {
	while (ob_get_level() > $hsb_level) {
		ob_end_clean();
	}
	error_log("hestia-sidebar: " . $e->getMessage());
	header("Location: " . $hsb_stock_home);
}
