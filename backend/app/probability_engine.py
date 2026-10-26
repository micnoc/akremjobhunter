"""Offer Probability Engine: Evaluates the statistical likelihood (0-100%) of securing an offer/interview.

Factors:
1. Technical and Domain Match (40% weight)
2. Visa & Immigration Pathway Feasibility (30% weight)
3. Language Alignment (15% weight)
4. Employer Sponsor Track Record & Recruiter Direct Contact (15% weight)
"""
from __future__ import annotations

import re
from typing import Any

# Immigration Pathway Policies by Country
COUNTRY_IMMIGRATION_INDEX = {
    # Germany: Chancenkarte / Opportunity card, Fachkräfteeinwanderungsgesetz, EU Blue Card
    "DE": {"score": 88, "pathway": "Chancenkarte / Skilled Immigration Act (Fast-track visa for Arab/North-African professionals)"},
    # Canada: Express Entry / LMIA / Francophone Mobility (greatly benefits bilingual Tunisian/Arab talent)
    "CA": {"score": 85, "pathway": "Francophone Mobility Program / Global Talent Stream / LMIA Exemption"},
    # France: Passeport Talent / Salarié qualifié
    "FR": {"score": 82, "pathway": "Passeport Talent (Salarié qualifié / Métiers en tension)"},
    # Belgium: Single Permit (Permis unique)
    "BE": {"score": 78, "pathway": "Single Permit (Permis Unique Région Flamande/Wallonne/Bruxelles)"},
    # Netherlands: Highly Skilled Migrant (Kennismigrant)
    "NL": {"score": 80, "pathway": "Highly Skilled Migrant Scheme (Fast-track 30% ruling)"},
    # Luxembourg: European Financial & Logistics Hub
    "LU": {"score": 80, "pathway": "Salarié Hautement Qualifié (EU Blue Card)"},
    # Austria: Red-White-Red Card
    "AT": {"score": 75, "pathway": "Rot-Weiß-Rot-Karte (Shortage occupations list)"},
    # Remote worldwide
    "REMOTE": {"score": 85, "pathway": "Direct Contractor / Global B2B Agreement (No visa needed)"},
    # Default fallback
    "DEFAULT": {"score": 65, "pathway": "Standard National Work Permit & Embassy Visa Process"},
}


class OfferProbabilityEngine:
    @staticmethod
    def calculate(
        match_score: int | None,
        eligibility: str | None,
        country: str,
        job_language: str | None,
        cv_language: str | None,
        has_direct_email: bool = False,
        missing_skills_count: int = 0,
        candidate_country_origin: str = "TN",  # Tunisia or any Arab country
    ) -> dict[str, Any]:
        """Calculates total probability (0-100), breakdown scores, and practical advice."""
        # 1. Technical / CV Match Score (0 - 40 points)
        base_match = max(0, min(int(match_score or 50), 100))
        score_technical = round(base_match * 0.40, 1)

        # 2. Visa & Policy Pathway Score (0 - 30 points)
        country_code = (country or "").upper()
        country_info = COUNTRY_IMMIGRATION_INDEX.get(country_code, COUNTRY_IMMIGRATION_INDEX["DEFAULT"])
        policy_base = country_info["score"]

        # Eligibility boost/penalty
        if eligibility == "VISA_SPONSORED":
            policy_base = min(100, policy_base + 12)
        elif eligibility == "OPEN_INTERNATIONAL":
            policy_base = min(100, policy_base + 8)
        elif eligibility == "REQUIRES_WORK_PERMIT":
            policy_base = max(20, policy_base - 35)
        elif eligibility == "GOVERNMENT_OR_CITIZENSHIP":
            policy_base = 5

        score_visa = round(policy_base * 0.30, 1)

        # 3. Language Alignment Score (0 - 15 points)
        job_lang = (job_language or "en").lower()[:2]
        cv_lang = (cv_language or "en").lower()[:2]
        if job_lang == cv_lang:
            score_language = 15.0
        elif job_lang in ("en", "fr") and cv_lang in ("en", "fr"):
            score_language = 12.0
        else:
            score_language = 8.0

        # 4. Employer Direct Outreach Score (0 - 15 points)
        score_employer = 10.0
        if has_direct_email:
            score_employer += 5.0
        if missing_skills_count > 3:
            score_employer = max(3.0, score_employer - 4.0)

        total = round(score_technical + score_visa + score_language + score_employer)
        total = max(5, min(98, total))

        # Probability Category
        if total >= 80:
            tier = "VERY_HIGH"
            tier_label_ar = "احتمال قبول مرتفع جداً (ممتاز)"
            tier_label_fr = "Probabilité très élevée"
            tier_label_en = "Very High Probability"
            badge_color = "#10B981"  # Emerald
        elif total >= 65:
            tier = "HIGH"
            tier_label_ar = "احتمال قبول واعد (جيد)"
            tier_label_fr = "Probabilité prometteuse"
            tier_label_en = "Promising Probability"
            badge_color = "#38BDF8"  # Cyan
        elif total >= 45:
            tier = "MODERATE"
            tier_label_ar = "احتمال قبول متوسط (تنافسي)"
            tier_label_fr = "Probabilité modérée"
            tier_label_en = "Moderate Probability"
            badge_color = "#F59E0B"  # Amber
        else:
            tier = "LOW"
            tier_label_ar = "احتمال قبول منخفض (شروط مشددة)"
            tier_label_fr = "Faible probabilité"
            tier_label_en = "Low Probability"
            badge_color = "#EF4444"  # Red

        # Optimization tips
        tips_ar = []
        if score_technical < 28:
            tips_ar.append("قم بتحديث سيرتك الذاتية وإضافة الكلمات المفتاحية المطابقة للوظيفة لرفع النسبة.")
        if not has_direct_email:
            tips_ar.append("يُفضل متابعة التقديم عبر LinkedIn أو بوابة الشركة الرسمية مباشرة.")
        if job_lang == "fr" and cv_lang != "fr":
            tips_ar.append("الوظيفة بالفرنسية: قم بتفعيل السيرة الذاتية بالفرنسية للحصول على أولوية القبول.")

        return {
            "total_probability": total,
            "tier": tier,
            "labels": {
                "ar": tier_label_ar,
                "fr": tier_label_fr,
                "en": tier_label_en,
            },
            "badge_color": badge_color,
            "breakdown": {
                "technical_match": score_technical,
                "visa_pathway": score_visa,
                "language_fit": score_language,
                "direct_outreach": score_employer,
            },
            "immigration_pathway": country_info["pathway"],
            "recommendations": tips_ar,
        }
