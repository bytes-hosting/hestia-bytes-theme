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
pictures() { (cd $H/web && sha256sum images/*.* favicon.ico); }
list > /tmp/before
pictures > /tmp/pictures
echo '<?php $x = [;' > /work/src/custom_scripts/hestia-sidebar/lib.php
/work/install.sh > /dev/null 2>&1 && fail "a file that does not parse was installed"
list | diff -q /tmp/before - > /dev/null || fail "a refused install left files behind"
cp /repo/src/custom_scripts/hestia-sidebar/lib.php /work/src/custom_scripts/hestia-sidebar/

/work/install.sh || fail "install.sh failed"
/work/install.sh > /dev/null || fail "the second install failed"
diff -r /repo/src/custom_scripts $H/web/js/custom_scripts | grep -vE 'README.txt|hestia-sidebar: logos$' && fail "installed files differ"
diff -r /repo/src/themes $H/web/css/themes/custom || fail "installed themes differ"
list | diff /tmp/before - | grep '^>' | grep -vE '^> \./(js/custom_scripts|css/themes/custom|images/custom)/' && fail "files outside the extension folders"
$H/bin/v-list-sys-themes plain | grep -qx sidebar_dark || fail "Hestia does not list the theme"

# Logos: a newer one of ours is applied, one uploaded by the administrator is kept through everything
diff -r /repo/src/images $H/web/images/custom || fail "installed logos differ"
for f in logo.svg logo.png logo-header.svg favicon.png; do cmp /repo/src/images/$f $H/web/images/$f || fail "$f is not applied"; done
cmp /repo/src/images/favicon.ico $H/web/favicon.ico || fail "favicon.ico is not applied"
echo '<svg>newer</svg>' > /work/src/images/logo.svg
/work/install.sh > /dev/null || fail "an update with a newer logo failed"
grep -q newer $H/web/images/logo.svg || fail "a newer logo is not applied"
echo '<svg>uploaded</svg>' > $H/web/images/custom/logo.svg
$H/bin/v-update-white-label-logo
/work/install.sh > /tmp/in.log || fail "install.sh failed next to an uploaded logo"
grep -q 'left as they are' /tmp/in.log || fail "an uploaded logo was not noticed"
grep -q uploaded $H/web/images/custom/logo.svg || fail "an uploaded logo was overwritten"
/work/uninstall.sh > /dev/null 2>&1 || fail "uninstall.sh failed next to an uploaded logo"
[ "$(ls -A $H/web/images/custom)" = logo.svg ] || fail "uninstall should leave only the uploaded logo"
grep -q uploaded $H/web/images/logo.svg || fail "the uploaded logo is no longer in use"
[ "$(pictures | grep -v images/logo.svg)" = "$(grep -v images/logo.svg /tmp/pictures)" ] || fail "the other stock logos did not return"
LOGO=no /work/install.sh > /dev/null || fail "install.sh with LOGO=no failed"
[ "$(ls -A $H/web/images/custom)" = logo.svg ] || fail "LOGO=no installed logos"
rm -r $H/web/images/custom && cp /hestia/web/images/logo.svg $H/web/images/
/work/install.sh > /dev/null || fail "install.sh failed after the uploaded logo was removed"

/work/uninstall.sh > /tmp/un.log 2>&1 || fail "uninstall.sh failed: $(cat /tmp/un.log)"
list | diff /tmp/before - || fail "uninstall left files behind"
pictures | diff /tmp/pictures - || fail "the stock logos did not return"
grep -q "^THEME='default'" $H/conf/hestia.conf || fail "the server theme was not reset"
grep -q "^THEME='default'" $H/data/users/demo/user.conf || fail "the user theme was not reset"
echo OK
