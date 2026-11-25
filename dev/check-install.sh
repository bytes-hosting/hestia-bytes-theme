#!/usr/bin/env bash
# Runs inside a throwaway container, see check.sh. The last line is OK when everything passed.
H=/usr/local/hestia
mkdir -p $H /etc/hestiacp
cp -r /hestia/. $H/
mkdir -p $H/php/bin $H/conf $H/log
ln -sf "$(command -v php)" $H/php/bin/php
cp -r /repo/dev/fixtures/. $H/
chmod +x $H/bin/*
# Same last line as on a real server: it returns non-zero
printf "export HESTIA=%s\n\n[[ -f /etc/hestiacp/local.conf ]] && source /etc/hestiacp/local.conf\n" $H > /etc/hestiacp/hestia.conf
fail() { echo "$1"; exit 1; }
list() { (cd $H/web && find . -type f | sort); }

mkdir /work && cp -r /repo/src /repo/install.sh /repo/uninstall.sh /work/
list > /tmp/before
echo '<?php $x = [;' > /work/src/custom_scripts/hestia-sidebar/lib.php
/work/install.sh > /dev/null 2>&1 && fail "a file that does not parse was installed"
list | diff -q /tmp/before - > /dev/null || fail "a refused install left files behind"
cp /repo/src/custom_scripts/hestia-sidebar/lib.php /work/src/custom_scripts/hestia-sidebar/

/work/install.sh || fail "install.sh failed"
/work/install.sh > /dev/null || fail "the second install failed"
diff -r /repo/src/custom_scripts $H/web/js/custom_scripts | grep -v README.txt && fail "installed files differ"
diff -r /repo/src/themes $H/web/css/themes/custom || fail "installed themes differ"
list | diff /tmp/before - | grep '^>' | grep -vE '^> \./(js/custom_scripts|css/themes/custom)/' && fail "files outside the extension folders"
$H/bin/v-list-sys-themes plain | grep -qx sidebar_dark || fail "Hestia does not list the theme"

/work/uninstall.sh > /tmp/un.log 2>&1 || fail "uninstall.sh failed: $(cat /tmp/un.log)"
list | diff /tmp/before - || fail "uninstall left files behind"
grep -q "^THEME='default'" $H/conf/hestia.conf || fail "the server theme was not reset"
grep -q "^THEME='default'" $H/data/users/demo/user.conf || fail "the user theme was not reset"
echo OK
