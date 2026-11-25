<?php
// Builds the sidebar HTML and returns it as a string. Included by ../hestia-sidebar.php.
if (!defined("HSB_LOADED")) {
	http_response_code(404);
	exit();
}

$c = hsb_context();
extract($c, EXTR_PREFIX_ALL, "c");
$u = $c_user;
$has = $c_has;
$allowed = $c_allowed;
$apiLevel = (int) hsb_opt("API_SYSTEM");

// item: [label, icon, href, url prefixes that make it active, badge, visible]
$menu = [
	"accounts" => [
		"label" => hsb_t("Accounts"),
		"icon" => "fa-users",
		"show" => $c_asAdmin,
		"items" => [
			[hsb_t("Users"), "fa-user-group", "/list/user/", ["/edit/user/"], $u["U_USERS"] ?? ""],
			[hsb_t("Add User"), "fa-user-plus", "/add/user/"],
			[hsb_t("Packages"), "fa-box-open", "/list/package/", ["/add/package/", "/edit/package/"]],
		],
	],
	"hosting" => [
		"label" => hsb_t("Hosting"),
		"icon" => "fa-earth-americas",
		"show" => true,
		"items" => [
			[
				hsb_t("Web Domains"),
				"fa-earth-americas",
				"/list/web/",
				["/add/web/", "/edit/web/", "/add/webapp/", "/list/web-log/", "/generate/ssl/"],
				$u["U_WEB_DOMAINS"] ?? "",
				$has("WEB_SYSTEM") && $allowed("WEB_DOMAINS"),
			],
			[
				hsb_t("DNS Zones"),
				"fa-book-atlas",
				"/list/dns/",
				["/add/dns/", "/edit/dns/"],
				$u["U_DNS_DOMAINS"] ?? "",
				$has("DNS_SYSTEM") && $allowed("DNS_DOMAINS"),
			],
			[
				hsb_t("Mail Domains"),
				"fa-envelopes-bulk",
				"/list/mail/",
				["/add/mail/", "/edit/mail/"],
				$u["U_MAIL_DOMAINS"] ?? "",
				$has("MAIL_SYSTEM") && $allowed("MAIL_DOMAINS"),
			],
			[
				hsb_t("Databases"),
				"fa-database",
				"/list/db/",
				["/add/db/", "/edit/db/"],
				$u["U_DATABASES"] ?? "",
				$has("DB_SYSTEM") && $allowed("DATABASES"),
			],
			[
				hsb_t("Cron Jobs"),
				"fa-clock",
				"/list/cron/",
				["/add/cron/", "/edit/cron/"],
				$u["U_CRON_JOBS"] ?? "",
				$has("CRON_SYSTEM") && $allowed("CRON_JOBS"),
			],
			[
				hsb_t("Backups"),
				"fa-file-zipper",
				"/list/backup/",
				["/edit/backup/"],
				$u["U_BACKUPS"] ?? "",
				$has("BACKUP_SYSTEM") &&
				($allowed("BACKUPS") ||
					($u["U_BACKUPS"] ?? "0") !== "0" ||
					($u["BACKUPS_INCREMENTAL"] ?? "") === "yes"),
			],
		],
	],
	"tools" => [
		"label" => hsb_t("Tools"),
		"icon" => "fa-toolbox",
		"show" => true,
		"items" => [
			[
				hsb_t("File manager"),
				"fa-folder-open",
				"/fm/",
				[],
				"",
				hsb_opt("FILE_MANAGER") === "true" && !$c_protectedRoot,
			],
			[
				hsb_t("Web terminal"),
				"fa-terminal",
				"/list/terminal/",
				[],
				"",
				hsb_opt("WEB_TERMINAL") === "true" && !$c_protectedRoot && hsb_opt("login_shell") !== "nologin",
			],
			[
				hsb_t("SSH Keys"),
				"fa-key",
				"/list/key/",
				["/add/key/"],
				"",
				$c_ownKeys && $c_activeAccount,
			],
			[
				hsb_t("Access Keys"),
				"fa-id-badge",
				"/list/access-key/",
				["/add/access-key/"],
				"",
				$c_ownKeys && $c_activeAccount && ($c_name === $c_root ? $apiLevel > 0 : $apiLevel > 1),
			],
			[
				hsb_t("Account"),
				"fa-circle-user",
				hsb_url("/edit/user/", ["user" => $c_name, "token" => $c_token]),
				[],
				"",
				!$c_asAdmin && !$c_protectedRoot && $c_activeAccount,
			],
			[hsb_t("Statistics"), "fa-chart-line", "/list/stats/", [], "", !$c_showServer],
			[hsb_t("Logs"), "fa-clock-rotate-left", "/list/log/", [], "", $c_showLogs && !$c_showServer],
		],
	],
	"server" => [
		"label" => hsb_t("Server"),
		"icon" => "fa-server",
		"show" => $c_showServer,
		"items" => [
			[hsb_t("Services"), "fa-server", "/list/server/"],
			[hsb_t("Configure"), "fa-gear", "/edit/server/"],
			[hsb_t("Network"), "fa-ethernet", "/list/ip/", ["/add/ip/", "/edit/ip/"]],
			[hsb_t("Updates"), "fa-arrows-rotate", "/list/updates/"],
			[hsb_t("White Label"), "fa-paint-brush", "/edit/server/whitelabel/"],
			[hsb_t("Panel Cronjobs"), "fa-calendar-days", "/edit/server/hestiaweb/"],
		],
	],
	"security" => [
		"label" => hsb_t("Security"),
		"icon" => "fa-shield-halved",
		"show" => $c_showServer && hsb_opt("FIREWALL_SYSTEM") === "iptables",
		"items" => [
			[hsb_t("Firewall"), "fa-shield-halved", "/list/firewall/", ["/add/firewall/", "/edit/firewall/"]],
			[
				hsb_t("Banned IP Addresses"),
				"fa-ban",
				"/list/firewall/banlist/",
				["/add/firewall/banlist/"],
				"",
				$has("FIREWALL_EXTENSION"),
			],
			[hsb_t("IPset IP Lists"), "fa-list", "/list/firewall/ipset/", ["/add/firewall/ipset/"]],
		],
	],
	"monitoring" => [
		"label" => hsb_t("Monitoring"),
		"icon" => "fa-chart-line",
		"show" => $c_showServer,
		"items" => [
			[hsb_t("Task Monitor"), "fa-chart-area", "/list/rrd/"],
			[hsb_t("Statistics"), "fa-chart-line", "/list/stats/"],
			[
				hsb_t("Logs"),
				"fa-clock-rotate-left",
				hsb_url("/list/log/", ["user" => "system", "token" => $c_token]),
			],
			[hsb_t("Login History"), "fa-right-to-bracket", "/list/log/auth/"],
		],
	],
];

