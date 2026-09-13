#!/bin/bash
# add-user.sh - Pembuatan akun Xray non-interaktif (dipakai oleh Telegram bot)
# Usage: add-user.sh <username> <days>
#
# Path file dapat dioverride lewat env (untuk pengujian):
#   XRAY_CONF, XRAY_DNS, XRAY_PSK, XRAY_CITY, XRAY_ORG, XRAY_REGION,
#   XRAY_LOG_DIR, XRAY_WWW, XRAY_NO_RESTART=1

NC='\e[0m'
RB='\e[31;1m'
GB='\e[32;1m'
YB='\e[33;1m'

CONF_FILE="${XRAY_CONF:-/usr/local/etc/xray/config/04_inbounds.json}"
DNS_FILE="${XRAY_DNS:-/usr/local/etc/xray/dns/domain}"
PSK_FILE="${XRAY_PSK:-/usr/local/etc/xray/serverpsk}"
CITY_FILE="${XRAY_CITY:-/usr/local/etc/xray/city}"
ORG_FILE="${XRAY_ORG:-/usr/local/etc/xray/org}"
REGION_FILE="${XRAY_REGION:-/usr/local/etc/xray/region}"
LOG_DIR="${XRAY_LOG_DIR:-/user}"

user=$1
masaaktif=$2

if [ -z "$user" ] || [ -z "$masaaktif" ]; then
    echo -e "${RB}Usage: add-user.sh <username> <days>${NC}"
    exit 1
fi
if ! [[ "$masaaktif" =~ ^[0-9]+$ ]]; then
    echo -e "${RB}Days must be a number.${NC}"
    exit 1
