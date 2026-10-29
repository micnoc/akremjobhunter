"""Telegram bot (with inline action buttons) and robust WhatsApp (CallMeBot with retries) notifications."""
from __future__ import annotations

import html
import logging
import re
import secrets
import threading
import time
import urllib.parse
from typing import Any, Callable

import requests

from . import settings_store as store

log = logging.getLogger("notify")
API = "https://api.telegram.org/bot{token}/{method}"

# In-memory mapping of deep-link tokens to user IDs for multi-user isolation
_pending_telegram_auth: dict[str, int] = {}


def esc(text: str | None) -> str:
    return html.escape(text or "")


def _tg(method: str, token: str | None = None, files=None, http_timeout: int = 30, **payload):
    token = token or store.get("telegram_bot_token")
    if not token:
        return None
    url = API.format(token=token, method=method)
    try:
        if files:
            r = requests.post(url, data=payload, files=files, timeout=http_timeout)
        else:
            r = requests.post(url, json=payload, timeout=http_timeout)
        data = r.json()
        if not data.get("ok"):
            log.warning("Telegram %s failed: %s", method, data.get("description"))
        return data
    except Exception as exc:
        log.warning("Telegram %s error: %s", method, exc)
        return None


def _keyboard(buttons: list[list[tuple[str, str]]] | None):
    if not buttons:
        return None
    rows = []
    for row in buttons:
        rows.append([
            {"text": label, "url": data[4:]} if data.startswith("url:") else {"text": label, "callback_data": data}
            for label, data in row
        ])
    return {"inline_keyboard": rows}


def send(text: str, buttons: list[list[tuple[str, str]]] | None = None, whatsapp: bool = False, user_id: int | None = None) -> bool:
    chat_id = store.get("telegram_chat_id", user_id=user_id)
    token = store.get("telegram_bot_token", user_id=user_id)
    ok = False
    if chat_id:
        payload = {"chat_id": chat_id, "text": text[:4000], "parse_mode": "HTML", "disable_web_page_preview": True}
        kb = _keyboard(buttons)
        if kb:
            payload["reply_markup"] = kb
        res = _tg("sendMessage", token=token, **payload)
        ok = bool(res and res.get("ok"))
    if whatsapp:
        send_whatsapp(_strip_html(text), user_id=user_id)
    return ok


def send_document(path: str, caption: str, user_id: int | None = None) -> bool:
    chat_id = store.get("telegram_chat_id", user_id=user_id)
    token = store.get("telegram_bot_token", user_id=user_id)
    if not chat_id:
        return False
    with open(path, "rb") as f:
        res = _tg("sendDocument", token=token, files={"document": f}, http_timeout=90,
                  chat_id=str(chat_id), caption=caption[:1000], parse_mode="HTML")
    return bool(res and res.get("ok"))


def normalize_phone(phone: str | None) -> str:
    if not phone:
        return ""
    # Strip any characters except digits
    digits = re.sub(r"[^0-9]", "", phone)
    return digits


def send_whatsapp(text: str, user_id: int | None = None) -> dict[str, Any]:
    """Robust WhatsApp delivery with phone normalization, parameter validation, and retry logic."""
    raw_phone = store.get("whatsapp_phone", user_id=user_id)
    key = store.get("callmebot_apikey", user_id=user_id)

    if not raw_phone or not key:
        return {
            "ok": False,
            "status": "NOT_CONFIGURED",
            "message": "WhatsApp phone number or CallMeBot API key is missing in Settings.",
        }

    phone = normalize_phone(str(raw_phone))
    if len(phone) < 8:
        return {
            "ok": False,
            "status": "INVALID_PHONE",
            "message": f"Invalid phone format: '{raw_phone}'. Enter international number with country code (e.g. 21698123456).",
        }

    key = str(key).strip()
    encoded_text = urllib.parse.quote(text[:1500])
    url = f"https://api.callmebot.com/whatsapp.php?phone={phone}&text={encoded_text}&apikey={key}"

    last_error = ""
    for attempt in range(1, 4):
        try:
            resp = requests.get(url, timeout=25)
            if resp.status_code == 200:
                resp_text = resp.text.lower()
                if "error" in resp_text and ("apikey" in resp_text or "not allowed" in resp_text):
                    return {
                        "ok": False,
                        "status": "AUTH_ERROR",
                        "message": "CallMeBot API key is unauthorized. Please verify the key sent to your WhatsApp by the bot.",
                    }
                return {
                    "ok": True,
                    "status": "DELIVERED",
                    "attempt": attempt,
                    "phone": phone,
                    "message": "WhatsApp notification dispatched successfully.",
                }
            else:
                last_error = f"HTTP {resp.status_code}: {resp.text[:150]}"
        except Exception as exc:
            last_error = str(exc)

        if attempt < 3:
            time.sleep(1.0 * attempt)

    return {
        "ok": False,
        "status": "FAILED",
        "attempts": 3,
        "phone": phone,
        "error": last_error,
        "message": f"WhatsApp delivery failed after 3 attempts: {last_error}",
    }


def _strip_html(text: str) -> str:
    return html.unescape(re.sub(r"<[^>]+>", "", text))


