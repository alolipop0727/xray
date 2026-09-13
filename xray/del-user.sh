#!/bin/bash
# del-user.sh - Penghapusan akun Xray non-interaktif (dipakai oleh Telegram bot)
# Usage: del-user.sh <username>

NC='\e[0m'
RB='\e[31;1m'
GB='\e[32;1m'
YB='\e[33;1m'

CONF_FILE="${XRAY_CONF:-/usr/local/etc/xray/config/04_inbounds.json}"
LOG_DIR="${XRAY_LOG_DIR:-/user}"
WWW_DIR="${XRAY_WWW:-/var/www/html/xray}"

user=$1
if [ -z "$user" ]; then
    echo -e "${RB}Usage: del-user.sh <username>${NC}"
    exit 1
fi
if ! [ -f "$CONF_FILE" ]; then
    echo -e "${RB}Config not found: $CONF_FILE${NC}"
    exit 1
fi

if ! grep -qE "^#&@ $user " "$CONF_FILE"; then
    echo -e "${RB}User '$user' not found.${NC}"
    exit 1
fi

exp=$(grep -wE "^#&@ $user" "$CONF_FILE" | cut -d ' ' -f 3 | sort | uniq)
sed -i "/^#&@ $user $exp/,/^},{/d" "$CONF_FILE"
rm -f "$WWW_DIR/xray-$user.log" "$WWW_DIR/xray-$user.html" "$LOG_DIR/xray-$user.log"

if [ -z "${XRAY_NO_RESTART:-}" ]; then
    systemctl restart --no-block xray
fi

echo -e "${GB}User '$user' deleted.${NC}"
exit 0