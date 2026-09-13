#!/usr/bin/env python3
"""Xray Telegram Bot v2 - manage Xray accounts via Telegram (interactive, inline buttons).

Konfigurasi : /usr/local/etc/xray/bot.conf
  BOT_TOKEN=123456:ABC
  ADMIN_CHAT_ID=123456789     (kosong = admin pertama yang hubungi bot = auto-set)
  MODE=private|public
      private : HANYA admin yang bisa buat/hapus/perpanjang akun.
      public  : SEMUA user bisa buat 1 akun sendiri. Untuk mengganti akun, user
                HARUS hapus akunnya dulu lewat menu Delete, baru bisa create lagi.

Database pemilik akun (chat_id -> username): /usr/local/etc/xray/bot_users.json

Semua interaksi memakai tombol inline (callback). Klaim via menu atau ketik /start.
"""

import json
import os
import random
import re
import signal
import string
import subprocess
import sys
import time

import requests

CONF = "/usr/local/etc/xray/bot.conf"
UDB = "/usr/local/etc/xray/bot_users.json"
API = "https://api.telegram.org/bot{token}"
POLL_TIMEOUT = 50
MAX_LEN = 4000
ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")

FLOWS = {}


def log(msg):
    print("[bot] %s" % msg, flush=True)


# ---------- config / users ----------
def load_conf():
    data = {"BOT_TOKEN": "", "ADMIN_CHAT_ID": "", "MODE": "private"}
    try:
        with open(CONF, "r") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith(("#", ";")) or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                data[k.strip()] = v.strip()
    except FileNotFoundError:
        pass
    if data.get("MODE") not in ("public", "private"):
        data["MODE"] = "private"
    return data


def save_conf(data):
    tmp = CONF + ".tmp"
    with open(tmp, "w") as f:
        f.write("BOT_TOKEN=%s\n" % data.get("BOT_TOKEN", ""))
        f.write("ADMIN_CHAT_ID=%s\n" % data.get("ADMIN_CHAT_ID", ""))
        f.write("MODE=%s\n" % (data.get("MODE", "private") or "private"))
    os.replace(tmp, CONF)


def load_users():
    try:
        with open(UDB, "r") as f:
            return json.load(f)
    except Exception:
        return {}


def save_users(users):
    tmp = UDB + ".tmp"
    with open(tmp, "w") as f:
        json.dump(users, f)
    os.replace(tmp, UDB)


def is_admin(chat_id, data):
    aid = str(data.get("ADMIN_CHAT_ID", "") or "").strip()
    return bool(aid) and str(chat_id) == aid


def is_public(data):
    return data.get("MODE", "private") == "public"


# ---------- telegram api ----------
def api(token, method, **params):
    try:
        r = requests.post(API.format(token=token) + "/" + method,
                          data=params, timeout=60)
        return r.json()
    except Exception as e:
        return {"ok": False, "description": str(e)}


def send_message(token, chat_id, text, kb=None):
    text = ANSI_RE.sub("", str(text)).strip()
    if not text:
        text = "(empty)"
    for i in range(0, len(text), MAX_LEN):
        params = {"chat_id": chat_id, "text": text[i:i + MAX_LEN]}
        if kb is not None:
            params["reply_markup"] = json.dumps(kb)
        api(token, "sendMessage", **params)
        time.sleep(0.3)
        kb = None


def edit_message(token, chat_id, message_id, text, kb=None):
    text = ANSI_RE.sub("", str(text)).strip()
    params = {"chat_id": chat_id, "message_id": message_id, "text": text}
    if kb is not None:
        params["reply_markup"] = json.dumps(kb)
    r = api(token, "editMessageText", **params)
    if not r.get("ok"):
        send_message(token, chat_id, text, kb)


def answer_cb(token, cb_id, text=""):
    api(token, "answerCallbackQuery", callback_query_id=cb_id, text=text)


# ---------- keyboards ----------
def mk(rows):
    return {"inline_keyboard": rows}


