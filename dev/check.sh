#!/usr/bin/env bash
# Does the addon work with a given Hestia version? Run before upgrading a server.
#   dev/check.sh                 the latest Hestia release
#   dev/check.sh 1.10.8 main     these tags or branches
#   HESTIA_SRC=/path dev/check.sh   a local Hestia checkout
# Exit code 0: everything passed. Works on a copy of src/, the working tree is not touched.
set -uo pipefail
cd "$(dirname "$0")/.."
IMAGE="${PHP_IMAGE:-sail-8.5/app:latest}"
WORK="$PWD/.cache/check-$$"
NAME="hsb-check-$$"
ADDON=/js/custom_scripts/hestia-sidebar
DASH=$ADDON/dashboard.php
OUT="$WORK/out"
failed=0
passed=0

cleanup() {
	docker rm -f "$NAME" > /dev/null 2>&1
	rm -rf "$WORK"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

ok() { passed=$((passed + 1)); [ -z "${VERBOSE:-}" ] || echo "  ok    $1"; }
bad() { failed=$((failed + 1)); echo "  FAIL  $1"; }
# is "what" expected actual
is() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1: expected '$2', got '$3'"; fi; }
# in_file "what" file pattern
in_file() { if grep -qE -- "$3" "$H/$2" 2> /dev/null; then ok "$1"; else bad "$1: no /$3/ in $2"; fi; }

# req account look theme path [curl options]: prints "code path-of-redirect", the body goes to $OUT
req() {
	local as=$1 look=$2 theme=$3 path=$4
	shift 4
	curl -s -m 60 -o "$OUT" -w '%{http_code} %{redirect_url}' -e "$BASE/" \
		-b "dev_as=$as;dev_look=$look;dev_theme=$theme;dev_lang=uk" "$@" "$BASE$path" | sed "s#$BASE##; s/ *\$//"
}
has() { grep -cE -- "$1" "$OUT" | sed 's/^[1-9][0-9]*$/yes/; s/^0$/no/'; }
# sign_in: follow redirects like a browser that has just submitted the login form
sign_in() {
	curl -s -m 60 -L --max-redirs 6 -o "$OUT" -w '%{http_code} %{url_effective}' -e "$BASE/login/" \
		-b "dev_as=admin;dev_look=;dev_theme=sidebar;dev_lang=uk" "$BASE/list/user/" | sed "s#$BASE##"
}

# What the addon relies on inside Hestia, so that a failure names its cause
check_sources() {
	in_file "custom PHP scripts are loaded" web/templates/includes/js.php 'custom_scripts'
	in_file "custom PHP scripts are included" web/templates/includes/js.php 'require(_once)? .*getPathname'
	in_file "custom themes are loaded" web/templates/includes/css.php 'css/themes/custom/'
	in_file "sidebar insertion point" web/templates/header.php '<div class="app">'
	in_file "render_page()" web/inc/main.php 'function render_page\(\$user, \$TAB, \$page\)'
	in_file "page templates path" web/inc/main.php '"pages/" \. \$page \. "\.php"'
	in_file "get_user_data()" web/inc/main.php 'function get_user_data\('
	in_file "read-only flag" web/inc/policies.php '\$read_only'
	for f in humanize_usage_size humanize_usage_measure humanize_time; do
		in_file "$f()" web/inc/main.php "function $f\\("
	done
	in_file "top menu for shortcuts" web/templates/includes/panel.php 'class="main-menu"'
	in_file "top bar" web/templates/includes/panel.php 'class="top-bar"'
	in_file "chart data endpoint" web/list/rrd/ajax.php 'v-export-rrd'
	in_file "load is stored * 100" bin/v-update-sys-rrd-la 'la//\./|LA \* 100'
	for c in v-list-user v-list-users v-list-web-domains v-list-sys-info v-list-sys-services v-export-rrd; do
		if [ -f "$H/bin/$c" ]; then ok "$c"; else bad "command $c is gone"; fi
	done
	for k in U_WEB_DOMAINS U_WEB_SSL U_DATABASES U_DISK_DB U_MAIL_ACCOUNTS U_MAIL_DOMAINS U_BACKUPS U_DISK SUSPENDED; do
		in_file "v-list-users: $k" bin/v-list-users "\"$k\""
	done
	for k in U_USERS DISK_QUOTA BANDWIDTH U_BANDWIDTH WEB_DOMAINS DNS_DOMAINS MAIL_DOMAINS DATABASES CRON_JOBS BACKUPS PACKAGE NS IP_AVAIL; do
		in_file "v-list-user: $k" bin/v-list-user "\"$k\""
	done
	for k in HOSTNAME OS VERSION HESTIA LOADAVERAGE UPTIME; do in_file "v-list-sys-info: $k" bin/v-list-sys-info "\"$k\""; done
	for k in STATE SYSTEM; do in_file "v-list-sys-services: $k" bin/v-list-sys-services "\"$k\""; done
	for i in $(grep -rhoE 'fa-[a-z][a-z-]+' src --include='*.php' --include='*.js' | sort -u); do
		in_file "icon $i" web/css/themes/default.min.css "\\.$i[,{:]"
	done
	for f in logo.svg logo.png logo-header.svg favicon.png favicon.ico; do
		in_file "white-label command: $f" bin/v-update-white-label-logo "web/images/custom/$f"
	done
	in_file "white-label is repeated after an upgrade" func/upgrade.sh 'v-update-white-label-logo'
	in_file "logo on the login page" web/templates/pages/login/login.php '"/images/logo\.svg"'
	in_file "tab icon" web/templates/includes/css.php '"/images/favicon\.png"'
	# Every menu link must still lead to a page
	for p in $(grep -oE '"/(list|add|edit)/[a-z/-]+/"' src/custom_scripts/hestia-sidebar/{menu,dashboard-data}.php -h | tr -d '"' | sort -u); do
		if [ -f "$H/web$p/index.php" ] || [ -d "$H/web$p" ]; then ok "page $p"; else bad "page $p is gone"; fi
	done
}

# No page may change its answer because of the addon
check_pages() {
	local as p stock ours stock_end
	for as in admin demo; do
		for p in $(cd "$H/web" && find list add edit -name index.php | sed 's#index.php$##; s#^#/#' | sort); do
			stock=$(req $as "" dark "$p")
			stock_end=$(has '</html>') # some stock pages stop halfway here: no restic, no vendor packages
			[ "$(has 'hsb-|hestia-sidebar')" = no ] || bad "$as $p: the addon leaks into another theme"
			ours=$(req $as "" sidebar "$p")
			if [ "$ours" != "$stock" ]; then
				bad "$as $p: '$stock' with a stock theme, '$ours' with sidebar"
			elif [ "${ours%% *}" = 200 ] && grep -q '<div class="app' "$OUT"; then
				if [ "$(has 'id="hsb"')$(has '</html>')" = "yes$stock_end" ]; then ok "$as $p"; else bad "$as $p: no sidebar, or the page is cut off"; fi
			else
				ok "$as $p"
			fi
		done
	done
}

check_access() {
	is "admin dashboard" 200 "$(req admin "" sidebar $DASH)"
	is "  complete" yes "$(has '</html>')"
	is "  tiles, services and charts" yesyesyes "$(has 'class="hsb-tile"')$(has data-hsb-services)$(has 'data-hsb-chart="mem"')"
	is "  menu item is active" yes "$(has 'hsb-home is-active')"
	is "user dashboard" 200 "$(req demo "" sidebar $DASH)"
	is "  own domains" yes "$(has shop.example.com)"
	is "  no server data" no "$(has 'data-hsb-services|data-hsb-chart|panel\.example\.com')"
	is "admin signed in as a user" 200 "$(req admin demo sidebar $DASH)"
	is "  no server data" no "$(has 'data-hsb-services|data-hsb-chart|panel\.example\.com')"
	is "signed out: dashboard" "302 /login/" "$(req nobody "" sidebar $DASH)"
	is "signed out: services" "302 /login/" "$(req nobody "" sidebar "$DASH?part=services")"
	is "admin: services" 200 "$(req admin "" sidebar "$DASH?part=services")"
	is "  JSON" yes "$(has '^\[\{"name":.*"running":(true|false)')"
	is "user: services" 403 "$(req demo "" sidebar "$DASH?part=services")"
	is "as a user: services" 403 "$(req admin demo sidebar "$DASH?part=services")"
	is "admin: chart data" 200 "$(req admin "" sidebar /list/rrd/ajax.php -X POST -H 'Content-Type: application/json' -d '{"service":"la","period":"daily"}')"
	is "  step, start and rows" yes "$(has '"start":[0-9]+.*"step":[0-9]+.*"data":\[\[')"
	is "another theme, admin" "302 /list/user/?hsb=0" "$(req admin "" dark $DASH)"
	is "another theme, user" "302 /list/web/?hsb=0" "$(req demo "" dark $DASH)"
	is "login page" 200 "$(req nobody "" sidebar /login/)"
	is "  skin without a sidebar" yesno "$(has hestia-sidebar/ui.css)$(has 'id="hsb"')"
	local f
	for f in "$WORK"/src/custom_scripts/hestia-sidebar/*.php; do
		f=$(basename "$f")
		[ "$f" = dashboard.php ] || is "direct request to $f" 404 "$(req admin "" sidebar "$ADDON/$f")"
	done
	is "direct request to the loader" 404 "$(req admin "" sidebar /js/custom_scripts/hestia-sidebar.php)"
}

check_menu() {
	req admin "" sidebar /list/firewall/ > /dev/null
	is "admin menu groups" "accounts hosting tools server security monitoring" "$(grep -oE 'data-key="[a-z]+"' "$OUT" | cut -d'"' -f2 | xargs)"
	is "active item" /list/firewall/ "$(grep -oE 'href="[^"?]+[^"]*" class="hsb-link is-active"' "$OUT" | cut -d'"' -f2)"
	req demo "" sidebar /list/web/ > /dev/null
	is "user menu groups" "hosting tools" "$(grep -oE 'data-key="[a-z]+"' "$OUT" | cut -d'"' -f2 | xargs)"
	req admin demo sidebar /list/web/ > /dev/null
	is "menu when signed in as a user" "hosting tools" "$(grep -oE 'data-key="[a-z]+"' "$OUT" | cut -d'"' -f2 | xargs)"
}

check_logo() {
	req admin "" sidebar /list/user/ > /dev/null
	is "logo in the menu" yes "$(has 'src="/images/custom/logo-sidebar\.svg\?[0-9]+"')"
	is "  loads" 200 "$(req admin "" sidebar /images/custom/logo-sidebar.svg)"
	local f
	for f in images/logo.svg images/logo.png images/logo-header.svg images/favicon.png favicon.ico; do
		is "/$f is ours" "200 yes" "$(req nobody "" sidebar "/$f") $(cmp -s "$OUT" "src/images/${f##*/}" && echo yes)"
	done
	rm "$WORK/src/images/logo-sidebar.svg"
	req admin "" sidebar /list/user/ > /dev/null
	is "no wide logo: Hestia's header logo" yes "$(has 'src="/images/logo-header\.svg"')"
	cp src/images/logo-sidebar.svg "$WORK/src/images/"
}