fi
if ! [[ "$user" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo -e "${RB}Username must be alphanumeric (a-z, 0-9, _).${NC}"
    exit 1
fi
if ! [ -f "$CONF_FILE" ]; then
    echo -e "${RB}Config not found: $CONF_FILE${NC}"
    exit 1
fi
if ! [ -f "$DNS_FILE" ]; then
    echo -e "${RB}Domain file not found: $DNS_FILE${NC}"
    exit 1
fi

if grep -qE "^#&@ $user " "$CONF_FILE"; then
    echo -e "${RB}User '$user' already exists.${NC}"
    exit 1
fi

domain=$(cat "$DNS_FILE")
cipher="aes-256-gcm"
cipher2="2022-blake3-aes-256-gcm"
uuid=$(cat /proc/sys/kernel/random/uuid)
pwtr=$(openssl rand -hex 4)
pwss=$(echo $RANDOM | md5sum | head -c 6)
userpsk=$(openssl rand -base64 32)
serverpsk=""
if [ -f "$PSK_FILE" ]; then
    serverpsk=$(cat "$PSK_FILE")
fi
exp=$(date -d "$masaaktif days" +"%Y-%m-%d")

add_xray_config() {
    local section=$1
    local content=$2
    sed -i "/^#$section\$/a\\#&@ $user $exp\n$content" "$CONF_FILE"
}

add_xray_config "xtls" "},{\"flow\": \"xtls-rprx-vision\",\"id\": \"$uuid\",\"email\": \"$user\""
add_xray_config "vless" "},{\"id\": \"$uuid\",\"email\": \"$user\""
add_xray_config "universal" "},{\"id\": \"$uuid\",\"email\": \"$user\""
add_xray_config "vmess" "},{\"id\": \"$uuid\",\"email\": \"$user\""
add_xray_config "trojan" "},{\"password\": \"$pwtr\",\"email\": \"$user\""
add_xray_config "ss" "},{\"password\": \"$pwss\",\"method\": \"$cipher\",\"email\": \"$user\""
add_xray_config "ss22" "},{\"password\": \"$userpsk\",\"email\": \"$user\""

ISP=$(cat "$ORG_FILE")
CITY=$(cat "$CITY_FILE")
REG=$(cat "$REGION_FILE")

create_vmess_link() {
    local version="2"
    local ps=$1
    local port=$2
    local net=$3
    local path=$4
    local tls=$5
    cat <<EOF | base64 -w 0
{
"v": "$version",
"ps": "$ps",
"add": "$domain",
"port": "$port",
"id": "$uuid",
"aid": "0",
"net": "$net",
"path": "$path",
"type": "none",
"host": "$domain",
"tls": "$tls"
}
EOF
}

vmesslink1="vmess://$(create_vmess_link "vmess-ws-tls" "443" "ws" "/vmess-ws" "tls")"
vmesslink2="vmess://$(create_vmess_link "vmess-ws-ntls" "80" "ws" "/vmess-ws" "none")"
vmesslink3="vmess://$(create_vmess_link "vmess-hup-tls" "443" "httpupgrade" "/vmess-hup" "tls")"
vmesslink4="vmess://$(create_vmess_link "vmess-hup-ntls" "80" "httpupgrade" "/vmess-hup" "none")"
vmesslink5="vmess://$(create_vmess_link "vmess-grpc" "443" "grpc" "vmess-grpc" "tls")"

vlesslink1="vless://$uuid@$domain:443?path=/vless-ws&security=tls&encryption=none&host=$domain&type=ws&sni=$domain#vless-ws-tls"
vlesslink2="vless://$uuid@$domain:80?path=/vless-ws&security=none&encryption=none&host=$domain&type=ws#vless-ws-ntls"
vlesslink3="vless://$uuid@$domain:443?path=/vless-hup&security=tls&encryption=none&host=$domain&type=httpupgrade&sni=$domain#vless-hup-tls"
vlesslink4="vless://$uuid@$domain:80?path=/vless-hup&security=none&encryption=none&host=$domain&type=httpupgrade#vless-hup-ntls"
vlesslink5="vless://$uuid@$domain:443?security=tls&encryption=none&headerType=gun&type=grpc&serviceName=vless-grpc&sni=$domain#vless-grpc"
vlesslink6="vless://$uuid@$domain:443?security=tls&encryption=none&headerType=none&type=tcp&sni=$domain&flow=xtls-rprx-vision#vless-vision"

trojanlink1="trojan://$pwtr@$domain:443?path=/trojan-ws&security=tls&host=$domain&type=ws&sni=$domain#trojan-ws-tls"
trojanlink2="trojan://$pwtr@$domain:80?path=/trojan-ws&security=none&host=$domain&type=ws#trojan-ws-ntls"
trojanlink3="trojan://$pwtr@$domain:443?path=/trojan-hup&security=tls&host=$domain&type=httpupgrade&sni=$domain#trojan-hup-tls"
trojanlink4="trojan://$pwtr@$domain:80?path=/trojan-hup&security=none&host=$domain&type=httpupgrade#trojan-hup-ntls"
trojanlink5="trojan://$pwtr@$domain:443?security=tls&type=grpc&mode=multi&serviceName=trojan-grpc&sni=$domain#trojan-grpc"
trojanlink6="trojan://$pwtr@$domain:443?security=tls&type=tcp&sni=$domain#trojan-tcp-tls"

encode_ss() {
    echo -n "$1:$2" | base64 -w 0
}

ss_base64=$(encode_ss "$cipher" "$pwss")
sslink1="ss://${ss_base64}@$domain:443?path=/ss-ws&security=tls&host=${domain}&type=ws&sni=${domain}#ss-ws-tls"
sslink2="ss://${ss_base64}@$domain:80?path=/ss-ws&security=none&host=${domain}&type=ws#ss-ws-ntls"
sslink3="ss://${ss_base64}@$domain:443?path=/ss-hup&security=tls&host=${domain}&type=httpupgrade&sni=${domain}#ss-hup-tls"
sslink4="ss://${ss_base64}@$domain:80?path=/ss-hup&security=none&host=${domain}&type=httpupgrade#ss-hup-ntls"
sslink5="ss://${ss_base64}@$domain:443?security=tls&encryption=none&type=grpc&serviceName=ss-grpc&sni=$domain#ss-grpc"

ss2022_base64=$(encode_ss "$cipher2" "$serverpsk:$userpsk")
ss22link1="ss://${ss2022_base64}@$domain:443?path=/ss22-ws&security=tls&host=${domain}&type=ws&sni=${domain}#ss2022-ws-tls"
ss22link2="ss://${ss2022_base64}@$domain:80?path=/ss22-ws&security=none&host=${domain}&type=ws#ss2022-ws-ntls"
ss22link3="ss://${ss2022_base64}@$domain:443?path=/ss22-hup&security=tls&host=${domain}&type=httpupgrade&sni=${domain}#ss2022-hup-tls"
ss22link4="ss://${ss2022_base64}@$domain:80?path=/ss22-hup&security=none&host=${domain}&type=httpupgrade#ss2022-hup-ntls"
ss22link5="ss://${ss2022_base64}@$domain:443?security=tls&encryption=none&type=grpc&serviceName=ss22-grpc&sni=$domain#ss2022-grpc"

{
echo "======================================================"
echo "                ----- [ All Xray ] -----"
echo "======================================================"
echo "ISP            : $ISP"
echo "Region         : $REG"
echo "City           : $CITY"
echo "Port TLS/HTTPS : 443"
echo "Port HTTP      : 80"
echo "Transport      : XTLS-Vision, TCP TLS, Websocket, HTTPupgrade, gRPC"
echo "Expired On     : $exp"
echo "Link / Web     : https://$domain/xray/xray-$user.html"
echo "======================================================"
echo "              ----- [ Vmess Link ] -----"
echo "------------------------------------------------------"
echo "Link WS TLS    : $vmesslink1"
echo "Link WS nTLS   : $vmesslink2"
echo "Link HUP TLS   : $vmesslink3"
echo "Link HUP nTLS  : $vmesslink4"
echo "Link gRPC      : $vmesslink5"
echo "======================================================"
echo "              ----- [ Vless Link ] -----"
echo "------------------------------------------------------"
echo "Link WS TLS      : $vlesslink1"
echo "Link WS nTLS     : $vlesslink2"
echo "Link HUP TLS     : $vlesslink3"
echo "Link HUP nTLS    : $vlesslink4"
echo "Link gRPC        : $vlesslink5"
echo "Link XTLS-Vision : $vlesslink6"
echo "======================================================"
echo "              ----- [ Trojan Link ] -----"
echo "------------------------------------------------------"
echo "Link WS TLS      : $trojanlink1"
echo "Link WS nTLS     : $trojanlink2"
echo "Link HUP TLS     : $trojanlink3"
echo "Link HUP nTLS    : $trojanlink4"
echo "Link gRPC        : $trojanlink5"
echo "Link TCP TLS     : $trojanlink6"
echo "======================================================"
echo "          ----- [ Shadowsocks Link ] -----"
echo "------------------------------------------------------"
echo "Link WS TLS      : $sslink1"
echo "Link WS nTLS     : $sslink2"
echo "Link HUP TLS     : $sslink3"
echo "Link HUP nTLS    : $sslink4"
echo "Link gRPC        : $sslink5"
echo "======================================================"
echo "       ----- [ Shadowsocks 2022 Link ] -----"
echo "------------------------------------------------------"
echo "Link WS TLS      : $ss22link1"
echo "Link WS nTLS     : $ss22link2"
echo "Link HUP TLS     : $ss22link3"
echo "Link HUP nTLS    : $ss22link4"
echo "Link gRPC        : $ss22link5"
echo "======================================================"
echo "User  : $user"
echo "UUID  : $uuid"
echo "Exp   : $exp"
echo "======================================================"
} | tee "${LOG_DIR}/xray-${user}.log"

if [ -z "${XRAY_NO_RESTART:-}" ]; then
    systemctl restart --no-block xray
fi

echo -e "${GB}User '$user' created, expire $exp.${NC}"
exit 0