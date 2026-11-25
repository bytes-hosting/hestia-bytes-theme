#!/usr/bin/env bash
# Install or update the theme on a server where Hestia is already installed. Run as root:
#   curl -fsSL https://raw.githubusercontent.com/bytes-hosting/hestia-bytes-theme/main/get.sh | bash
# Options go after "bash -s --":
#   --theme NAME   make this theme the panel default; "keep" leaves the current one.
#                  Without it the first install sets "sidebar", and an update changes nothing.
#   --no-logo      leave the panel logos alone
#   --ref REF      a branch, tag or commit instead of main
set -euo pipefail

REPO=https://github.com/bytes-hosting/hestia-bytes-theme
DIR=/opt/hestia-bytes-theme

die() { echo "$*" >&2; exit 1; }

# Everything is in a function, so that a download cut short runs nothing
main() {
	local theme="" ref=main logo=yes
	while [ $# -gt 0 ]; do
		case "$1" in
			--theme | --ref)
				[ -n "${2:-}" ] || die "$1 needs a value"
				if [ "$1" = --theme ]; then theme=$2; else ref=$2; fi
				shift 2
				;;
			--no-logo) logo=no; shift ;;
			*) die "Unknown option: $1" ;;
		esac
	done

	[ "$(id -u)" = 0 ] || die "Run as root"
	# hestia.conf ends with a test that fails when local.conf is absent, which would trip `set -e`
	if [ -f /etc/hestiacp/hestia.conf ]; then . /etc/hestiacp/hestia.conf || true; fi
	HESTIA="${HESTIA:-/usr/local/hestia}"
	[ -x "$HESTIA/bin/v-change-sys-config-value" ] || die "Hestia is not installed here. Install it first: https://hestiacp.com/install.html"
	[ ! -e "$DIR/.git" ] || die "$DIR is a git checkout: update it with git pull and run its install.sh"

	# Beside the final place, so that the swap below is a plain rename
	work=$(mktemp -d "$DIR.XXXXXX")
	trap 'rm -rf "$work"' EXIT
	chmod 755 "$work"
	# Only these three: dev/ holds a passwordless test session and must never reach a server
	curl -fsSL --retry 3 "${HESTIA_THEME_URL:-$REPO/archive/$ref.tar.gz}" -o "$work/theme.tar.gz" \
		|| die "Could not download '$ref', nothing was changed"
	tar -xzf "$work/theme.tar.gz" -C "$work" --strip-components=1 --no-same-owner --wildcards \
		'*/install.sh' '*/uninstall.sh' '*/src' || die "The archive is incomplete, nothing was changed"
	rm "$work/theme.tar.gz"

	[ -z "$theme" ] || [ "$theme" = keep ] || [ -f "$work/src/themes/$theme.css" ] \
		|| die "No theme '$theme', choose from: $(cd "$work/src/themes" && printf '%s ' *.css | sed 's/\.css//g')"
	if [ -z "$theme" ]; then
		if [ -e "$HESTIA/web/js/custom_scripts/hestia-sidebar.php" ]; then theme=keep; else theme=sidebar; fi
	fi

	LOGO=$logo "$work/install.sh" < /dev/null
	if [ "$theme" != keep ]; then
		"$HESTIA/bin/v-change-sys-config-value" THEME "$theme"
		echo "Default theme: $theme. Users who chose their own theme keep it."
	fi

	# Keep this version for uninstall.sh, and the one before it for going back
	rm -rf "$DIR.previous"
	if [ -e "$DIR" ]; then mv "$DIR" "$DIR.previous"; fi
	mv "$work" "$DIR"
	echo "Done ($ref). To remove: $DIR/uninstall.sh"
}

main "$@"