def main_kb():
    return mk([
        [{"text": "Create Account", "callback_data": "create"}],
        [{"text": "Delete Account", "callback_data": "del"}],
        [{"text": "Extend Account", "callback_data": "extend"}],
        [{"text": "My Info", "callback_data": "info"},
         {"text": "List Users", "callback_data": "list"}],
        [{"text": "Traffic", "callback_data": "traffic"},
         {"text": "Server", "callback_data": "server"}],
        [{"text": "Restart Xray", "callback_data": "restart"}],
        [{"text": "Bot Mode", "callback_data": "mode"}],
    ])


def days_kb():
    return mk([
        [{"text": "7 days", "callback_data": "days:7"},
         {"text": "30 days", "callback_data": "days:30"},
         {"text": "90 days", "callback_data": "days:90"}],
        [{"text": "Custom days", "callback_data": "days:custom"},
         {"text": "Cancel", "callback_data": "cancel"}],
    ])


def crt_kb():
    return mk([
        [{"text": "Auto username", "callback_data": "crt:auto"},
         {"text": "Custom username", "callback_data": "crt:custom"}],
        [{"text": "Cancel", "callback_data": "cancel"}],
    ])


def confirm_kb():
    return mk([
        [{"text": "Yes, delete", "callback_data": "confirm:yes"},
         {"text": "Cancel", "callback_data": "cancel"}],
    ])


def mode_kb():
    return mk([
        [{"text": "Public", "callback_data": "mode:public"},
         {"text": "Private (admin only)", "callback_data": "mode:private"}],
        [{"text": "Cancel", "callback_data": "cancel"}],
    ])


# ---------- helpers ----------
def run(cmd, timeout=120):
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=timeout)
        return p.returncode, p.stdout.decode("utf-8", errors="replace")
    except subprocess.TimeoutExpired:
        return 1, "Timeout perintah (>{0}s)".format(timeout)
    except FileNotFoundError as e:
        return 1, "File tidak ditemukan: %s" % e


def gen_user():
    return "user" + "".join(random.choices(string.ascii_lowercase + string.digits, k=5))


def read_log(username):
    path = "/user/xray-%s.log" % username
    if os.path.isfile(path):
        with open(path, "r", errors="replace") as f:
            return f.read()
    return "(log akun tidak ditemukan di server)"


def main_menu_text(data):
    mode = data.get("MODE", "private")
    return (
        "Xray Manager Bot\n"
        "------------------\n"
        "Mode akses saat ini : %s\n"
        "Pilih menu dengan tombol di bawah." % mode
    )


def own_account(chat_id, users):
    return users.get(str(chat_id))


# ---------- actions ----------
def exec_create(chat_id, data, users, days, username=None):
    admin = is_admin(chat_id, data)
    if username is None:
        username = gen_user()
    for _ in range(5):
        rc, out = run(["/usr/bin/add-user", username, str(days)])
        if rc == 0:
            break
        if "already exists" in out.lower():
            username = gen_user()
            continue
        break
    if rc != 0:
        return ("Gagal membuat akun:\n%s" % ANSI_RE.sub("", out), None)
    FLOWS.pop(str(chat_id), None)
    if not admin:
        users[str(chat_id)] = username
        save_users(users)
    links = read_log(username)
    msg = (
        "Akun dibuat.\n"
        "Username : `%s`\n"
        "Masa aktif : %s hari\n"
        "----------------\n"
        "%s" % (username, days, links)
    )
    return (msg, main_kb())


def start_create(chat_id, data, users):
    admin = is_admin(chat_id, data)
    if not admin and not is_public(data):
        return ("Khusus admin (bot sedang mode Private).", None)
    if not admin:
        own = own_account(chat_id, users)
        if own:
            return (
                "Kamu sudah punya akun `%s`.\n"
                "Tiap user hanya boleh 1 akun. Untuk membuat yang baru, "
                "hapus akun kamu dulu lewat menu Delete Account." % own,
                None,
            )
        FLOWS[str(chat_id)] = {"step": "crt_days_auto", "user": None}
        return ("Pilih masa aktif akun kamu:", days_kb())
    FLOWS[str(chat_id)] = {"step": None, "user": None}
    return ("Buat akun admin. Pilih username:", crt_kb())


