#!/usr/bin/env bash
# Install or update hestia-sidebar on a Hestia server. Run as root.
# Only Hestia's own extension folders are written, so `apt upgrade` keeps these files. The logos
# are put in place by Hestia's white-label command, which Hestia repeats after its own upgrades.
#   LOGO=no ./install.sh   leaves the panel logos alone
set -euo pipefail
cd "$(dirname "$0")"
# hestia.conf ends with a test that fails when local.conf is absent, which would trip `set -e`
if [ -f /etc/hestiacp/hestia.conf ]; then . /etc/hestiacp/hestia.conf || true; fi
HESTIA="${HESTIA:-/usr/local/hestia}"
[ "$(id -u)" = 0 ] || { echo "Run as root" >&2; exit 1; }
[ -d "$HESTIA/web/js/custom_scripts" ] || { echo "Hestia with custom_scripts support not found in $HESTIA" >&2; exit 1; }

# Never install a file the panel's own PHP cannot parse
for f in src/custom_scripts/*.php src/custom_scripts/hestia-sidebar/*.php; do
	"$HESTIA/php/bin/php" -l "$f" > /dev/null || { echo "Syntax error in $f, nothing was installed" >&2; exit 1; }
done

install -d -m 755 "$HESTIA/web/css/themes/custom" "$HESTIA/web/js/custom_scripts/hestia-sidebar"
install -m 644 src/themes/*.css "$HESTIA/web/css/themes/custom/"
install -m 644 src/custom_scripts/hestia-sidebar/* "$HESTIA/web/js/custom_scripts/hestia-sidebar/"

# Logos go to Hestia's white-label folder, unless it holds a file that is not ours. The checksums
# of everything ever installed tell our older logos from those the administrator uploaded.
custom="$HESTIA/web/images/custom"
state="$HESTIA/web/js/custom_scripts/hestia-sidebar/logos"
foreign() {
	local f
	for f in "$custom"/* "$custom"/.[!.]*; do
		[ -e "$f" ] || continue
		grep -qxF "$(cd "$custom" && sha256sum -- "${f##*/}")" "$state/sha256" 2> /dev/null || return 0
	done
	return 1
}
if [ "${LOGO:-yes}" = no ]; then
	logos="skipped"
elif foreign; then
	logos="left as they are, $custom holds files that are not from here"
else
	install -d -m 755 "$custom" "$state"
	# The logos in use before ours, for uninstall.sh: Hestia itself can only download its stock ones
	if [ ! -d "$state/before" ]; then
		rm -rf "$state/before.new" && mkdir -m 755 "$state/before.new"
		cp "$HESTIA"/web/images/{logo.svg,logo.png,logo-header.svg,favicon.png} "$HESTIA/web/favicon.ico" "$state/before.new/"
		mv "$state/before.new" "$state/before"
	fi
	touch "$state/sha256"
	(cd src/images && sha256sum -- *) | sort -u -o "$state/sha256" - "$state/sha256"
	install -m 644 src/images/* "$custom/"
	logos="installed"
	"$HESTIA/bin/v-update-white-label-logo" || logos="copied, but v-update-white-label-logo failed"
fi

# The loader goes last, so the panel never sees a half-copied addon
install -m 644 src/custom_scripts/hestia-sidebar.php "$HESTIA/web/js/custom_scripts/"
echo "Logos: $logos."
echo "Installed. Choose the theme 'sidebar' or 'sidebar_dark' in the panel settings."
