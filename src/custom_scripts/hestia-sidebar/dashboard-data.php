<?php
// Collects everything dashboard-view.php prints into $hsb_tiles, $hsb_meters, ...
if (!defined("HSB_LOADED")) {
	http_response_code(404);
	exit();
}

$hsb_tiles = $hsb_meters = $hsb_ranking = $hsb_domains = $hsb_info = [];
$hsb_actions = [];
$hsb_num = static fn($v): float => is_numeric($v) ? (float) $v : 0.0;

// Hestia counts disk and bandwidth in megabytes
$hsb_size = static function ($mb): string {
	return $mb === "unlimited"
		? "∞"
		: humanize_usage_size($mb) . " " . humanize_usage_measure($mb);
};

/** One row of a meter list. $max is null when there is no limit. */
$hsb_meter = static function (string $label, float $used, ?float $max, string $text, string $href = ""): array {
	$percent = $max > 0 ? min(100, max(0, ($used / $max) * 100)) : null;
	$level = $percent === null || $percent < 80 ? "" : ($percent < 90 ? "warn" : "crit");
	return compact("label", "percent", "level", "text", "href");
};

if ($hsb["showServer"]) {
	// Memory, /proc is readable by everyone
	$mem = [];
	foreach (@file("/proc/meminfo") ?: [] as $line) {
		if (preg_match('/^(\w+):\s+(\d+)/', $line, $m)) {
			$mem[$m[1]] = (int) $m[2] / 1048576; // kB -> GB
		}
	}
	$gb = static fn(float $v): string => number_format($v, 1, ".", "") . " " . hsb_t("GB");

	$cores = preg_match_all('/^processor\s*:/m', (string) @file_get_contents("/proc/cpuinfo")) ?: 1;
	$load = function_exists("sys_getloadavg") ? sys_getloadavg() : false;
	if ($load !== false) {
		$hsb_meters[] = $hsb_meter(
			hsb_t("CPU load"),
			$load[0],
			$cores,
			number_format($load[0], 2, ".", "") . " · " . sprintf(hsb_t("%s cores"), $cores),
			"/list/rrd/",
		);
	}
	if (!empty($mem["MemTotal"])) {
		$used = $mem["MemTotal"] - ($mem["MemAvailable"] ?? $mem["MemFree"] ?? 0);
		$hsb_meters[] = $hsb_meter(
			_("Memory"),
			$used,
			$mem["MemTotal"],
			sprintf(hsb_t("%s of %s"), $gb($used), $gb($mem["MemTotal"])),
			"/list/rrd/",
		);
	}
	if (!empty($mem["SwapTotal"])) {
		$used = $mem["SwapTotal"] - ($mem["SwapFree"] ?? 0);
		$hsb_meters[] = $hsb_meter(
			hsb_t("Swap"),
			$used,
			$mem["SwapTotal"],
			sprintf(hsb_t("%s of %s"), $gb($used), $gb($mem["SwapTotal"])),
		);
	}
	// Each mounted disk once
	$seen = [];
	foreach (["/", "/home", "/backup"] as $mount) {
		$dev = @stat($mount)["dev"] ?? null;
		$total = $dev === null || isset($seen[$dev]) ? 0 : (float) @disk_total_space($mount);
		if ($total > 0) {
			$seen[$dev] = true;
			$used = $total - (float) @disk_free_space($mount);
			$hsb_meters[] = $hsb_meter(
				_("Disk") . " " . $mount,
				$used,
				$total,
				sprintf(hsb_t("%s of %s"), $gb($used / 1073741824), $gb($total / 1073741824)),
			);
		}
	}

	$sys = hsb_list("v-list-sys-info")["sysinfo"] ?? [];
	if ($sys) {
		$hsb_info = [
			_("Hostname") => $sys["HOSTNAME"] ?? "",
			_("Operating System") => trim(($sys["OS"] ?? "") . " " . ($sys["VERSION"] ?? "")),
			"Hestia" => "v" . ($sys["HESTIA"] ?? ""),
			_("Load Average") => $sys["LOADAVERAGE"] ?? "",
			_("Uptime") => humanize_time($hsb["showServer"] ? $hsb_num($sys["UPTIME"] ?? 0) : 0),
		];
	}
}

