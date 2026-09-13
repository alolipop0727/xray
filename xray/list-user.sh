#!/bin/bash
# list-user.sh - Daftar akun Xray non-interaktif (dipakai oleh Telegram bot)
# Output: <username> <expired>

CONF_FILE="${XRAY_CONF:-/usr/local/etc/xray/config/04_inbounds.json}"

if ! [ -f "$CONF_FILE" ]; then
    echo "Config not found: $CONF_FILE"
    exit 1
fi

count=$(grep -c -E "^#&@ " "$CONF_FILE")
if [ "$count" -eq 0 ]; then
    echo "No accounts."
    exit 0
fi

if command -v column >/dev/null 2>&1; then
    grep -E "^#&@ " "$CONF_FILE" | cut -d ' ' -f 2-3 | column -t | sort -u
else
    grep -E "^#&@ " "$CONF_FILE" | awk '{print $2"\t"$3}' | sort -u
fi
echo "--------------------------------"
echo "Total: $count account(s)."
exit 0