check_landing() {
	is "landing after sign-in" "200 $DASH" "$(sign_in)"
	is "landing for a user" "302 $DASH" "$(req demo "" sidebar /list/web/ -e "$BASE/login/")"
	is "no landing from a panel page" 200 "$(req admin "" sidebar /list/user/ -e "$BASE/list/web/")"
	is "no landing from another site" 200 "$(req admin "" sidebar /list/user/ -e http://other.example/login/)"
	is "no landing with another theme" 200 "$(req admin "" dark /list/user/ -e "$BASE/login/")"
	is "no landing as a user" 200 "$(req admin demo sidebar /list/web/ -e "$BASE/login/")"
}

# Break one file and sign in: the visitor must still get a complete page
# breaks "what" file content expected-path sidebar(yes|no)
breaks() {
	local file="$WORK/src/custom_scripts/hestia-sidebar/$2"
	printf '%s' "$3" > "$file"
	is "$1: page" "200 $4" "$(sign_in)"
	is "$1: complete, sidebar, nothing leaked" "yes$5no" "$(has '</html>')$(has 'id="hsb"')$(has BROKEN)"
	cp "src/custom_scripts/hestia-sidebar/$2" "$file"
}
check_failures() {
	local home="/list/user/?hsb=0"
	breaks "dashboard data throws" dashboard-data.php '<?php throw new Exception("test");' "$home" yes
	breaks "dashboard data does not parse" dashboard-data.php '<?php $x = [;' "$home" yes
	breaks "dashboard view throws" dashboard-view.php 'BROKEN<?php throw new Exception("test");' "$home" yes
	breaks "dashboard body does not parse" dashboard-main.php '<?php $x = [;' "$home" yes
	breaks "menu throws" menu.php '<?php ob_start(); echo "BROKEN"; throw new Exception("test");' "$DASH" no
	breaks "library does not parse" lib.php '<?php function (;' /list/user/ no
	is "healthy again" "200 $DASH" "$(sign_in)"
}

