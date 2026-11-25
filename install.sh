#!/usr/bin/env bash
# Install or update hestia-sidebar on a Hestia server. Run as root.
# Only Hestia's own extension folders are written, so `apt upgrade` keeps these files.
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
# The loader goes last, so the panel never sees a half-copied addon
install -m 644 src/custom_scripts/hestia-sidebar.php "$HESTIA/web/js/custom_scripts/"
echo "Installed. Choose the theme 'sidebar' or 'sidebar_dark' in the panel settings."
