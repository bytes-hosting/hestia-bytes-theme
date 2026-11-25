<?php
// Shared by the menu and the dashboard.
if (!defined("HSB_LOADED")) {
	http_response_code(404);
	exit();
}

const HSB_DASHBOARD = "/js/custom_scripts/hestia-sidebar/dashboard.php";

function hsb_e($value): string {
	return htmlspecialchars((string) $value, ENT_QUOTES, "UTF-8");
}

function hsb_opt(string $key): string {
	return (string) ($_SESSION[$key] ?? "");
}

// Strings Hestia has no translation for; everything else goes through gettext.
function hsb_t(string $msg): string {
	static $own = [
		"uk" => [
			"Hosting" => "Хостинг",
			"Server" => "Сервер",
			"Monitoring" => "Моніторинг",
			"Tools" => "Інструменти",
			"White Label" => "White Label",
			"SSH Keys" => "Ключі SSH",
			"Find a tool" => "Знайти інструмент",
			"Nothing found" => "Нічого не знайдено",
			"Expand" => "Розгорнути",
			"Collapse" => "Згорнути",
			"Dashboard" => "Дашборд",
			"Resource usage" => "Використання ресурсів",
			"CPU load" => "Навантаження CPU",
			"Swap" => "Swap",
			"%s of %s" => "%s з %s",
			"%s suspended" => "заблоковано: %s",
			"None suspended" => "заблокованих немає",
			"%s with SSL" => "із SSL: %s",
			"High" => "Високе",
			"Critical" => "Критичне",
			"Load over 24 hours" => "Навантаження за 24 години",
			"Memory used over 24 hours" => "Зайнята пам'ять за 24 години",
			"GB" => "ГБ",
			"No data yet" => "Даних ще немає",
			"Could not load" => "Не вдалося завантажити",
			"Show as table" => "Показати таблицею",
			"Time" => "Час",
			"Value" => "Значення",
			"%s of %s running" => "працюють %s з %s",
			"Running" => "працює",
			"Stopped" => "зупинено",
			"Accounts by disk usage" => "Облікові записи за диском",
			"Plan usage" => "Використання тарифу",
			"No limit" => "без ліміту",
			"All domains" => "Усі домени",
			"All accounts" => "Усі акаунти",
			"No domains yet" => "Доменів ще немає",
			"No SSL" => "без SSL",
			"Paused" => "призупинено",
			"%s cores" => "ядер: %s",
		],
	];
	$lang = hsb_opt("language") ?: hsb_opt("LANGUAGE");
	return $own[$lang][$msg] ?? _($msg);
}

/**
 * Who is looking and what they may see. Same rules as web/templates/includes/panel.php.
 * This decides only what is shown: access itself is enforced by the Hestia pages.
 */
function hsb_context(): array {
	$look = hsb_opt("look");
	$name = $look !== "" ? $look : hsb_opt("user");
	$root = hsb_opt("ROOT_USER");
	$isAdmin = hsb_opt("userContext") === "admin";
	$impersonating = $isAdmin && $look !== "";
	// Cached by Hestia: top_panel() asks for the same record, so this adds no extra command.
	$record = get_user_data($name)[$name] ?? [];

	return [
		"name" => $name,
		"root" => $root,
		"token" => hsb_opt("token"),
		"user" => $record,
		"isAdmin" => $isAdmin,
		"asAdmin" => $isAdmin && !$impersonating,
		"protectedRoot" =>
			$impersonating && $look === $root && hsb_opt("POLICY_SYSTEM_PROTECTED_ADMIN") === "yes",
		// Keys of ROOT_USER are closed to other administrators, see is_protected_root_target()
		"ownKeys" => !($isAdmin && $name === $root && hsb_opt("user") !== $root),
		"activeAccount" => ($record["SUSPENDED"] ?? "no") === "no",
		"showServer" =>
			!$impersonating &&
			(($isAdmin && hsb_opt("POLICY_SYSTEM_HIDE_SERVICES") !== "yes") || hsb_opt("user") === $root),
		"showLogs" => $isAdmin || hsb_opt("POLICY_USER_VIEW_LOGS") !== "no",
		"has" => static fn(string $service): bool => hsb_opt($service) !== "",
		"allowed" => static fn(string $quota): bool => ($record[$quota] ?? "0") !== "0",
	];
}

function hsb_url(string $path, array $args): string {
	return $path . "?" . http_build_query($args);
}

/** True for the first list page Hestia opens right after a sign-in: that visit goes to the dashboard. */
function hsb_is_landing(): bool {
	$from = parse_url($_SERVER["HTTP_REFERER"] ?? "");
	$host = preg_replace('/:\d+$/', "", $_SERVER["HTTP_HOST"] ?? "");
	return ($_SERVER["REQUEST_METHOD"] ?? "") === "GET" &&
		hsb_opt("look") === "" &&
		($from["host"] ?? "") === $host &&
		in_array($from["path"] ?? "", ["/login/", "/login"], true) &&
		preg_match('#^/list/(user|web|dns|mail|db|cron|backup)/$#', $_SERVER["REQUEST_URI"] ?? "") === 1;
}
