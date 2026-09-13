## 1 Click Xray
Ubuntu or Debian

Setelah pasang ketik `menu` untuk menampilkan menu

Skrip ini aman untuk di install ulang tanpa harus rebuild VPS

Support VPS IPv6 Only, tetapi !!! saat SETUP DOMAIN wajib pilih no.2 / pilih domain sendiri (tidak mendukung opsi no.1)

Jika Script ini membantu jangan lupa sawerannya 😁😁

Saweria: https://saweria.co/dugonglewat

| Protocol & Transport | Network Port |
|----------|--------|
| Vmess Websocket | 443 & 80 |
| Vless Websocket | 443 & 80 |
| Trojan Websocket | 443 & 80 |
| Shadowsocks Websocket | 443 & 80 |
| Shadowsocks 2022 Websocket | 443 & 80 |
| Vmess HTTPupgrade | 443 & 80 |
| Vless HTTPupgrade | 443 & 80 |
| Trojan HTTPupgrade | 443 & 80 |
| Shadowsocks HTTPupgrade | 443 & 80 |
| Shadowsocks 2022 HTTPupgrade | 443 & 80 |
| Vless XTLS-RPRX-VISION | 443 |
| Trojan TCP TLS | 443 |
| Vmess gRPC | 443 |
| Vless gRPC | 443 |
| Trojan gRPC | 443 |
| Shadowsocks gRPC | 443 |
| Shadowsocks 2022 gRPC | 443 |

**Link Instalasi Opsi 1**
```
bash -c "$(wget -qO- https://raw.githubusercontent.com/alolipop0727/xray/main/install.sh)"
```
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/alolipop0727/xray/main/install.sh)"
```


**Link Instalasi Opsi 2**
```
bash -c "$(wget -qO- https://raw.githubusercontent.com/alolipop0727/xray/main/install2.sh)"
```
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/alolipop0727/xray/main/install2.sh)"
```

---

## Ringkasan Perubahan

### 1. Kompatibilitas Ubuntu 26.04 LTS ("Resolute")
- `bsdmainutils` → `bsdextrautils` (paket lama dihapus dari arsip Ubuntu 26.04)
- `libpcre3` / `libpcre3-dev` → `libpcre2-dev`
- `apt-transport-https` dihapus (sudah obsolete sejak apt >= 1.5)
- Instalasi `pip` kini memakai `--break-system-packages` (Python modern / PEP 668)
- Repo `nginx.org` memakai URL `https` (mainline mendukung Ubuntu 26.04)
- `wireproxy` kini diunduh langsung dari rilis resmi [pufferffish/wireproxy](https://github.com/pufferffish/wireproxy/releases) (mengikuti tag terbaru, otomatis sesuai arsitektur VPS), bukan binary versi lama yang disertakan di repo
- **Repo Ookla speedtest-cli (packagecloud) belum menyediakan rilis untuk Ubuntu 26.04** — installer otomatis memakai codename fallback (`noble`) dan menulis ulang source list agar `apt update` tidak gagal 404

### 2. Bot Telegram (baru)
Akhir setup akan ditanya: **"Setup Telegram Bot sekarang? (y/n)"**
- `y` → diminta **BOT TOKEN** (dari @BotFather), **Admin Chat ID** (opsional, bisa diisi lewat chat `/start` pertama), dan **mode akses** (`public` / `private`, default `private`)
- `n` → lanjut selesai, bot bisa disetup nanti lewat menu **`[0] Bot Telegram`**

Menu `[0] Bot Telegram` di dalam `menu`:
- Set Token / Set Admin ID / Set Mode
- Start, Stop, Restart, Status, dan Log bot (`journalctl -u xraybot`)

### 3. Interaksi Bot via Tombol (Inline Keyboard)
Semua perintah dikendalikan tombol, tidak perlu hafal command:
`Create Account` | `Delete Account` | `Extend Account` | `My Info` | `List Users` | `Traffic` | `Server` | `Restart Xray` | `Bot Mode`

Mode akses:
- **Private** (default): hanya Admin yang boleh membuat / menghapus / memperpanjang akun
- **Public**: siapapun boleh membuat **1 akun** sendiri; untuk mengganti harus **menghapus akunnya dulu** lewat tombol Delete, baru bisa create lagi

Admin otomatis terdaftar: chat pertama yang menghubungi bot (saat `ADMIN_CHAT_ID` kosong) akan ditetapkan sebagai admin.

### 4. Script Non-Interaktif (dipakai bot, bisa juga lewat command line)
- `/usr/bin/add-user <username> <days>` — buat akun (pengganti create-xray interaktif)
- `/usr/bin/del-user <username>` — hapus akun
- `/usr/bin/extend-user <username> <days>` — perpanjang masa aktif
- `/usr/bin/list-user` — daftar akun

### 5. Catatan WARP (`wireproxy`)
- WARP **tidak aktif secara default** — semua lalu lintas melewati outbound `direct`, sehingga matinya layanan WARP tidak berpengaruh ke jaringan
- WARP hanya dipakai bila diaktifkan lewat menu **Xray Route** (mengubah `"outboundTag": "direct"` → `"warp"` di `config/06_routing.json`)
- Jika WARP mati saat sudah diaktifkan, traffic ter-route lewat WARP akan gagal — kembalikan lewat menu Xray Route (pilih balik ke `direct`) tanpa perlu install ulang