// Find the active item: the longest matching URL prefix wins.
$path = parse_url($_SERVER["REQUEST_URI"] ?? "/", PHP_URL_PATH) ?: "/";
$active = null;
$best = 0;
foreach ($menu as $key => &$group) {
	$group["items"] = array_filter($group["items"], static fn(array $i): bool => $i[5] ?? true);
	if (!$group["show"] || !$group["items"]) {
		unset($menu[$key]);
		continue;
	}
	foreach ($group["items"] as $n => $item) {
		$prefixes = array_merge([strtok($item[2], "?")], $item[3] ?? []);
		foreach ($prefixes as $prefix) {
			if (str_starts_with($path, $prefix) && strlen($prefix) > $best) {
				$best = strlen($prefix);
				$active = [$key, $n];
			}
		}
	}
}
unset($group);

$appName = hsb_opt("APP_NAME") ?: "Hestia Control Panel";
// The wide logo is ours; without it (never installed, or reset in white-label settings) Hestia's header logo is used
$logo = "/images/custom/logo-sidebar.svg";
$logoTime = @filemtime($_SERVER["DOCUMENT_ROOT"] . $logo);
$logo = $logoTime ? "$logo?$logoTime" : "/images/logo-header.svg";

ob_start();
?>
<button type="button" class="hsb-toggle" aria-controls="hsb" aria-expanded="false" title="<?= hsb_e(_("Open menu")) ?>">
	<i class="fas fa-bars"></i><span class="u-hidden-visually"><?= hsb_e(_("Open menu")) ?></span>