if ($hsb["asAdmin"]) {
	$accounts = hsb_list("v-list-users");
	// Same rule as the stock user list: hide the main account from other administrators
	if (hsb_opt("POLICY_SYSTEM_HIDE_ADMIN") === "yes" && hsb_opt("user") !== $hsb["root"]) {
		unset($accounts[$hsb["root"]]);
	}
	$sum = static fn(string $key): int => (int) array_sum(
		array_map(static fn(array $a): float => is_numeric($a[$key] ?? "") ? (float) $a[$key] : 0, $accounts),
	);
	$blocked = count(array_filter($accounts, static fn(array $a): bool => ($a["SUSPENDED"] ?? "") === "yes"));

	$hsb_tiles[] = [
		_("Users"), "fa-user-group", count($accounts), "/list/user/",
		$blocked ? sprintf(hsb_t("%s suspended"), $blocked) : hsb_t("None suspended"),
	];
	if ($hsb["has"]("WEB_SYSTEM")) {
		$hsb_tiles[] = [
			_("Web Domains"), "fa-earth-americas", $sum("U_WEB_DOMAINS"), "",
			sprintf(hsb_t("%s with SSL"), $sum("U_WEB_SSL")),
		];
	}
	if ($hsb["has"]("DB_SYSTEM")) {
		$hsb_tiles[] = [_("Databases"), "fa-database", $sum("U_DATABASES"), "", $hsb_size($sum("U_DISK_DB"))];
	}
	if ($hsb["has"]("MAIL_SYSTEM")) {
		$hsb_tiles[] = [
			_("Mail Accounts"), "fa-envelopes-bulk", $sum("U_MAIL_ACCOUNTS"), "",
			_("Mail Domains") . ": " . $sum("U_MAIL_DOMAINS"),
		];
	}
	if ($hsb["has"]("BACKUP_SYSTEM")) {
		$hsb_tiles[] = [_("Backups"), "fa-file-zipper", $sum("U_BACKUPS"), "", ""];
	}

	uasort($accounts, static fn(array $a, array $b): int => $hsb_num($b["U_DISK"] ?? 0) <=> $hsb_num($a["U_DISK"] ?? 0));
	$top = array_slice($accounts, 0, 5, true);
	$peak = max([1, ...array_map(static fn(array $a): float => $hsb_num($a["U_DISK"] ?? 0), array_values($top))]);
	foreach ($top as $login => $a) {
		$hsb_ranking[] = [
			"label" => $login,
			"percent" => ($hsb_num($a["U_DISK"] ?? 0) / $peak) * 100,
			"level" => "",
			"text" => $hsb_size($a["U_DISK"] ?? 0),
			"href" => hsb_url("/edit/user/", ["user" => $login, "token" => $hsb["token"]]),
		];
	}

	$hsb_actions = [
		[_("Add User"), "fa-circle-plus", "/add/user/", true],
		[_("Packages"), "fa-box-open", "/list/package/", true],
		[_("Firewall"), "fa-shield-halved", "/list/firewall/", $hsb["showServer"] && hsb_opt("FIREWALL_SYSTEM") === "iptables"],
		[_("Updates"), "fa-arrows-rotate", "/list/updates/", $hsb["showServer"]],
	];
} else {
	$u = $hsb["user"];
	$plan = [
		[_("Disk"), "U_DISK", "DISK_QUOTA", true, true, ""],
		[_("Bandwidth"), "U_BANDWIDTH", "BANDWIDTH", true, true, "/list/stats/"],
		[_("Web Domains"), "U_WEB_DOMAINS", "WEB_DOMAINS", false, $hsb["has"]("WEB_SYSTEM"), "/list/web/"],
		[_("DNS Zones"), "U_DNS_DOMAINS", "DNS_DOMAINS", false, $hsb["has"]("DNS_SYSTEM"), "/list/dns/"],
		[_("Mail Domains"), "U_MAIL_DOMAINS", "MAIL_DOMAINS", false, $hsb["has"]("MAIL_SYSTEM"), "/list/mail/"],
		[_("Databases"), "U_DATABASES", "DATABASES", false, $hsb["has"]("DB_SYSTEM"), "/list/db/"],
		[_("Cron Jobs"), "U_CRON_JOBS", "CRON_JOBS", false, $hsb["has"]("CRON_SYSTEM"), "/list/cron/"],
		[_("Backups"), "U_BACKUPS", "BACKUPS", false, $hsb["has"]("BACKUP_SYSTEM"), "/list/backup/"],
	];
	foreach ($plan as [$label, $usedKey, $maxKey, $isSize, $visible, $href]) {
		$max = (string) ($u[$maxKey] ?? "0");
		if (!$visible || (!$isSize && $max === "0")) {
			continue;
		}
		$used = $hsb_num($u[$usedKey] ?? 0);
		$show = static fn($v): string => $isSize ? $hsb_size($v) : (string) $v;
		$row = $hsb_meter(
			$label,
			$used,
			is_numeric($max) && $max > 0 ? (float) $max : null,
			is_numeric($max)
				? sprintf(hsb_t("%s of %s"), $show($used), $show($max))
				: $show($used) . " · " . hsb_t("No limit"),
			$href,
		);
		// A full count is normal (backups rotate); only disk and bandwidth deserve a warning
		if (!$isSize) {
			$row["level"] = "";
		}
		$hsb_meters[] = $row;
	}

	if ($hsb["has"]("WEB_SYSTEM") && $hsb["allowed"]("WEB_DOMAINS")) {
		foreach (array_slice(hsb_list("v-list-web-domains", $hsb["name"]), 0, 8, true) as $domain => $d) {
			$hsb_domains[] = [
				"name" => $domain,
				"ssl" => ($d["SSL"] ?? "") === "yes",
				"suspended" => ($d["SUSPENDED"] ?? "") === "yes",
				"disk" => $hsb_size($d["U_DISK"] ?? 0),
				"href" => hsb_url("/edit/web/", ["domain" => $domain, "token" => $hsb["token"]]),
			];
		}
	}

	$hsb_info = [
		_("Package") => $u["PACKAGE"] ?? "",
		_("IP Addresses") => $u["IP_AVAIL"] ?? "",
		_("Name Servers") => $hsb["has"]("DNS_SYSTEM") ? str_replace(",", ", ", $u["NS"] ?? "") : "",
	];

	$can = static fn(string $service, string $quota): bool => !$read_only && $hsb["has"]($service) && $hsb["allowed"]($quota);
	$hsb_actions = [
		[_("Add Web Domain"), "fa-circle-plus", "/add/web/", $can("WEB_SYSTEM", "WEB_DOMAINS")],
		[_("Add Database"), "fa-database", "/add/db/", $can("DB_SYSTEM", "DATABASES")],
		[_("Add Mail Domain"), "fa-envelopes-bulk", "/add/mail/", $can("MAIL_SYSTEM", "MAIL_DOMAINS")],
		[_("File manager"), "fa-folder-open", "/fm/", hsb_opt("FILE_MANAGER") === "true" && !$hsb["protectedRoot"]],
	];
}
