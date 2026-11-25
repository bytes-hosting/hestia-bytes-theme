<?php
// Template, included by render_page() from dashboard.php
if (!defined("HSB_LOADED")) {
	http_response_code(404);
	exit();
}

$hsb_asset = static fn(string $file): string => "/js/custom_scripts/hestia-sidebar/$file?v=" .
	(@filemtime(__DIR__ . "/$file") ?: 0);

$hsb_list_rows = static function (array $rows): void {
	foreach ($rows as $row) {
		$icon = ["warn" => "fa-triangle-exclamation", "crit" => "fa-circle-exclamation"][$row["level"]] ?? "";
		$word = ["warn" => hsb_t("High"), "crit" => hsb_t("Critical")][$row["level"]] ?? "";
		?>
		<li class="hsb-meter<?= $row["level"] ? " is-" . $row["level"] : "" ?>">
			<span class="hsb-meter-label">
				<?php if ($row["href"]) { ?><a href="<?= hsb_e($row["href"]) ?>"><?= hsb_e($row["label"]) ?></a><?php } else {echo hsb_e($row["label"]);} ?>
				<?php if ($word) { ?><span class="hsb-meter-state"><i class="fas <?= $icon ?>"></i> <?= hsb_e($word) ?></span><?php } ?>
			</span>
			<span class="hsb-meter-text"><?= hsb_e($row["text"]) ?></span>
			<?php if ($row["percent"] !== null) { ?>
			<span class="hsb-meter-track" aria-hidden="true"><span style="width: <?= number_format($row["percent"], 1, ".", "") ?>%"></span></span>
			<?php } ?>
		</li>
		<?php
	}
};
?>
<link rel="stylesheet" href="<?= $hsb_asset("dashboard.css") ?>">
<script defer src="<?= $hsb_asset("dashboard.js") ?>"></script>

