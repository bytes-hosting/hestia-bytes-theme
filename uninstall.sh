#!/usr/bin/env bash
# Remove hestia-sidebar from a Hestia server. Run as root.
set -euo pipefail
# hestia.conf ends with a test that fails when local.conf is absent, which would trip `set -e`
if [ -f /etc/hestiacp/hestia.conf ]; then . /etc/hestiacp/hestia.conf || true; fi
HESTIA="${HESTIA:-/usr/local/hestia}"
[ "$(id -u)" = 0 ] || { echo "Run as root" >&2; exit 1; }
cd "$(dirname "$0")"

# Our logos leave, the previous ones return, and logos the administrator added since are applied again
custom="$HESTIA/web/images/custom"
state="$HESTIA/web/js/custom_scripts/hestia-sidebar/logos"
if [ -d "$state/before" ]; then
	for f in "$custom"/*; do
		[ -f "$f" ] || continue
		if grep -qxF "$(cd "$custom" && sha256sum -- "${f##*/}")" "$state/sha256"; then rm -f "$f"; fi
	done
	rmdir "$custom" 2> /dev/null || true
	install -m 644 "$state"/before/{logo.svg,logo.png,logo-header.svg,favicon.png} "$HESTIA/web/images/"
	install -m 644 "$state/before/favicon.ico" "$HESTIA/web/"
	"$HESTIA/bin/v-update-white-label-logo" || true
fi

rm -f "$HESTIA/web/js/custom_scripts/hestia-sidebar.php"
rm -rf "$HESTIA/web/js/custom_scripts/hestia-sidebar"
for f in src/themes/*.css; do rm -f "$HESTIA/web/css/themes/custom/$(basename "$f")"; done

# Accounts that still use the removed theme go back to the default one
if grep -q "^THEME='sidebar" "$HESTIA/conf/hestia.conf"; then
	"$HESTIA/bin/v-change-sys-config-value" THEME default
fi
for conf in "$HESTIA"/data/users/*/user.conf; do
	if grep -q "^THEME='sidebar" "$conf"; then
		# Hestia refuses to change suspended accounts. The leftover name is harmless: the default look is used.
		"$HESTIA/bin/v-change-user-theme" "$(basename "$(dirname "$conf")")" default || true
	fi
done
echo "Removed."
