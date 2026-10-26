"""Telegram bot (with inline action buttons) and optional WhatsApp (CallMeBot) notifications."""
from __future__ import annotations

import html
import logging
import threading
import time
import urllib.parse
from typing import Callable

import requests

from . import settings_store as store

log = logging.getLogger("notify")
API = "https://api.telegram.org/bot{token}/{method}"


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


def send(text: str, buttons: list[list[tuple[str, str]]] | None = None, whatsapp: bool = False) -> bool:
    chat_id = store.get("telegram_chat_id")
    ok = False
    if chat_id:
        payload = {"chat_id": chat_id, "text": text[:4000], "parse_mode": "HTML", "disable_web_page_preview": True}
        kb = _keyboard(buttons)
        if kb:
            payload["reply_markup"] = kb
        res = _tg("sendMessage", **payload)
        ok = bool(res and res.get("ok"))
    if whatsapp:
        send_whatsapp(_strip_html(text))
    return ok


def send_document(path: str, caption: str) -> bool:
    chat_id = store.get("telegram_chat_id")
    if not chat_id:
        return False
    with open(path, "rb") as f:
        res = _tg("sendDocument", files={"document": f}, http_timeout=90,
                  chat_id=str(chat_id), caption=caption[:1000], parse_mode="HTML")
    return bool(res and res.get("ok"))


def send_whatsapp(text: str) -> bool:
    phone, key = store.get("whatsapp_phone"), store.get("callmebot_apikey")
    if not phone or not key:
        return False
    try:
        url = (
            "https://api.callmebot.com/whatsapp.php?phone="
            f"{urllib.parse.quote(phone)}&text={urllib.parse.quote(text[:1500])}&apikey={urllib.parse.quote(key)}"
        )
        return requests.get(url, timeout=30).status_code == 200
    except Exception as exc:
        log.warning("WhatsApp error: %s", exc)
        return False


def _strip_html(text: str) -> str:
    import re

    return html.unescape(re.sub(r"<[^>]+>", "", text))


def test_telegram() -> str:
    token = store.get("telegram_bot_token")
    if not token:
        raise RuntimeError("Telegram bot token not configured")
    me = _tg("getMe", token=token)
    if not me or not me.get("ok"):
        raise RuntimeError("Invalid Telegram bot token")
    username = me["result"]["username"]
    if not store.get("telegram_chat_id"):
        return f"Bot @{username} is valid. Open Telegram and send /start to @{username} to link your chat."
    if not send("<b>akremjobhunter</b>\nTelegram channel verified."):
        raise RuntimeError("Could not deliver a message to the linked chat")
    return f"Test message delivered via @{username}."


# ---------------------------------------------------------------- update polling
CallbackHandler = Callable[[str], str]


class TelegramPoller(threading.Thread):
    """Long-polls getUpdates; links the owner's chat on /start and dispatches button callbacks."""

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
                time.sleep(20)
                continue
            offset = int(store.get("telegram_update_offset") or 0)
            # "timeout" is Telegram's long-polling wait; http_timeout must exceed it.
            res = _tg("getUpdates", token=token, http_timeout=70, offset=offset, timeout=50,
                      allowed_updates=["message", "callback_query"])
            if not res or not res.get("ok"):
                time.sleep(10)
                continue
            for upd in res.get("result", []):
                store.put("telegram_update_offset", upd["update_id"] + 1)
                try:
                    self._handle(upd)
                except Exception as exc:
                    log.exception("Update handling failed: %s", exc)

    def _handle(self, upd: dict) -> None:
        owner = str(store.get("telegram_chat_id") or "")
        if "message" in upd:
            chat_id = str(upd["message"]["chat"]["id"])
            text = (upd["message"].get("text") or "").strip()
            if text.startswith("/start"):
                if not owner:
                    store.put("telegram_chat_id", chat_id)
                    send("<b>akremjobhunter</b>\nThis chat is now linked. You will receive verified responses, "
                         "interview preparations and review requests here.")
                elif owner != chat_id:
                    _tg("sendMessage", chat_id=chat_id, text="This bot is private.")
            return
        cq = upd.get("callback_query")
        if not cq:
            return
        chat_id = str(cq["message"]["chat"]["id"])
        if chat_id != owner:
            _tg("answerCallbackQuery", callback_query_id=cq["id"], text="Not authorized")
            return
        result = self.on_callback(cq.get("data", ""))
        _tg("answerCallbackQuery", callback_query_id=cq["id"], text=result[:190])
        original = cq["message"].get("text") or ""
        _tg("editMessageText", chat_id=chat_id, message_id=cq["message"]["message_id"],
            text=f"{esc(original)}\n\nâ€” {esc(result)}"[:4000], parse_mode="HTML", disable_web_page_preview=True)
