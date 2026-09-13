#!/bin/bash

# Bot Telegram Xray - menu setup & kontrol service xraybot
NC='\e[0m'
DEFBOLD='\e[39;1m'
RB='\e[31;1m'
GB='\e[32;1m'
YB='\e[33;1m'
BB='\e[34;1m'
MB='\e[35;1m'
CB='\e[36;1m'
WB='\e[37;1m'

BOT_CONF="/usr/local/etc/xray/bot.conf"

read_conf() {
    BOT_TOKEN=""
    ADMIN_CHAT_ID=""
    if [ -f "$BOT_CONF" ]; then
        BOT_TOKEN=$(grep -E "^(BOT_TOKEN|BOT_TOKEN )" "$BOT_CONF" | cut -d= -f2-)
        ADMIN_CHAT_ID=$(grep -E "^ADMIN_CHAT_ID" "$BOT_CONF" | cut -d= -f2-)
    fi
}

write_conf() {
    echo "BOT_TOKEN=$BOT_TOKEN" > "$BOT_CONF"
    echo "ADMIN_CHAT_ID=$ADMIN_CHAT_ID" >> "$BOT_CONF"
}

show_menu() {
    clear
    read_conf
    echo -e "${BB}————————————————————————————————————————————————————————${NC}"
    echo -e "              ${WB}----- [ Bot Telegram Menu ] -----${NC}            "
    echo -e "${BB}————————————————————————————————————————————————————————${NC}"
    if [ -n "$BOT_TOKEN" ]; then
        echo -e " ${YB}Token  :${NC} ${GB}${BOT_TOKEN:0:8}...${NC}"
    else
        echo -e " ${YB}Token  :${NC} ${RB}belum diset${NC}"
    fi
    if [ -n "$ADMIN_CHAT_ID" ]; then
        echo -e " ${YB}Admin  :${NC} ${GB}$ADMIN_CHAT_ID${NC}"
    else
        echo -e " ${YB}Admin  :${NC} ${RB}belum diset (otomatis ke chat pertama)${NC}"
    fi
    echo -e "${BB}————————————————————————————————————————————————————————${NC}"
    echo -e " ${MB}[1]${NC} ${YB}Set BOT Token${NC}"
    echo -e " ${MB}[2]${NC} ${YB}Set Admin ID${NC}"
    echo -e " ${MB}[3]${NC} ${YB}Start Bot${NC}"
    echo -e " ${MB}[4]${NC} ${YB}Stop Bot${NC}"
    echo -e " ${MB}[5]${NC} ${YB}Restart Bot${NC}"
    echo -e " ${MB}[6]${NC} ${YB}Status Bot${NC}"
    echo -e " ${MB}[7]${NC} ${YB}Log Bot${NC}"
    echo -e " ${MB}[0]${NC} ${YB}Back To Menu${NC}"
    echo -e "${BB}————————————————————————————————————————————————————————${NC}"
}

set_token() {
    read_conf
    read -rp "Masukkan BOT TOKEN Telegram : " token_input
    if [ -z "$token_input" ]; then
        echo -e "${RB}Token tidak boleh kosong!${NC}"
        sleep 2
        return
    fi
    BOT_TOKEN="$token_input"
    write_conf
    echo -e "${GB}Token disimpan.${NC} ${YB}Start ulang bot agar aktif.${NC}"
    sleep 2
}

set_admin() {
    read_conf
    read -rp "Masukkan Admin Chat ID (isi chat /id ke bot, atau kosongkan utk auto-set): " admin_input
    ADMIN_CHAT_ID="$admin_input"
    write_conf
    echo -e "${GB}Admin disimpan.${NC}"
    sleep 2
}

start_bot() {
    read_conf
    if [ -z "$BOT_TOKEN" ]; then
        echo -e "${RB}Set BOT TOKEN dulu (menu 1).${NC}"
        sleep 2
        return
    fi
    sudo systemctl daemon-reload
    sudo systemctl enable xraybot
    sudo systemctl restart xraybot
    echo -e "${GB}Bot dijalankan.${NC}"
    sleep 2
}

stop_bot() {
    sudo systemctl disable --now xraybot 2>/dev/null
    sudo systemctl stop xraybot
    echo -e "${YB}Bot dihentikan.${NC}"
    sleep 2
}

restart_bot() {
    sudo systemctl restart xraybot
    echo -e "${GB}Bot di-restart.${NC}"
    sleep 2
}

bot_status() {
    clear
    echo -e "${YB}Status xraybot :${NC}"
    sudo systemctl is-active xraybot || true
    echo ""
    sudo systemctl status xraybot --no-pager -n 5
    echo -e "${BB}————————————————————————————————————————————————————————${NC}"
    read -n 1 -s -r -p "Press any key to back to menu"
}

bot_log() {
    clear
    sudo journalctl -u xraybot -n 50 --no-pager
    echo -e "${BB}————————————————————————————————————————————————————————${NC}"
    read -n 1 -s -r -p "Press any key to back to menu"
}

while true; do
    show_menu
    read -p " Select menu : " opt
    echo -e ""
    case $opt in
        1) set_token ;;
        2) set_admin ;;
        3) start_bot ;;
        4) stop_bot ;;
        5) restart_bot ;;
        6) bot_status ;;
        7) bot_log ;;
        0) clear ; menu ;;
        *) echo -e "${YB}Invalid input${NC}" ; sleep 1 ;;
    esac
done