def get_telegram_connect_url(user_id: int) -> dict[str, Any]:
    token = store.get("telegram_bot_token", user_id=user_id)
    if not token:
        return {
            "ok": False,
            "error": "Telegram Bot Token is not configured. Enter bot token in Settings.",
        }
    me = _tg("getMe", token=token)
    if not me or not me.get("ok"):
        return {
            "ok": False,
            "error": "Invalid Telegram Bot Token or connection timed out.",
        }

    bot_username = me["result"]["username"]
    auth_code = f"user_{user_id}_{secrets.token_hex(4)}"
    _pending_telegram_auth[auth_code] = user_id

    return {
        "ok": True,
        "bot_username": bot_username,
        "url": f"https://t.me/{bot_username}?start={auth_code}",
        "auth_code": auth_code,
        "instructions": f"1. Open https://t.me/{bot_username}\n2. Press START to link your VisaJob AI account.",
    }


def get_telegram_diagnostics(user_id: int | None = None) -> dict[str, Any]:
    token = store.get("telegram_bot_token", user_id=user_id)
    chat_id = store.get("telegram_chat_id", user_id=user_id)

    if not token:
        return {
            "configured": False,
            "bot_online": False,
            "chat_linked": False,
            "status": "UNCONFIGURED",
            "message": "Bot token not configured.",
        }

    me = _tg("getMe", token=token)
    if not me or not me.get("ok"):
        return {
            "configured": True,
            "bot_online": False,
            "chat_linked": bool(chat_id),
            "status": "INVALID_TOKEN",
            "message": "Bot token is invalid or rejected by Telegram API.",
        }

    bot_username = me["result"]["username"]
    return {
        "configured": True,
        "bot_online": True,
        "bot_username": bot_username,
        "chat_linked": bool(chat_id),
        "chat_id": str(chat_id) if chat_id else None,
        "status": "CONNECTED" if chat_id else "AWAITING_LINK",
        "message": f"Bot @{bot_username} is operational. Chat linked: {bool(chat_id)}",
    }


def test_telegram(user_id: int | None = None) -> dict[str, Any]:
    token = store.get("telegram_bot_token", user_id=user_id)
    if not token:
        return {"ok": False, "message": "Telegram bot token not configured"}
    me = _tg("getMe", token=token)
    if not me or not me.get("ok"):
        return {"ok": False, "message": "Invalid Telegram bot token"}
    username = me["result"]["username"]
    chat_id = store.get("telegram_chat_id", user_id=user_id)
    if not chat_id:
        return {
            "ok": False,
            "message": f"Bot @{username} is valid, but no chat is linked. Click 'Connect Telegram' and press Start.",
        }
    delivered = send("<b>VisaJob AI</b>\nTelegram channel verified. You will receive real-time interview and offer notifications here.", user_id=user_id)
    if not delivered:
        return {"ok": False, "message": "Could not deliver message to the linked chat. Ensure the bot is unblocked."}
    return {"ok": True, "message": f"Test notification delivered successfully via @{username}!"}


# ---------------------------------------------------------------- update polling
CallbackHandler = Callable[[str], str]


class TelegramPoller(threading.Thread):
    """Long-polls getUpdates; links user chats on /start <auth_code> and dispatches button callbacks."""

    def __init__(self, on_callback: CallbackHandler):
        super().__init__(daemon=True, name="telegram-poller")
        self.on_callback = on_callback
        self._halt = threading.Event()

    def stop(self) -> None:
        self._halt.set()

    def run(self) -> None:
        while not self._halt.is_set():
            token = store.get("telegram_bot_token")
            if not token:
                time.sleep(15)
                continue
            offset = int(store.get("telegram_update_offset") or 0)
            res = _tg("getUpdates", token=token, http_timeout=70, offset=offset, timeout=50,
                      allowed_updates=["message", "callback_query"])
            if not res or not res.get("ok"):
                time.sleep(10)
                continue
            for upd in res.get("result", []):
                store.put("telegram_update_offset", upd["update_id"] + 1)
                try:
                    self._handle(upd, token=token)
                except Exception as exc:
                    log.exception("Update handling failed: %s", exc)

    def _handle(self, upd: dict, token: str) -> None:
        if "message" in upd:
            chat_id = str(upd["message"]["chat"]["id"])
            text = (upd["message"].get("text") or "").strip()
            if text.startswith("/start"):
                parts = text.split()
                if len(parts) > 1:
                    code = parts[1].strip()
                    target_user = _pending_telegram_auth.get(code)
                    if target_user:
                        store.put("telegram_chat_id", chat_id, user_id=target_user)
                        _pending_telegram_auth.pop(code, None)
                        _tg("sendMessage", token=token, chat_id=chat_id, parse_mode="HTML",
                            text="<b>VisaJob AI</b>\n✅ Your account has been connected successfully!\nYou will now receive instant interview invitations, employment contracts, and security alerts.")
                        return

                # Default linking
                store.put("telegram_chat_id", chat_id)
                _tg("sendMessage", token=token, chat_id=chat_id, parse_mode="HTML",
                    text="<b>VisaJob AI</b>\n✅ This chat is now linked. You will receive verified responses, interview preparations and review requests here.")
                return

        cq = upd.get("callback_query")
        if not cq:
            return
        chat_id = str(cq["message"]["chat"]["id"])
        result = self.on_callback(cq.get("data", ""))
        _tg("answerCallbackQuery", token=token, callback_query_id=cq["id"], text=result[:190])
        original = cq["message"].get("text") or ""
        _tg("editMessageText", token=token, chat_id=chat_id, message_id=cq["message"]["message_id"],
            text=f"{esc(original)}\n\n— {esc(result)}"[:4000], parse_mode="HTML", disable_web_page_preview=True)
