#!/usr/bin/env bash
# Run the Hestia web UI locally: real templates and real v-list-* scripts on fixture data.
#   http://localhost:8084/?as=admin   administrator
#   http://localhost:8084/?as=demo    regular user
#   &theme=sidebar|sidebar_dark|default|dark   &lang=uk|en|...
# Only read pages are meant to work here: there are no real services behind it.
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE="${PHP_IMAGE:-sail-8.5/app:latest}" # any image with php-cli 8.2+, gettext and bash
PORT="${PORT:-8084}"
H=/usr/local/hestia
[ -d .hestia ] || { echo "Run dev/setup.sh first" >&2; exit 1; }

exec docker run --rm --name hestia-sidebar-dev --entrypoint bash \
	-p "127.0.0.1:$PORT:8084" \
	-e XDEBUG_MODE=off -e PHP_CLI_SERVER_WORKERS=6 \
	-v "$PWD/.hestia:/src/hestia:ro" \
	-v "$PWD/dev:/src/dev:ro" \
	-v "$PWD/src:/src/addon:ro" \
	"$IMAGE" /src/dev/container.sh
