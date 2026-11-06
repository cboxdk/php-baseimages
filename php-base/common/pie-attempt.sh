#!/bin/sh
# usage: pie-attempt <ext-name> <vendor/package[:version|:dev-branch]> [-DEV]
# -DEV marks a development-branch attempt: it is skipped when the released
# version already loaded, and scores as OK-DEV/FAIL-DEV so the scoreboard
# separates "released and working" from "fix confirmed on branch, await tag".
name="$1"; pkg="$2"; label="${3:-}"; REPORT=/usr/local/etc/php86-report.txt
if [ "$label" = "-DEV" ] && php -m 2>/dev/null | grep -qix "$name"; then
    echo "SKIP-DEV $name  (released version already loaded)" >> "$REPORT"
    exit 0
fi
if pie install "$pkg" >"/tmp/pie-$name.log" 2>&1; then
    v=$(php -r "echo phpversion('$name');" 2>/dev/null)
    echo "OK$label   $name  $pkg  $v" >> "$REPORT"
else
    rm -f /usr/local/etc/php/conf.d/*"$name"*.ini
    reason=$(grep -iE 'cannot use|not compatible|requires php|fatal error|error:|exit code' "/tmp/pie-$name.log" | head -1)
    [ -n "$reason" ] || reason=$(grep -vE '^\s*$|^ *\[|Output:|^install \[' "/tmp/pie-$name.log" | tail -1)
    echo "FAIL$label $name  $pkg  $(echo "$reason" | cut -c1-140)" >> "$REPORT"
fi
exit 0