def start_del(chat_id, data, users):
    admin = is_admin(chat_id, data)
    if not admin and not is_public(data):
        return ("Khusus admin (bot sedang mode Private).", None)
    if not admin:
        own = own_account(chat_id, users)
        if not own:
            return ("Kamu belum punya akun.", None)
        FLOWS[str(chat_id)] = {"step": "confirm", "user": own}
        return (
            "Hapus akun kamu (`%s`)? Tindakan ini tidak bisa dibatalkan." % own,
            confirm_kb(),
        )
    FLOWS[str(chat_id)] = {"step": "del_user", "user": None}
    return ("Ketik username yang akan dihapus:", None)


def confirm_del(chat_id, data, users):
    st = FLOWS.get(str(chat_id)) or {}
    username = st.get("user")
    if not username:
        return ("Tidak ada akun yang dipilih untuk dihapus.", main_kb())
    admin = is_admin(chat_id, data)
    rc, out = run(["/usr/bin/del-user", username])
    FLOWS.pop(str(chat_id), None)
    if rc == 0:
        if not admin:
            users.pop(str(chat_id), None)
            save_users(users)
        return ("Akun `%s` berhasil dihapus." % username, main_kb())
    return ("Gagal hapus `%s`:\n%s" % (username, ANSI_RE.sub("", out)), main_kb())


def start_extend(chat_id, data, users):
    admin = is_admin(chat_id, data)
    if not admin and not is_public(data):
        return ("Khusus admin (bot sedang mode Private).", None)
    if not admin:
        own = own_account(chat_id, users)
        if not own:
            return ("Kamu belum punya akun.", None)
        FLOWS[str(chat_id)] = {"step": "ext_days", "user": own}
        return (
            "Perpanjang akun kamu (`%s`). Pilih tambahan hari:" % own,
            days_kb(),
        )
    FLOWS[str(chat_id)] = {"step": "ext_user", "user": None}
    return ("Ketik username yang akan diperpanjang:", None)


def exec_extend(chat_id, data, username, days):
    rc, out = run(["/usr/bin/extend-user", username, str(days)])
    FLOWS.pop(str(chat_id), None)
    if rc == 0:
        return ("Akun `%s` diperpanjang +%s hari." % (username, days), main_kb())
    return ("Gagal perpanjang `%s`:\n%s" % (username, ANSI_RE.sub("", out)), main_kb())


def do_list(chat_id, data, users):
    admin = is_admin(chat_id, data)
    if admin:
        rc, out = run(["/usr/bin/list-user"])
        return (out or "Gagal (rc=%s)" % rc, main_kb())
    own = own_account(chat_id, users)
    if own:
        rc, out = run(["/usr/bin/list-user"])
        hit = [ln for ln in out.splitlines() if own in ln]
        return ("Akun kamu:\n" + "\n".join(hit), main_kb())
    return ("Kamu belum punya akun.", main_kb())


def do_info(chat_id, data, users):
    admin = is_admin(chat_id, data)
    own = own_account(chat_id, users)
    lines = [
        "Chat ID : %s" % chat_id,
        "Mode    : %s" % data.get("MODE", "private"),
        "Role    : %s" % ("ADMIN" if admin else "user"),
    ]
    if own:
        lines.append("Akun    : `%s`" % own)
    return ("\n".join(lines), main_kb())


def do_traffic(chat_id, data):
    rc, out = run(["/usr/bin/timeout", "30", "/usr/bin/python3", "/usr/bin/traffic.py"])
    return (out or "Tidak ada data (rc=%s)." % rc, main_kb())


def do_server(chat_id, data):
    rc, out = run(["/usr/bin/timeout", "30", "/usr/bin/python3", "/usr/bin/system_info.py"])
    return (out or "Tidak ada data (rc=%s)." % rc, main_kb())


def do_restart(chat_id, data):
    rc, out = run(["/usr/bin/systemctl", "restart", "xray"])
    if rc == 0:
        return ("Service xray di-restart.", main_kb())
    return ("Gagal restart (rc=%s)." % rc, main_kb())