check_install() {
	local out
	out=$(docker run --rm --entrypoint bash -v "$PWD:/repo:ro" -v "$H:/hestia:ro" "$IMAGE" /repo/dev/check-install.sh 2>&1)
	is "install and uninstall" OK "$(echo "$out" | tail -1)"
	[ "$(echo "$out" | tail -1)" = OK ] || echo "$out" | tail -12 | sed 's/^/        /'
}

check_version() {
	local ref=$1 before=$failed start=$passed
	H="$PWD/.cache/hestia-$ref"
	echo "Hestia $ref"
	case "$ref" in
		[0-9]*.[0-9]*.[0-9]*) ;;      # a release never changes, keep it
		*) rm -rf "$H" ;;             # branches and local sources are always fresh
	esac
	if [ ! -d "$H" ]; then
		mkdir -p "$WORK"
		if ! HESTIA_REF="$ref" HESTIA_DIR="$H" dev/setup.sh > "$WORK/setup.log" 2>&1; then
			bad "could not fetch or build Hestia $ref"
			tail -5 "$WORK/setup.log" | sed 's/^/        /'
			return
		fi
	fi

	rm -rf "$WORK" && mkdir -p "$WORK" && cp -R src "$WORK/src"
	check_sources
	docker rm -f "$NAME" > /dev/null 2>&1
	if ! docker run -d --rm --name "$NAME" --entrypoint bash -p 127.0.0.1::8084 \
		-e XDEBUG_MODE=off -e PHP_CLI_SERVER_WORKERS=4 -e CSRF_STRICTNESS=1 \
		-v "$H:/src/hestia:ro" -v "$PWD/dev:/src/dev:ro" -v "$WORK/src:/src/addon:ro" \
		"$IMAGE" /src/dev/container.sh > /dev/null; then
		bad "could not start the container from $IMAGE"
		return
	fi
	BASE="http://$(docker port "$NAME" 8084 | head -1)"
	local i
	for i in $(seq 1 120); do
		curl -s -o /dev/null "$BASE/css/themes/default.min.css" && break
		sleep 0.5
	done
	is "the panel starts" 200 "$(req admin "" dark /list/user/)"
	if [ "$(has 'units-table')" = yes ]; then
		check_pages
		check_menu
		check_logo
		check_access
		check_landing
		check_failures
	else
		bad "the stock user list does not work in the test environment, page checks were skipped"
	fi
	local fatals
	# Stock pages may fail here too (no restic, no vendor packages); only the addon's own errors count
	fatals=$(docker logs "$NAME" 2>&1 | grep -E 'PHP Fatal|Uncaught' | grep -E 'custom_scripts|/src/addon' | head -3)
	if [ -z "$fatals" ]; then ok "no fatal errors"; else bad "fatal errors: $fatals"; fi
	check_install
	docker rm -f "$NAME" > /dev/null 2>&1
	if [ "$failed" = "$before" ]; then
		echo "  passed: $((passed - start)) checks"
	else
		echo "  failed: $((failed - before)), passed: $((passed - start))"
	fi
}

command -v docker > /dev/null && docker info > /dev/null 2>&1 || { echo "Docker is not running" >&2; exit 2; }
for f in src/custom_scripts/hestia-sidebar/*.js; do
	node --check "$f" 2> /dev/null && ok "$f" || bad "$f does not parse"
done

if [ -n "${HESTIA_SRC:-}" ]; then
	set -- local
elif [ $# = 0 ]; then
	latest=$(git ls-remote --tags --refs https://github.com/hestiacp/hestiacp.git \
		| sed 's#.*refs/tags/##' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
	[ -n "$latest" ] || { echo "Could not find the latest Hestia release" >&2; exit 2; }
	set -- "$latest"
fi
for ref in "$@"; do check_version "$ref"; done
[ "$failed" = 0 ]
