<?php
/**
 * hestia-sidebar: left sidebar layout for Hestia Control Panel.
 *
 * Hestia includes every *.php file from web/js/custom_scripts/ in the <head> of each page
 * (see web/templates/includes/js.php). Nothing in the Hestia core is modified: if this file
 * is removed, or the markup below can no longer be found, the stock top menu is shown.
 */

// The file sits inside the web root: do nothing when it is requested directly.
if (realpath($_SERVER["SCRIPT_FILENAME"] ?? "") === __FILE__) {
	http_response_code(404);
	exit();
}

// Hestia internals changed: step aside and leave the stock layout.
if (!function_exists("get_user_data")) {
	return;
}

(static function ($tab): void {
	$theme = !empty($_SESSION["userTheme"]) ? $_SESSION["userTheme"] : $_SESSION["THEME"] ?? "";

	// The layout is enabled by any theme named "sidebar" or "sidebar_*".
	if (!preg_match('/^sidebar(_[a-z0-9]+)?$/i', (string) $theme)) {
		return;
	}

	$dir = __DIR__ . "/hestia-sidebar";
	$asset = static fn(string $file): string => "/js/custom_scripts/hestia-sidebar/" .
		$file .
		"?v=" .
		(@filemtime("$dir/$file") ?: 0);

	echo '<link rel="stylesheet" href="' . $asset("ui.css") . '">' . "\n";

	// Login, password reset and 2FA pages get the skin, but no sidebar.
	if (empty($_SESSION["user"]) || in_array($tab, ["LOGIN", "RESET"], true)) {
		return;
	}

	defined("HSB_LOADED") || define("HSB_LOADED", true);

	// A broken menu must never take the panel down with it.
	$level = ob_get_level();
	try {
		require_once "$dir/lib.php";
		if (hsb_is_landing()) {
			if (!headers_sent()) {
				header("Location: " . HSB_DASHBOARD);
				exit();
			}
			echo '<script>location.replace("' . HSB_DASHBOARD . '");</script>';
		}
		$sidebar = require "$dir/menu.php";
	} catch (Throwable $e) {
		while (ob_get_level() > $level) {
			ob_end_clean();
		}
		error_log("hestia-sidebar: " . $e->getMessage());
		return;
	}

	echo '<script defer src="' . $asset("ui.js") . '"></script>' . "\n";

	// Hold the output only until the insertion point, then let it through as Hestia sends it:
	// buffering the whole page would change how a page that fails halfway is answered.
	$pending = "";
	$done = false;
	ob_start(
		static function (string $chunk, int $phase) use ($sidebar, &$pending, &$done): string {
			if ($done) {
				return $chunk;
			}
			$marker = '<div class="app">';
			$pending .= $chunk;
			$pos = strpos($pending, $marker);
			if ($pos === false) {
				return $phase & PHP_OUTPUT_HANDLER_FINAL ? $pending : "";
			}
			$done = true;
			return substr_replace($pending, '<div class="app hsb">' . $sidebar, $pos, strlen($marker));
		},
		1,
	);
})($TAB ?? "");
