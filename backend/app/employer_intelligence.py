"""VisaJob AI — Employer Rating & Intelligence System.

Aggregates enterprise data, reputation metrics, salary competitiveness,
interview difficulty, and international visa sponsorship track records
to rate employers (0-100) across standard international categories.
"""
from __future__ import annotations

import re
from typing import Any

# Verified multinational or well-known sponsors with top rating baseline
TIER_1_SPONSORS = {
    "google", "amazon", "microsoft", "apple", "meta", "sap", "siemens",
    "bosch", "asml", "booking.com", "delivery hero", "zalando", "shopify",
    "rbc", "td bank", "scotiabank", "airbus", "totalenergies", "schneider electric",
    "aramco", "sabic", "adnoc", "neom", "emirates", "qatar airways"
}

KNOWN_PUBLIC_PORTALS = {
    "jobbank": {"base_score": 88, "sponsorship_reputation": "High (Official Canadian Federal Bank)"},
    "eures": {"base_score": 86, "sponsorship_reputation": "High (European Cross-Border Mobility Portal)"},
    "arbeitnow": {"base_score": 82, "sponsorship_reputation": "Good (EU Visa Sponsorship Friendly)"},
    "remote_portals": {"base_score": 80, "sponsorship_reputation": "Global B2B / Worldwide Contractor Friendly"},
    "adzuna": {"base_score": 75, "sponsorship_reputation": "Moderate (Aggregated Enterprise Postings)"},
    "jobspy": {"base_score": 78, "sponsorship_reputation": "Standard (Direct LinkedIn/Indeed Sourced)"},
}


class EmployerIntelligenceSystem:
    @staticmethod
    def rate_employer(
        company_name: str,
        country: str,
        source: str = "",
        job_description: str = "",
        eligibility: str | None = None,
    ) -> dict[str, Any]:
        """Calculates 0-100 employer intelligence score, category, and breakdowns."""
        name_clean = (company_name or "Enterprise").strip()
        lower_name = name_clean.lower()
        desc_lower = (job_description or "").lower()

        # 1. Base Score from Source and Company profile
        portal_info = KNOWN_PUBLIC_PORTALS.get(source.lower(), {"base_score": 72, "sponsorship_reputation": "Standard"})
        score = portal_info["base_score"]

        # Check for Tier-1 recognized global employers
        if any(t1 in lower_name for t1 in TIER_1_SPONSORS):
            score = max(score, 94)
            reputation = "Top-Tier Multinational Enterprise"
        elif len(name_clean) > 3 and not re.search(r"\b(agency|recruitment|consulting|temporary)\b", lower_name):
            reputation = "Direct Corporate Employer"
            score += 4
        else:
            reputation = "Staffing / Recruitment Agency"

        # 2. Visa Sponsorship Friendliness
        if eligibility == "VISA_SPONSORED" or "visa sponsorship" in desc_lower or "relocation" in desc_lower:
            score += 8
            sponsorship_friendliness = "Very High (Documented Visa Sponsorship / Relocation Support)"
        elif eligibility == "OPEN_INTERNATIONAL" or "international candidates" in desc_lower or "fglo=1" in desc_lower:
            score += 5
            sponsorship_friendliness = "High (Welcomes Foreign & International Applicants)"
        elif eligibility == "REQUIRES_WORK_PERMIT":
            score -= 15
            sponsorship_friendliness = "Low (Strict Existing Work Authorization Required)"
        else:
            sponsorship_friendliness = portal_info["sponsorship_reputation"]

        # 3. Salary Competitiveness
        salary_indicators = [
            r"\bcompetitive\s*salary\b", r"\beuro\b", r"\bchf\b", r"\bcad\b", r"\busd\b",
            r"\bbonus\b", r"\b401k\b", r"\bpension\b", r"\bhealth\s*insurance\b",
            r"\bmutuelle\b", r"\brémunération\s*attractive\b", r"\brattrapage\b"
        ]
        has_benefits = sum(bool(re.search(pat, desc_lower)) for pat in salary_indicators)
        if has_benefits >= 3:
            salary_competitiveness = "Above Market Average (Comprehensive Benefits Package)"
            score += 4
        elif has_benefits >= 1:
            salary_competitiveness = "Standard Market Rate"
        else:
            salary_competitiveness = "Standard Compensation"

        # 4. Interview Experience Prediction
        country_code = (country or "").upper()
        if country_code in ("DE", "NL", "CH", "AT"):
            interview_experience = "Structured (Screening Call ➔ Technical Task ➔ Team Alignment)"
        elif country_code in ("CA", "US"):
            interview_experience = "Multi-Stage (Behavioral Interview ➔ Domain Assessment ➔ Manager Review)"
        elif country_code in ("SA", "AE", "QA", "KW"):
            interview_experience = "Fast-Track (Direct Video Interview ➔ Visa Document Verification ➔ Offer)"
        elif country_code in ("FR", "BE"):
            interview_experience = "HR Screening ➔ Operational Interview ➔ Director Validation"
        else:
            interview_experience = "Standard 2-Round Video Conference Interview"

        final_score = max(20, min(98, score))

        # Categorization
        if final_score >= 85:
            category = "Excellent"
            cat_color = "#10B981"  # Emerald
            cat_ar = "ممتاز (موثوق ومثبت)"
            cat_fr = "Excellent (Très fiable)"
        elif final_score >= 70:
            category = "Good"
            cat_color = "#38BDF8"  # Sky
            cat_ar = "جيد (موصى به)"
            cat_fr = "Bon (Recommandé)"
        elif final_score >= 50:
            category = "Average"
            cat_color = "#F59E0B"  # Amber
            cat_ar = "متوسط (اعتيادي)"
            cat_fr = "Moyen (Standard)"
        else:
            category = "Risky"
            cat_color = "#EF4444"  # Red
            cat_ar = "محفوف بالمخاطر (تدقيق إضافي)"
            cat_fr = "Risqué (Vérification requise)"

        return {
            "employer_score": final_score,
            "category": category,
            "category_label": {
                "en": category,
                "ar": cat_ar,
                "fr": cat_fr,
            },
            "category_color": cat_color,
            "company_name": name_clean,
            "company_reputation": reputation,
            "salary_competitiveness": salary_competitiveness,
            "interview_experience": interview_experience,
            "visa_sponsorship_friendliness": sponsorship_friendliness,
        }
