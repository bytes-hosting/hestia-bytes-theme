#!/usr/bin/env bash
# Remove hestia-sidebar from a Hestia server. Run as root.
set -euo pipefail
# hestia.conf ends with a test that fails when local.conf is absent, which would trip `set -e`
if [ -f /etc/hestiacp/hestia.conf ]; then . /etc/hestiacp/hestia.conf || true; fi
HESTIA="${HESTIA:-/usr/local/hestia}"
[ "$(id -u)" = 0 ] || { echo "Run as root" >&2; exit 1; }
cd "$(dirname "$0")"

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
