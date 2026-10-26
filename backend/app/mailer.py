"""Gmail SMTP sending and IMAP reading (read-only peek: never marks messages as read)."""
from __future__ import annotations

import email
import imaplib
import logging
import os
import smtplib
import ssl
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from email.header import decode_header, make_header
from email.message import EmailMessage
from email.utils import getaddresses, make_msgid, parsedate_to_datetime

from bs4 import BeautifulSoup

from . import settings_store as store

log = logging.getLogger("mail")

IMAP_HOST = "imap.gmail.com"
SMTP_HOST = "smtp.gmail.com"


class MailNotConfigured(RuntimeError):
    pass


def _creds() -> tuple[str, str]:
    addr = (store.get("gmail_address") or "").strip()
    pwd = (store.get("gmail_app_password") or "").replace(" ", "")
    if not addr or not pwd:
        raise MailNotConfigured("Gmail address / app password not configured")
    return addr, pwd


def send_email(
    to: str,
    subject: str,
    body: str,
    attachment_path: str | None = None,
    attachment_name: str | None = None,
    cc: str | None = None,
    in_reply_to: str | None = None,
) -> str:
    """Send a plain-text email. Returns the Message-ID. Raises on failure."""
    addr, pwd = _creds()
    name = store.get("full_name") or ""
    msg = EmailMessage()
    msg["From"] = f"{name} <{addr}>" if name else addr
    msg["To"] = to
    if cc:
        msg["Cc"] = cc
    msg["Subject"] = subject
    msg_id = make_msgid(domain=addr.split("@")[-1])
    msg["Message-ID"] = msg_id
    if in_reply_to:
        msg["In-Reply-To"] = in_reply_to
        msg["References"] = in_reply_to
    msg.set_content(body)
    if attachment_path and os.path.exists(attachment_path):
        with open(attachment_path, "rb") as f:
            msg.add_attachment(
                f.read(), maintype="application", subtype="pdf",
                filename=attachment_name or os.path.basename(attachment_path),
            )
    with smtplib.SMTP_SSL(SMTP_HOST, 465, context=ssl.create_default_context(), timeout=60) as server:
        server.login(addr, pwd)
        server.send_message(msg)
    return msg_id


def test_connection() -> None:
    addr, pwd = _creds()
    with imaplib.IMAP4_SSL(IMAP_HOST, timeout=30) as m:
        m.login(addr, pwd)
    with smtplib.SMTP_SSL(SMTP_HOST, 465, context=ssl.create_default_context(), timeout=30) as s:
        s.login(addr, pwd)


@dataclass
class InboundMail:
    uid: int
    from_addr: str
    from_name: str
    subject: str
    body: str
    message_id: str | None
    references: list[str] = field(default_factory=list)
    date: datetime | None = None


def _decode(value: str | None) -> str:
    if not value:
        return ""
    try:
        return str(make_header(decode_header(value)))
    except Exception:
        return value


def _body_text(msg: email.message.Message) -> str:
    plain, html = [], []
    for part in msg.walk() if msg.is_multipart() else [msg]:
        if part.get_content_maintype() == "multipart" or part.get("Content-Disposition", "").startswith("attachment"):
            continue
        payload = part.get_payload(decode=True)
        if not payload:
            continue
        text = payload.decode(part.get_content_charset() or "utf-8", errors="replace")
        (plain if part.get_content_type() == "text/plain" else html if part.get_content_type() == "text/html" else []).append(text)
    if plain:
        return "\n".join(plain)
    if html:
        return BeautifulSoup("\n".join(html), "html.parser").get_text("\n")
    return ""


def fetch_new(last_uid: int, max_messages: int = 80) -> list[InboundMail]:
    """Fetch messages with UID > last_uid from INBOX using BODY.PEEK (keeps them unread)."""
    addr, pwd = _creds()
    out: list[InboundMail] = []
    with imaplib.IMAP4_SSL(IMAP_HOST, timeout=60) as m:
        m.login(addr, pwd)
        m.select("INBOX", readonly=True)
        if last_uid <= 0:
            since = (datetime.now(timezone.utc) - timedelta(days=7)).strftime("%d-%b-%Y")
            typ, data = m.uid("search", None, f"(SINCE {since})")
        else:
            typ, data = m.uid("search", None, f"(UID {last_uid + 1}:*)")
        if typ != "OK" or not data or not data[0]:
            return out
        uids = [int(u) for u in data[0].split() if int(u) > last_uid][-max_messages:]
        for uid in uids:
            typ, msg_data = m.uid("fetch", str(uid), "(BODY.PEEK[])")
            if typ != "OK" or not msg_data or not isinstance(msg_data[0], tuple):
                continue
            msg = email.message_from_bytes(msg_data[0][1])
            name, from_addr = (getaddresses([msg.get("From", "")]) or [("", "")])[0]
            refs = " ".join(filter(None, [msg.get("In-Reply-To"), msg.get("References")])).split()
            try:
                date = parsedate_to_datetime(msg.get("Date")) if msg.get("Date") else None
            except Exception:
                date = None
            out.append(InboundMail(
                uid=uid, from_addr=from_addr.lower(), from_name=_decode(name), subject=_decode(msg.get("Subject")),
                body=_body_text(msg), message_id=msg.get("Message-ID"), references=refs, date=date,
            ))
    return out
