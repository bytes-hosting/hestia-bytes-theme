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

# One-command install, from an archive like the one GitHub makes
mkdir /pack && cp -r /repo/. /pack/hestia-bytes-theme-main && rm -rf /pack/*/.git /pack/*/.hestia /pack/*/.cache
pack() { tar -czf /tmp/theme.tar.gz -C /pack hestia-bytes-theme-main; }
get() { HESTIA_THEME_URL=file:///tmp/theme.tar.gz bash -s -- "$@" < /repo/get.sh > /tmp/get.log 2>&1; }
theme() { grep '^THEME=' $H/conf/hestia.conf | cut -d"'" -f2; }
O=/opt/hestia-bytes-theme
pack
get --theme nosuch && fail "an unknown theme was accepted"
get --oops && fail "an unknown option was accepted"
HESTIA_THEME_URL=file:///nosuch bash /repo/get.sh > /dev/null 2>&1 && fail "a failed download was not noticed"
# The script itself cut short, at any line
for n in $(seq 1 $(($(wc -l < /repo/get.sh) - 1))); do
	head -n $n /repo/get.sh | HESTIA_THEME_URL=file:///tmp/theme.tar.gz bash > /dev/null 2>&1
done
mv /tmp/theme.tar.gz /tmp/whole.tar.gz
for cut in 30000 5000 1000 100 20; do
	head -c -$cut /tmp/whole.tar.gz > /tmp/theme.tar.gz
	get && fail "an archive without its last $cut bytes was accepted"
done
list | diff /tmp/before - || fail "a refused one-command install left files in the panel"
[ -z "$(ls -A /opt | grep hestia)" ] || fail "a refused one-command install left files in /opt"
[ "$(theme)" = default ] || fail "a refused one-command install changed the theme"

pack
get || fail "one-command install failed: $(cat /tmp/get.log)"
[ "$(theme)" = sidebar ] || fail "the first install did not set the default theme"
[ "$(ls -A $O | xargs)" = "install.sh src uninstall.sh" ] || fail "$O should hold only what a server needs"
diff -r /repo/src $O/src || fail "$O/src differs"
cmp /repo/src/images/logo.svg $H/web/images/logo.svg || fail "one-command install: the logos are not applied"
$H/bin/v-change-sys-config-value THEME dark
get || fail "one-command update failed: $(cat /tmp/get.log)"
[ "$(theme)" = dark ] || fail "an update changed the default theme"
[ -x $O.previous/install.sh ] || fail "the previous version was not kept"
get --theme sidebar_dark || fail "--theme failed: $(cat /tmp/get.log)"
[ "$(theme)" = sidebar_dark ] || fail "--theme was ignored"
[ "$(ls -A /opt | grep -c hestia)" = 2 ] || fail "extra folders in /opt: $(ls /opt)"
find $O -type f -exec sha256sum {} + | sort > /tmp/opt
echo '<?php $x = [;' > /pack/hestia-bytes-theme-main/src/custom_scripts/hestia-sidebar/lib.php && pack
get && fail "a version that does not parse was installed"
find $O -type f -exec sha256sum {} + | sort | diff /tmp/opt - || fail "a refused update touched $O"
cp /repo/src/custom_scripts/hestia-sidebar/lib.php /pack/hestia-bytes-theme-main/src/custom_scripts/hestia-sidebar/ && pack
$O/uninstall.sh > /dev/null 2>&1 || fail "uninstall.sh from $O failed"
list | diff /tmp/before - || fail "uninstall from $O left files behind"
get --no-logo --theme keep || fail "--no-logo failed: $(cat /tmp/get.log)"
[ "$(theme)" = default ] || fail "--theme keep was ignored"
pictures | diff /tmp/pictures - || fail "--no-logo changed the logos"
rm -rf $O/src && mkdir $O/.git
get && fail "a git checkout was overwritten"
echo OK