<div class="container hsb-dash"
	data-no-data="<?= hsb_e(hsb_t("No data yet")) ?>"
	data-failed="<?= hsb_e(hsb_t("Could not load")) ?>"
	data-running="<?= hsb_e(hsb_t("Running")) ?>"
	data-stopped="<?= hsb_e(hsb_t("Stopped")) ?>"
	data-summary="<?= hsb_e(hsb_t("%s of %s running")) ?>">

	<div class="hsb-dash-head">
		<h1><?= hsb_e(hsb_t("Dashboard")) ?></h1>
		<div class="hsb-dash-actions">
			<?php foreach ($hsb_actions as [$label, $icon, $href, $visible]) {
   	if ($visible) { ?>
			<a href="<?= hsb_e($href) ?>" class="button button-secondary"><i class="fas <?= $icon ?>"></i><?= hsb_e($label) ?></a>
			<?php }
   } ?>
		</div>
	</div>

	<?php if ($hsb_tiles) { ?>
	<div class="hsb-tiles">
		<?php foreach ($hsb_tiles as [$label, $icon, $value, $href, $note]) {
  	$tag = $href ? "a" : "div"; ?>
		<<?= $tag ?> class="hsb-tile"<?= $href ? ' href="' . hsb_e($href) . '"' : "" ?>>
			<span class="hsb-tile-label"><i class="fas <?= $icon ?>"></i><?= hsb_e($label) ?></span>
			<span class="hsb-tile-value"><?= hsb_e($value) ?></span>
			<span class="hsb-tile-note"><?= hsb_e($note) ?></span>
		</<?= $tag ?>>
		<?php
  } ?>
	</div>
	<?php } ?>

	<div class="hsb-grid">
		<div>
		<?php if ($hsb_meters) { ?>
		<section class="hsb-card">
			<h2><?= hsb_e($hsb["showServer"] ? hsb_t("Resource usage") : hsb_t("Plan usage")) ?></h2>
			<ul><?php $hsb_list_rows($hsb_meters); ?></ul>
		</section>
		<?php } ?>

		<?php if ($hsb["showServer"] && $hsb["isAdmin"]) {
  	foreach ([["la", hsb_t("Load over 24 hours"), ""], ["mem", hsb_t("Memory used over 24 hours"), hsb_t("GB")]] as [$service, $title, $unit]) { ?>
		<section class="hsb-card" data-hsb-chart="<?= $service ?>" data-unit="<?= hsb_e($unit) ?>">
			<h2><?= hsb_e($title) ?><?= $unit ? ", " . hsb_e($unit) : "" ?></h2>
			<div class="hsb-chart"><p class="hsb-muted"><?= hsb_e(_("Loading...")) ?></p></div>
			<details class="hsb-chart-table" hidden>
				<summary><?= hsb_e(hsb_t("Show as table")) ?></summary>
				<div><table><thead><tr><th><?= hsb_e(hsb_t("Time")) ?></th><th><?= hsb_e(hsb_t("Value")) ?></th></tr></thead><tbody></tbody></table></div>
			</details>
		</section>
		<?php }
  } ?>
		</div>
		<div>
		<?php if ($hsb["showServer"]) { ?>
		<section class="hsb-card" data-hsb-services="<?= hsb_e(HSB_DASHBOARD) ?>?part=services">
			<h2><a href="/list/server/"><?= hsb_e(_("Services")) ?></a><span class="hsb-card-note"></span></h2>
			<ul class="hsb-services"><li class="hsb-muted"><?= hsb_e(_("Loading...")) ?></li></ul>
		</section>
		<?php } ?>

		<?php if (!$hsb["asAdmin"] && $hsb["has"]("WEB_SYSTEM") && $hsb["allowed"]("WEB_DOMAINS")) { ?>
		<section class="hsb-card">
			<h2><?= hsb_e(_("Web Domains")) ?><a class="hsb-card-note" href="/list/web/"><?= hsb_e(hsb_t("All domains")) ?></a></h2>
			<ul class="hsb-rows">
				<?php foreach ($hsb_domains as $d) { ?>
				<li>
					<a href="<?= hsb_e($d["href"]) ?>"><?= hsb_e($d["name"]) ?></a>
					<?php if ($d["suspended"]) { ?>
					<span class="hsb-state is-off"><i class="fas fa-pause"></i><?= hsb_e(hsb_t("Paused")) ?></span>
					<?php } ?>
					<span class="hsb-state <?= $d["ssl"] ? "is-ok" : "is-off" ?>"><i class="fas <?= $d["ssl"] ? "fa-lock" : "fa-lock-open" ?>"></i><?= hsb_e($d["ssl"] ? "SSL" : hsb_t("No SSL")) ?></span>
					<span class="hsb-num"><?= hsb_e($d["disk"]) ?></span>
				</li>
				<?php } ?>
				<?php if (!$hsb_domains) { ?><li class="hsb-muted"><?= hsb_e(hsb_t("No domains yet")) ?></li><?php } ?>
			</ul>
		</section>
		<?php } ?>

		<?php if ($hsb_ranking) { ?>
		<section class="hsb-card">
			<h2><?= hsb_e(hsb_t("Accounts by disk usage")) ?><a class="hsb-card-note" href="/list/user/"><?= hsb_e(hsb_t("All accounts")) ?></a></h2>
			<ul class="hsb-ranking"><?php $hsb_list_rows($hsb_ranking); ?></ul>
		</section>
		<?php } ?>

		<?php if ($hsb_info = array_filter($hsb_info, static fn($v): bool => (string) $v !== "")) { ?>
		<section class="hsb-card">
			<h2><?= hsb_e($hsb["showServer"] ? hsb_t("Server") : _("Account")) ?></h2>
			<dl class="hsb-info">
				<?php foreach ($hsb_info as $label => $value) { ?>
				<div><dt><?= hsb_e($label) ?></dt><dd><?= hsb_e($value) ?></dd></div>
				<?php } ?>
			</dl>
		</section>
		<?php } ?>
		</div>
	</div>
</div>
