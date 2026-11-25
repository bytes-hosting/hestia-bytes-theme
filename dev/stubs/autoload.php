<?php
// DEV ONLY: stands in for web/inc/vendor, which is installed by v-add-sys-dependencies on a server
namespace Hestiacp\quoteshellarg;
function quoteshellarg(string $arg): string {
	return "'" . str_replace("'", "'\\''", $arg) . "'";
}