</button>
<div class="hsb-backdrop"></div>
<aside class="hsb-sidebar" id="hsb">
	<a href="<?= HSB_DASHBOARD ?>" class="hsb-logo" title="<?= hsb_e($appName) ?>">
		<img src="<?= hsb_e($logo) ?>" alt="<?= hsb_e($appName) ?>" height="36">
	</a>
	<div class="hsb-search">
		<i class="fas fa-magnifying-glass"></i>
		<input type="search" class="hsb-search-input" placeholder="<?= hsb_e(hsb_t("Find a tool")) ?>" aria-label="<?= hsb_e(hsb_t("Find a tool")) ?>" autocomplete="off">
		<kbd>/</kbd>
	</div>
	<div class="hsb-fold">
		<button type="button" data-hsb-fold="open"><?= hsb_e(hsb_t("Expand")) ?></button>
		<button type="button" data-hsb-fold="close"><?= hsb_e(hsb_t("Collapse")) ?></button>
	</div>
	<nav class="hsb-nav">
		<a href="<?= HSB_DASHBOARD ?>" class="hsb-link hsb-home<?= $path === HSB_DASHBOARD ? " is-active" : "" ?>"<?= $path === HSB_DASHBOARD ? ' aria-current="page"' : "" ?>>
			<i class="fas fa-gauge-high"></i>
			<span class="hsb-link-label"><?= hsb_e(hsb_t("Dashboard")) ?></span>
		</a>
		<?php foreach ($menu as $key => $group) {
  	$open = ($active[0] ?? "") === $key || in_array($key, ["accounts", "hosting"], true); ?>
		<details class="hsb-group" data-key="<?= hsb_e($key) ?>"<?= $open ? " open" : "" ?><?= ($active[0] ?? "") === $key ? " data-active" : "" ?>>
			<summary><i class="fas <?= hsb_e($group["icon"]) ?>"></i><span><?= hsb_e($group["label"]) ?></span></summary>
			<ul>
				<?php foreach ($group["items"] as $n => $item) {
    	$isActive = $active === [$key, $n]; ?>
				<li>
					<a href="<?= hsb_e($item[2]) ?>" class="hsb-link<?= $isActive ? " is-active" : "" ?>"<?= $isActive ? ' aria-current="page"' : "" ?>>
						<i class="fas <?= hsb_e($item[1]) ?>"></i>
						<span class="hsb-link-label"><?= hsb_e($item[0]) ?></span>
						<?php if (($item[4] ?? "") !== "") { ?><span class="hsb-badge"><?= hsb_e($item[4]) ?></span><?php } ?>
					</a>
				</li>
				<?php } ?>
			</ul>
		</details>
		<?php } ?>
		<p class="hsb-empty" hidden><?= hsb_e(hsb_t("Nothing found")) ?></p>
	</nav>
</aside>
<script>
	// Runs before first paint so that saved groups do not jump.
	(() => {
		try {
			const saved = JSON.parse(localStorage.getItem('hsb.groups') || '{}');
			document.querySelectorAll('.hsb-group').forEach((el) => {
				const key = el.dataset.key;
				if (key in saved) el.open = saved[key] || el.hasAttribute('data-active');
			});
			document.querySelector('.hsb-nav').scrollTop = +sessionStorage.getItem('hsb.scroll') || 0;
			document.querySelector('.hsb-link.is-active')?.scrollIntoView({ block: 'nearest' });
		} catch (e) {}
	})();
</script>
<?php return ob_get_clean();
