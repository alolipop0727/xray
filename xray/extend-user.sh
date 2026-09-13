#!/bin/bash
# extend-user.sh - Perpanjang masa aktif akun Xray non-interaktif (dipakai oleh Telegram bot)
# Usage: extend-user.sh <username> <days>

NC='\e[0m'
RB='\e[31;1m'
GB='\e[32;1m'
YB='\e[33;1m'

CONF_FILE="${XRAY_CONF:-/usr/local/etc/xray/config/04_inbounds.json}"

user=$1
days=$2
if [ -z "$user" ] || [ -z "$days" ]; then
    echo -e "${RB}Usage: extend-user.sh <username> <days>${NC}"
    exit 1
fi
if ! [[ "$days" =~ ^[0-9]+$ ]]; then
    echo -e "${RB}Days must be a number.${NC}"
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
now=$(date +%Y-%m-%d)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
exp3=$(( exp2 + days ))
exp4=$(date -d "$exp3 days" +"%Y-%m-%d")
sed -i "/^#&@ $user/c\#&@ $user $exp4" "$CONF_FILE"

if [ -z "${XRAY_NO_RESTART:-}" ]; then
    systemctl restart --no-block xray
fi

echo -e "${GB}User '$user' extended, new expire: $exp4.${NC}"
exit 0