def do_status(chat_id, data):
    lines = []
    for svc in ("xray", "nginx", "xraybot"):
        rc, out = run(["/usr/bin/systemctl", "is-active", svc], timeout=15)
        lines.append("%s : %s" % (svc, out.strip() or "inactive"))
    return ("\n".join(lines), main_kb())


# ---------- dispatch ----------
def handle_callback(token, chat_id, message_id, cb_id, cdata, data, users):
    admin = is_admin(chat_id, data)

    if cdata == "menu":
        return main_menu_text(data), main_kb()
    if cdata == "cancel":
        FLOWS.pop(str(chat_id), None)
        return "Dibatalkan.", main_kb()

    if cdata == "create":
        return start_create(chat_id, data, users)
    if cdata == "del":
        return start_del(chat_id, data, users)
    if cdata == "extend":
        return start_extend(chat_id, data, users)
    if cdata == "info":
        return do_info(chat_id, data, users)
    if cdata == "list":
        return do_list(chat_id, data, users)
    if cdata == "traffic":
        return do_traffic(chat_id, data)
    if cdata == "server":
        return do_server(chat_id, data)
    if cdata == "restart":
        if not admin:
            return "Khusus admin.", None
        return do_restart(chat_id, data)
    if cdata == "status":
        if not admin:
            return "Khusus admin.", None
        return do_status(chat_id, data)

    if cdata == "mode":
        if not admin:
            return "Khusus admin.", None
        return "Mode akses bot saat ini : %s" % data.get("MODE", "private"), mode_kb()

    if cdata.startswith("mode:"):
        if not admin:
            return "Khusus admin.", None
        val = cdata.split(":", 1)[1]
        if val in ("public", "private"):
            data["MODE"] = val
            save_conf(data)
            return "Mode akses bot diset ke %s." % val, main_kb()
        return "Mode tidak valid.", None

    if cdata.startswith("crt:"):
        if not admin:
            return "Khusus admin.", None
        val = cdata.split(":", 1)[1]
        if val == "auto":
            FLOWS[str(chat_id)] = {"step": "crt_days_auto", "user": None}
            return "Pilih masa aktif akun:", days_kb()
        FLOWS[str(chat_id)] = {"step": "crt_user", "user": None}
        return "Ketik username baru (a-z, 0-9, _):", None

    if cdata.startswith("days:"):
        st = FLOWS.get(str(chat_id)) or {}
        step = st.get("step")
        val = cdata.split(":", 1)[1]
        if val == "custom":
            if step in ("crt_days", "crt_days_auto", "ext_days"):
                return "Ketik jumlah hari (bilangan):", None
            return "Silakan pilih lewat menu utama.", None
        if not val.isdigit():
            return "Hari harus angka.", None
        n = int(val)
        if step == "crt_days_auto":
            return exec_create(chat_id, data, users, n, None)
        if step == "crt_days":
            return exec_create(chat_id, data, users, n, st.get("user"))
        if step == "ext_days":
            return exec_extend(chat_id, data, st.get("user"), n)
        return "Pilih action dulu lewat menu utama.", None

    if cdata.startswith("confirm:"):
        val = cdata.split(":", 1)[1]
        if val == "yes":
            return confirm_del(chat_id, data, users)
        FLOWS.pop(str(chat_id), None)
        return "Dibatalkan.", main_kb()

    return "Menu tidak dikenal.", main_kb()


