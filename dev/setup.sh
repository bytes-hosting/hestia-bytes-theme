#!/usr/bin/env bash
# Fetch Hestia sources and build their CSS/JS. Run once, and again to change the version.
#   HESTIA_REF  branch or tag, "main" by default
#   HESTIA_SRC  copy a local checkout instead of cloning
#   HESTIA_DIR  where to put it, ".hestia" by default
set -euo pipefail
cd "$(dirname "$0")/.."
REF="${HESTIA_REF:-main}"
DIR="${HESTIA_DIR:-.hestia}"

rm -rf "$DIR" "$DIR.new"
mkdir -p "$(dirname "$DIR")"
if [ -n "${HESTIA_SRC:-}" ]; then
	mkdir "$DIR.new"
	tar -C "$HESTIA_SRC" --exclude .git --exclude ./node_modules -cf - . | tar -C "$DIR.new" -xf -
else
	git clone --quiet --depth 1 --branch "$REF" https://github.com/hestiacp/hestiacp.git "$DIR.new"
fi
if [ ! -f "$DIR.new/web/css/themes/default.min.css" ]; then
	(cd "$DIR.new" && npm ci --ignore-scripts --no-audit --no-fund && node build.js && rm -rf node_modules)
fi
mv "$DIR.new" "$DIR" # appears only when complete
echo "Ready: Hestia in $DIR"
