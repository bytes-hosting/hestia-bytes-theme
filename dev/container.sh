#!/usr/bin/env bash
# Entry point inside the container, see up.sh
set -e
H=/usr/local/hestia
mkdir -p $H /etc/hestiacp
cp -r /src/hestia/. $H/
rm -rf $H/node_modules

mkdir -p $H/php/bin $H/conf $H/data/packages $H/data/ips $H/data/firewall $H/data/queue $H/log
ln -sf "$(command -v php)" $H/php/bin/php
cp $H/install/common/packages/*.pkg $H/data/packages/
cp $H/install/common/firewall/*.conf $H/data/firewall/ 2> /dev/null || true
cp -r /src/dev/fixtures/. $H/
[ -z "${CSRF_STRICTNESS:-}" ] || sed -i "s/^POLICY_CSRF_STRICTNESS=.*/POLICY_CSRF_STRICTNESS='$CSRF_STRICTNESS'/" $H/conf/hestia.conf
cp /src/dev/stubs/bin/* $H/bin/ 2> /dev/null || true
chmod +x $H/bin/*
mkdir -p $H/web/inc/vendor && cp /src/dev/stubs/autoload.php $H/web/inc/vendor/autoload.php

# The addon is linked, so edits in src/ show up on reload
rm -rf $H/web/js/custom_scripts $H/web/css/themes/custom
ln -s /src/addon/custom_scripts $H/web/js/custom_scripts
ln -s /src/addon/themes $H/web/css/themes/custom

# Same content as on a real server, including the last line that returns non-zero
cat > /etc/hestiacp/hestia.conf << CONF
export HESTIA='$H'

[[ -f /etc/hestiacp/local.conf ]] && source /etc/hestiacp/local.conf
CONF
printf '#!/bin/bash\nexec "$@"\n' > /usr/bin/sudo && chmod +x /usr/bin/sudo
export HESTIA=$H

# v-list-users reads panel accounts from /etc/passwd
for u in $H/data/users/*; do
	u=$(basename "$u")
	install -d -m 700 "/home/$u/.ssh" && touch "/home/$u/.ssh/authorized_keys"
	echo "$u:x:2000:2000:$u@example.com:/home/$u:/bin/bash" >> /etc/passwd
done

# gettext ignores the chosen language under C.UTF-8, so provide the locale Hestia asks for
[ -d /usr/lib/locale/en_US.utf8 ] || cp -r /usr/lib/locale/C.utf8 /usr/lib/locale/en_US.utf8

exec php -d auto_prepend_file=/src/dev/stubs/prepend.php -d display_errors=0 -d log_errors=1 \
	-d error_log=/dev/stderr -d error_reporting='E_ALL & ~E_WARNING & ~E_NOTICE & ~E_DEPRECATED' \
	-d opcache.enable=0 -S 0.0.0.0:8084 -t $H/web /src/dev/stubs/router.php