def handle_text(token, chat_id, text, data, users):
    t = text.strip()
    low = t.lower()

    if low in ("/start", "/help", "/menu", "/main"):
        FLOWS.pop(str(chat_id), None)
        return main_menu_text(data), main_kb()

    if low == "/id":
        return ("Chat ID kamu : %s" % chat_id, main_kb())

    st = FLOWS.get(str(chat_id))
    if st:
        step = st.get("step")
        if step == "crt_user":
            if not re.match(r"^[a-zA-Z0-9_]+$", t):
                return "Username hanya a-z, 0-9, _:", None
            st["user"] = t
            st["step"] = "crt_days"
            return "Masa aktif untuk `%s`? Pilih hari:" % t, days_kb()
        if step == "crt_days" or step == "crt_days_auto":
            if not t.isdigit():
                return "Jumlah hari harus bilangan:", None
            return exec_create(chat_id, data, users, int(t),
                               st.get("user") if step == "crt_days" else None)
        if step == "del_user":
            st["user"] = t
            st["step"] = "confirm"
            return "Hapus akun `%s`? Konfirmasi:" % t, confirm_kb()
        if step == "ext_user":
            st["user"] = t
            st["step"] = "ext_days"
            return "Tambahan hari untuk `%s`:" % t, days_kb()
        if step == "ext_days":
            if not t.isdigit():
                return "Jumlah hari harus bilangan:", None
            return exec_extend(chat_id, data, st.get("user"), int(t))
        FLOWS.pop(str(chat_id), None)

    return "Gunakan tombol menu di bawah / ketik /start:", main_kb()


# ---------- main ----------
def main():
    def _stop(signum, frame):
        log("stopped (signal %s)" % signum)
        sys.exit(0)

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)

    data = load_conf()
    token = data.get("BOT_TOKEN", "").strip()
    if not token:
        for _ in range(30):
            time.sleep(10)
            data = load_conf()
            if data.get("BOT_TOKEN", "").strip():
                token = data["BOT_TOKEN"].strip()
                break
    if not token:
        log("BOT_TOKEN belum diset di %s. Keluar." % CONF)
        sys.exit(1)

    users = load_users()
    offset = None
    while True:
        params = {"timeout": POLL_TIMEOUT}
        if offset is not None:
            params["offset"] = offset
        try:
            r = requests.post(API.format(token=token) + "/getUpdates",
                              data=params, timeout=POLL_TIMEOUT + 15)
            resp = r.json()
        except Exception as e:
            log("getUpdates error: %s" % e)
            time.sleep(5)
            continue

        if not resp.get("ok"):
            desc = str(resp.get("description", ""))
            log("api error: %s" % desc)
            if "conflict" in desc.lower():
                log("Bot dijalankan dua proses / atau Webhook aktif -> keluar.")
                sys.exit(1)
            time.sleep(5)
            continue

        updates = resp.get("result", [])
        data = load_conf()
        for up in updates:
            up_id = up.get("update_id")
            cb = up.get("callback_query")
            msg = up.get("message") or {}
            chat = msg.get("chat") or {}
            if not chat and cb:
                chat = (cb.get("message") or {}).get("chat") or {}
            if chat.get("type") != "private":
                continue
            chat_id = chat.get("id")

            admin_id = str(data.get("ADMIN_CHAT_ID", "") or "").strip()
            if not admin_id and (msg.get("text") or cb):
                data["ADMIN_CHAT_ID"] = str(chat_id)
                save_conf(data)
                admin_id = str(chat_id)
                log("admin auto-set: %s" % chat_id)
                send_message(token, chat_id,
                             "Kamu terdaftar sebagai ADMIN (chat ID %s). "
                             "Ketik /start" % chat_id)
                continue

            try:
                if cb:
                    cdata = cb.get("data", "")
                    cb_id = cb.get("id")
                    cb_msg = cb.get("message") or {}
                    cb_edit = cb_msg.get("message_id")
                    reply, kb = handle_callback(token, chat_id, cb_edit, cb_id,
                                                cdata, data, users)
                    if reply is None:
                        reply = "(empty)"
                    edit_message(token, chat_id, cb_edit, reply, kb)
                elif msg.get("text"):
                    text = msg.get("text", "")
                    reply, kb = handle_text(token, chat_id, text, data, users)
                    send_message(token, chat_id, reply, kb)
            except Exception as e:
                log("handle error: %s" % e)
                send_message(token, chat_id, "Error internal: %s" % e)
            offset = up_id + 1

        if updates:
            offset = updates[-1]["update_id"] + 1


if __name__ == "__main__":
    main()