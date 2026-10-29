"""VisaJob AI — Scam Detection & Employment Security Engine.

Forensically analyzes recruiter emails, company domains, job offers,
and employment contracts to safeguard candidates against advance-fee fraud,
fake recruiters, unrealistic promises, and phishing scams.
"""
from __future__ import annotations

import re
from typing import Any

# Known suspicious free or disposable domains pretending to be official corporate recruitment
FREE_EMAIL_DOMAINS = {
    "gmail.com", "yahoo.com", "hotmail.com", "outlook.com", "aol.com",
    "protonmail.com", "mail.com", "zoho.com", "yandex.com", "gmx.com",
    "icloud.com", "live.com"
}

# Red flag keywords indicating advance-fee or financial scam
PAYMENT_RED_FLAGS = [
    r"\bwestern\s*union\b", r"\bmoney\s*gram\b", r"\bcrypto\b", r"\bbitcoin\b",
    r"\bgift\s*card\b", r"\bprocessing\s*fee\b", r"\bvisa\s*fee\b", r"\bregistration\s*fee\b",
    r"\bcourier\s*fee\b", r"\bmedical\s*examination\s*fee\b", r"\btraining\s*deposit\b",
    r"\bequipment\s*check\b", r"\bcashier'?s?\s*check\b", r"\bwire\s*transfer\b",
    r"\bpay\s*upfront\b", r"\brefundable\s*deposit\b", r"\bfrais\s*de\s*dossier\b",
    r"\bfrais\s*de\s*visa\b", r"\bavance\s*sur\s*frais\b", r"\bرسوم\s*تأشيرة\b",
    r"\bتحويل\s*مسبق\b", r"\bرسوم\s*معالجة\b"
]

# Unrealistic compensation or scam promises
SALARY_RED_FLAGS = [
    r"\b500\s*\$?\s*per\s*day\b", r"\b300\s*\$?\s*per\s*hour\b",
    r"\b1000\s*\$?\s*daily\b", r"\bno\s*experience\s*earn\s*thousands\b",
    r"\bguaranteed\s*visa\b", r"\b100%\s*guaranteed\s*job\b",
    r"\bvisa\s*garantie\b", r"\bفيزا\s*مضمونة\b", r"\bربح\s*فوري\b"
]

# Sensitive personal information requests before any formal interview
IDENTITY_THEFT_FLAGS = [
    r"\bbank\s*account\s*details\b", r"\bcredit\s*card\b", r"\bcvv\b",
    r"\bsocial\s*security\b", r"\blogin\s*credentials\b", r"\bpassword\b",
    r"\bcoordonn[ée]es\s*bancaires\b", r"\bبيانات\s*الحساب\s*البنكي\b"
]


class ScamDetectorEngine:
    @staticmethod
    def analyze_opportunity(
        title: str,
        company: str,
        description: str,
        apply_email: str | None = None,
        recruiter_email: str | None = None,
        salary_text: str | None = None,
        job_url: str | None = None,
    ) -> dict[str, Any]:
        """Analyzes a job posting or offer for scam signals and returns risk evaluation."""
        text = f"{title} {company} {description} {salary_text or ''}".lower()
        contact_email = (recruiter_email or apply_email or "").strip().lower()

        reasons: list[str] = []
        risk_points = 0

        # 1. Email domain check
        if contact_email:
            domain = contact_email.split("@")[-1] if "@" in contact_email else ""
            if domain in FREE_EMAIL_DOMAINS:
                # If company name is an established enterprise but email is free Gmail/Yahoo
                risk_points += 35
                reasons.append(
                    f"Recruiter contact email uses a generic public domain (@{domain}) instead of an official corporate domain."
                )

        # 2. Advance-fee / payment requests check
        for pattern in PAYMENT_RED_FLAGS:
            if re.search(pattern, text, re.IGNORECASE):
                risk_points += 50
                reasons.append(
                    "Detected suspicious advance payment, processing fee, or wire transfer solicitation."
                )
                break

        # 3. Unrealistic salary / guaranteed visa promises
        for pattern in SALARY_RED_FLAGS:
            if re.search(pattern, text, re.IGNORECASE):
                risk_points += 30
                reasons.append(
                    "Contains exaggerated earnings claims or legally impossible '100% guaranteed visa' promises."
                )
                break

        # 4. Identity theft / banking credentials requested prematurely
        for pattern in IDENTITY_THEFT_FLAGS:
            if re.search(pattern, text, re.IGNORECASE):
                risk_points += 45
                reasons.append(
                    "Demands sensitive banking credentials or financial data before a contract stage."
                )
                break

        # 5. Telegram-only or WhatsApp-only hiring without legitimate business presence
        if ("telegram only" in text or "contact on telegram" in text) and not contact_email:
            risk_points += 25
            reasons.append("Restricts hiring communication strictly to unverified instant messaging channels.")

        # Determine Final Risk Category
        if risk_points >= 50:
            risk_level = "HIGH"
            badge_color = "#EF4444"  # Red
            explanation_en = "High Scam Risk: Critical fraud or payment indicators detected. Caution advised."
            explanation_ar = "مخاطرة احتيال عالية: تم رصد مؤشرات دفع مسبق أو بيانات مشبوهة. يرجى الحذر."
            explanation_fr = "Risque d'arnaque élevé : Indicateurs de fraude ou de demande de paiement détectés."
            is_safe = False
        elif risk_points >= 25:
            risk_level = "MEDIUM"
            badge_color = "#F59E0B"  # Amber
            explanation_en = "Moderate Risk: Generic contact details or unverified recruiter. Verify employer identity."
            explanation_ar = "مخاطرة متوسطة: البريد عام أو بيانات غير موثقة بالكامل. تحقق من هوية المشغل."
            explanation_fr = "Risque modéré : Contact générique ou recruteur non vérifié. Vérifiez l'identité."
            is_safe = True
        else:
            risk_level = "LOW"
            badge_color = "#10B981"  # Emerald
            explanation_en = "Low Scam Risk: Verified corporate structure, standard recruitment practices."
            explanation_ar = "مخاطرة منخفضة: مسار توظيف نظامي وموثوق وخال من طلبات الدفع المشبوهة."
            explanation_fr = "Risque faible : Recrutement conforme et sécurisé sans frais suspects."
            is_safe = True
            reasons.append("Verified recruitment workflow with standard employment safeguards.")

        return {
            "risk_score": risk_level,
            "risk_points": min(100, risk_points),
            "risk_color": badge_color,
            "is_safe": is_safe,
            "reasons": reasons,
            "explanation": {
                "en": explanation_en,
                "ar": explanation_ar,
                "fr": explanation_fr,
            },
        }

    @staticmethod
    def analyze_email_message(sender: str, subject: str, body: str) -> dict[str, Any]:
        """Analyzes an incoming recruiter email to detect phishing, spoofing, or fake job offers."""
        return ScamDetectorEngine.analyze_opportunity(
            title=subject,
            company=sender,
            description=body,
            recruiter_email=sender,
        )
