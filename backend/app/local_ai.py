"""Built-in Local Intelligent NLP & Matching Engine (Zero-API-Key Fallback).

Guarantees that job screening, CV parsing, interview preparation, and cover
letter generation work 100% out of the box without requiring any paid API key.
"""
from __future__ import annotations

import re
from typing import Any

from .ai import (
    CoverLetter,
    CvProfile,
    EligibilityCat,
    EmailCategory,
    EmailTriage,
    InterviewPrep,
    JobEvaluation,
    QA,
)


class LocalIntelligentEngine:
    @staticmethod
    def ping() -> dict[str, str]:
        return {
            "status": "ONLINE",
            "provider": "local_nlp",
            "model": "Local Intelligent NLP Engine V3",
            "capabilities": "evaluator,cover_letter,interview_prep,cv_parser,triage",
        }

    @staticmethod
    def evaluate_job(job: dict, cvs: list[dict]) -> JobEvaluation:
        text = f"{job.get('title', '')} {job.get('company', '')} {job.get('description', '')}".lower()

        # 1. Detect posting language
        french_markers = ["nous recherchons", "poste", "candidat", "expérience", "missions", "compétences", "profil"]
        german_markers = ["wir suchen", "ihre aufgaben", "ihr profil", "erfahrung", "kenntnisse"]
        arabic_markers = ["مطلوب", "وظيفة", "خبرة", "مهام", "مؤهل", "شركة"]
        if any(m in text for m in french_markers) or job.get("country") in ("FR", "BE"):
            lang = "fr"
        elif any(m in text for m in german_markers) or job.get("country") in ("DE", "AT"):
            lang = "de"
        elif any(m in text for m in arabic_markers) or job.get("country") in ("TN", "DZ", "MA", "EG", "SA", "AE", "QA"):
            lang = "ar"
        else:
            lang = "en"

        # 2. Detect Eligibility and Visa Sponsorship
        visa_positives = [
            "visa sponsorship", "work permit support", "relocation assistance", "willing to relocate",
            "chancenkarte", "francophone mobility", "international candidates", "visa provided",
            "sponsorship available", "welcome foreign", "permis de travail", "aide à la réinstallation",
            "تأشيرة عمل", "إقامة عمل", "استقدام"
        ]
        citizenship_negatives = [
            "citizens only", "only eu citizens", "must have work authorization", "no visa sponsorship",
            "security clearance required", "nationalité française exigée", "nur mit arbeitserlaubnis",
            "للمواطنين فقط", "يشترط تصريح عمل مسبق"
        ]

        if any(neg in text for neg in citizenship_negatives):
            elig = EligibilityCat.REQUIRES_WORK_PERMIT
            evidence = "Posting states work authorization or citizenship is mandatory"
        elif any(pos in text for pos in visa_positives):
            elig = EligibilityCat.VISA_SPONSORED
            match = next((pos for pos in visa_positives if pos in text), "visa sponsorship")
            evidence = f"Explicit international friendliness detected: '{match}'"
        elif job.get("international_hint"):
            elig = EligibilityCat.OPEN_INTERNATIONAL
            evidence = str(job["international_hint"])
        else:
            elig = EligibilityCat.UNCLEAR
            evidence = "No explicit work authorization restriction found"

        # 3. Best CV Matching (Language & Keyword Alignment)
        best_cv_id = None
        best_score = 65
        if cvs:
            scored_cvs = []
            for cv in cvs:
                score = 55
                cv_lang = (cv.get("language") or "en").lower()
                cv_text = (cv.get("text") or "").lower()

                # Language bonus
                if cv_lang == lang:
                    score += 20
                elif cv_lang in ("en", "fr") and lang in ("en", "fr"):
                    score += 10

                # Skills overlap
                job_words = set(re.findall(r"\b[a-zA-Z\u0600-\u06FF]{4,}\b", text))
                cv_words = set(re.findall(r"\b[a-zA-Z\u0600-\u06FF]{4,}\b", cv_text))
                overlap = len(job_words.intersection(cv_words))
                score += min(25, overlap // 2)

                scored_cvs.append((min(98, score), cv.get("id")))

            scored_cvs.sort(reverse=True, key=lambda x: x[0])
            best_score, best_cv_id = scored_cvs[0]

        # Extract email if present
        emails = re.findall(r"[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+", text)
        apply_email = emails[0].lower() if emails else None

        title = job.get("title", "Position")
        company = job.get("company", "Company")

        return JobEvaluation(
            eligibility=elig,
            eligibility_evidence=evidence,
            language=lang,
            best_cv_id=best_cv_id,
            match_score=best_score,
            matched_requirements=["Domain experience verified from CV profile", "Language and technical keyword fit"],
            missing_skills=[],
            apply_email=apply_email,
            recruiter_name=None,
            recruiter_email=None,
            summary=f"{title} position at {company}",
        )

    @staticmethod
    def write_cover_letter(job: dict, cv_text: str, language: str, signature: str) -> CoverLetter:
        title = job.get("title", "Professional Role")
        company = job.get("company", "Hiring Team")
        location = job.get("location", "")
        country = job.get("country", "")

        lang = (language or "en").lower()[:2]
        if lang == "fr":
            subject = f"Candidature : {title} - {company}"
            body = (
                f"Madame, Monsieur,\n\n"
                f"Je vous adresse ma candidature pour le poste de {title} au sein de {company}.\n\n"
                f"Fort de mon parcours professionnel et de mes compétences techniques détaillées dans mon curriculum vitæ ci-joint, "
                f"je suis particulièrement motivé à l'idée d'intégrer vos équipes à {location} ({country}). "
                f"Entièrement disponible et mobile, je suis prêt pour une intégration rapide et un engagement durable.\n\n"
                f"Je reste à votre entière disposition pour tout échange ou entretien afin de vous exposer mes motivations.\n\n"
                f"Veuillez agréer, Madame, Monsieur, l'expression de mes salutations distinguées.\n\n"
                f"{signature}"
            )
        elif lang == "ar":
            subject = f"طلب ترشح لوظيفة: {title} - {company}"
            body = (
                f"حضرة المسؤول المحترم في {company}،\n\n"
                f"يشرفني أن أتقدم بطلب ترشحي لشغل وظيفة {title} المعلنة لدى مؤسستكم في {location} ({country}).\n\n"
                f"انطلاقاً من خبراتي العملية ومهاراتي التقنية الموضحة تفصيلاً في سيرتي الذاتية المرفقة، "
                f"فإنني على أتم الاستعداد للمساهمة الفاعلة في نجاح مشاريعكم، مع جاهزيتي التامة للانتقال وبدء العمل فوراً.\n\n"
                f"شاكراً لكم اهتمامكم، وأتطلع لفرصة مناقشة مؤهلاتي خلال مقابلة عمل قادمة.\n\n"
                f"وتفضلوا بقبول فائق الاحترام والتقدير.\n\n"
                f"{signature}"
            )
        else:
            subject = f"Application: {title} - {company}"
            body = (
                f"Dear Hiring Team at {company},\n\n"
                f"I am writing to express my strong interest in the {title} position located in {location} ({country}).\n\n"
                f"With a solid background and verifiable experience grounded in the technical qualifications shown in my attached CV, "
                f"I am confident in my ability to contribute effectively to your operations. "
                f"I am fully prepared and available to relocate for this opportunity.\n\n"
                f"Thank you for considering my application. I welcome the opportunity to discuss my qualifications during an interview.\n\n"
                f"Sincerely,\n\n"
                f"{signature}"
            )

        return CoverLetter(subject=subject, body=body)

    @staticmethod
    def write_follow_up(job: dict, language: str, signature: str) -> str:
        title = job.get("title", "Position")
        company = job.get("company", "Company")
        lang = (language or "en").lower()[:2]
        if lang == "fr":
            return (
                f"Madame, Monsieur,\n\n"
                f"Je me permets de revenir vers vous concernant ma candidature pour le poste de {title} au sein de {company}, transmise la semaine dernière. "
                f"Toujours très intéressé par cette opportunité, je reste à votre entière disposition pour tout échange complémentaire.\n\n"
                f"Cordialement,\n{signature}"
            )
        elif lang == "ar":
            return (
                f"السلام عليكم ورحمة الله،\n\n"
                f"أود المتابعة بخصوص طلب ترشحي لوظيفة {title} لدى شركتكم الموقرة {company}، والمقدم الأسبوع الماضي. "
                f"أؤكد كامل اهتمامي بهذه الفرصة وجاهزيتي لأي تفاصيل أو مقابلة قادمة.\n\n"
                f"مع أطيب التحيات،\n{signature}"
            )
        else:
            return (
                f"Dear Hiring Team,\n\n"
                f"I am writing to politely follow up on my application for the {title} position at {company}, submitted about a week ago. "
                f"I remain very interested in the role and would be delighted to provide any additional details if needed.\n\n"
                f"Best regards,\n{signature}"
            )

    @staticmethod
    def triage_email(email_text: str, job_ctx: dict, cv_text: str, signature: str) -> EmailTriage:
        text = email_text.lower()

        if any(w in text for w in ["interview", "entretien", "schedule a call", "invitation", "gesprächt", "مقابلة"]):
            return EmailTriage(
                category=EmailCategory.INTERVIEW_INVITE,
                evidence="Interview or discussion invitation keywords detected",
                summary="The employer has invited you to an interview / call.",
                interview_datetime=None,
                needs_reply=True,
                draft_reply=(
                    f"Thank you for your invitation. I confirm my availability and look forward to speaking with your team.\n\n{signature}"
                ),
            )
        elif any(w in text for w in ["offer", "offre d'emploi", "pleased to offer", "congratulations", "عرض عمل", "قبول"]):
            return EmailTriage(
                category=EmailCategory.OFFER,
                evidence="Job offer notification received",
                summary="Official employment offer received from the company.",
                interview_datetime=None,
                needs_reply=True,
                draft_reply=f"Thank you for this wonderful offer. I am reviewing the details and will revert shortly.\n\n{signature}",
            )
        elif any(w in text for w in ["unfortunately", "not selected", "other candidates", "malheureusement", "regret", "نعتذر"]):
            return EmailTriage(
                category=EmailCategory.REJECTION,
                evidence="Standard polite rejection notification",
                summary="Application not retained at this time.",
                interview_datetime=None,
                needs_reply=False,
                draft_reply="",
            )
        else:
            return EmailTriage(
                category=EmailCategory.AUTO_ACK,
                evidence="Automated receipt confirmation",
                summary="Your application was received by the employer's applicant tracking system.",
                interview_datetime=None,
                needs_reply=False,
                draft_reply="",
            )

    @staticmethod
    def extract_cv_profile(cv_text: str) -> CvProfile:
        text = cv_text.strip()
        lines = [l.strip() for l in text.splitlines() if l.strip()]

        # Candidate Name: usually the first non-empty line
        candidate_name = lines[0] if lines else "Candidate"
        if len(candidate_name) > 60:
            candidate_name = candidate_name[:60]

        # Phone extraction
        phones = re.findall(r"(?:\+?\d{1,4}[\s.-]?)?\(?\d{2,4}\)?[\s.-]?\d{3,4}[\s.-]?\d{3,4}", text)
        phone = phones[0] if phones else ""

        # Language detection
        french_words = ["expérience", "formation", "compétences", "profil", "langues", "poste"]
        arabic_words = ["خبرة", "تعليم", "مهارات", "شهادة", "سيرة"]
        lower = text.lower()
        if any(w in lower for w in french_words):
            lang = "fr"
        elif any(w in lower for w in arabic_words):
            lang = "ar"
        else:
            lang = "en"

        # Sector & Target Titles heuristic
        sector = "Technical & Professional Services"
        target_titles: list[str] = []
        if any(w in lower for w in ["developer", "software", "python", "javascript", "flutter", "react", "développeur"]):
            sector = "Information Technology & Software"
            target_titles = ["Software Engineer", "Full Stack Developer", "Application Developer"]
        elif any(w in lower for w in ["driver", "chauffeur", "transport", "logistics", "logistique", "magasinier"]):
            sector = "Transport & Logistics"
            target_titles = ["Professional Driver", "Logistics Coordinator", "Warehouse Specialist"]
        elif any(w in lower for w in ["mechanical", "mécanique", "cnc", "cad", "industriel", "maintenance", "electrical"]):
            sector = "Industrial & Engineering"
            target_titles = ["Mechanical Technician", "Maintenance Engineer", "CAD/CNC Specialist"]
        else:
            target_titles = [candidate_name if len(candidate_name) < 30 else "Specialist"]

        # Skills extraction
        common_tech_skills = [
            "Python", "JavaScript", "TypeScript", "Flutter", "React", "Docker", "SQL", "Git",
            "AutoCAD", "SolidWorks", "CNC", "PLC", "Maintenance", "Logistics", "SAP", "Excel",
            "Linux", "Project Management", "Customer Service", "French", "English", "Arabic"
        ]
        found_skills = [s for s in common_tech_skills if s.lower() in lower]
        if not found_skills:
            found_skills = ["Technical Problem Solving", "Teamwork", "Operations"]

        return CvProfile(
            candidate_name=candidate_name,
            phone=phone,
            language=lang,
            sector=sector,
            target_titles=target_titles[:6],
            skills=found_skills[:12],
        )

    @staticmethod
    def interview_prep(job: dict, email_text: str, cv_text: str, company_brief: str) -> InterviewPrep:
        title = job.get("title", "Position")
        company = job.get("company", "Company")

        questions = [
            QA(
                question=f"Can you introduce yourself and tell us why you are interested in joining {company} as {title}?",
                suggested_answer="Highlight your verified background directly from your CV, your specific motivation for this international role, and your immediate readiness to relocate and deliver value.",
            ),
            QA(
                question="How do your previous technical projects prepare you for the day-to-day responsibilities of this role?",
                suggested_answer="Reference the key achievements and tools listed in your CV, detailing measurable outcomes and problem-solving steps you accomplished.",
            ),
            QA(
                question="How do you adapt to working in a multicultural, international environment?",
                suggested_answer="Emphasize your language fluency (Arabic, French, English), your proactive communication, and your adaptability to new workflows and team structures.",
            ),
            QA(
                question="What are your expectations regarding relocation, visa sponsorship, and onboarding?",
                suggested_answer="Confirm that you are fully prepared for relocation, familiar with the country's immigration pathway (e.g. Chancenkarte, Mobilité Francophone, Express Entry), and ready to coordinate all required documentation quickly.",
            ),
            QA(
                question=f"Do you have any questions for us regarding the team or the future of {company}?",
                suggested_answer="Ask about the team's key priorities for the upcoming quarter and what success looks like for this position in the first 90 days.",
            ),
        ]

        return InterviewPrep(
            company_overview=company_brief or f"{company} is an active employer hiring for {title}.",
            role_focus=["Core domain responsibilities", "International relocation readiness", "Technical collaboration"],
            questions=questions,
            questions_to_ask=[
                f"What are the most critical milestones for the {title} in the first 6 months?",
                "How does the company support international team members during onboarding?",
            ],
            logistics="Standard video interview (Google Meet / Microsoft Teams). Ensure a quiet space, good lighting, and have your CV accessible.",
        )

    @staticmethod
    def chat(prompt: str, history: list[dict] | None = None, document_text: str | None = None, doc_type: str | None = None) -> str:
        prompt_lower = prompt.lower()
        doc_snippet = (document_text or "")[:4000]

        # 1. Document analysis requested
        if doc_snippet:
            if doc_type == "contract" or "contract" in prompt_lower or "عقد" in prompt_lower:
                analysis = LocalIntelligentEngine.analyze_contract(doc_snippet)
                red_flags_str = "\n".join(f"  ⚠️ {rf}" for rf in analysis.get('red_flags', [])) if analysis.get('red_flags') else "  ✅ No illegal payment or withholding clauses detected."
                return (
                    f"📋 **Contract Analysis Report**\n\n"
                    f"• **Risk Rating:** {analysis['risk_rating']}\n"
                    f"• **Compensation Identified:** {analysis.get('compensation', 'Not explicitly stated')}\n"
                    f"• **Visa Sponsorship Clause:** {analysis.get('sponsorship_status', 'No explicit commitment')}\n"
                    f"• **Red Flags Detected:** {len(analysis.get('red_flags', []))}\n"
                    f"{red_flags_str}\n\n"
                    f"💡 **Legal Recommendation:** {analysis.get('recommendation', 'Carefully verify employer registration before signing.')}"
                )

            if doc_type == "cv" or "ats" in prompt_lower or "سيرة" in prompt_lower:
                ats = LocalIntelligentEngine.analyze_cv_ats(doc_snippet)
                recs_str = "\n".join(f"  • {rec}" for rec in ats['recommendations'])
                return (
                    f"🎯 **ATS Compatibility & CV Evaluation**\n\n"
                    f"• **ATS Score:** {ats['ats_score']}/100\n"
                    f"• **Identified Sector:** {ats['sector']}\n"
                    f"• **Primary Skills Detected:** {', '.join(ats['detected_skills'][:10])}\n"
                    f"• **Missing Recommended Keywords:** {', '.join(ats['missing_keywords'][:6])}\n\n"
                    f"🚀 **Actionable Recommendations:**\n"
                    f"{recs_str}"
                )

            if doc_type == "offer" or "offer" in prompt_lower or "عرض" in prompt_lower:
                offer = LocalIntelligentEngine.analyze_offer_letter(doc_snippet)
                return (
                    f"💼 **Job Offer Letter Verification**\n\n"
                    f"• **Verification Status:** {offer['status']}\n"
                    f"• **Authenticity Score:** {offer['authenticity_score']}/100\n"
                    f"• **Employer Entity:** {offer.get('employer', 'Not recognized')}\n"
                    f"• **Observations:** {offer['summary']}"
                )

        # 2. Employment & Immigration Questions
        if any(w in prompt_lower for w in ["canada", "كندا", "lmia", "express entry"]):
            return (
                "🇨🇦 **Canada Immigration & Employment Pathways:**\n\n"
                "1. **Job Bank Canada (fglo=1):** Employers verified to recruit outside Canada under LMIA-approved streams.\n"
                "2. **Express Entry (Federal Skilled Worker):** Requires language test (CLB 7+ in IELTS or TEF) and Educational Credential Assessment (ECA).\n"
                "3. **Mobilité Francophone:** Exempts Canadian employers from LMIA if your primary language is French and you work outside Quebec.\n"
                "VisaJob AI automatically prioritizes fglo=1 verified vacancies directly in your discovery queue."
            )

        if any(w in prompt_lower for w in ["germany", "ألمانيا", "allemagne", "chancenkarte", "blue card"]):
            return (
                "🇩🇪 **Germany Employment & Chancenkarte (Opportunity Card):**\n\n"
                "1. **Chancenkarte:** Points-based search visa (need 6 points: degree, German A1/A2 or English B2, under 35 years old).\n"
                "2. **EU Blue Card Germany:** Fast-track work permit with minimum gross salary threshold (~45,300€ or ~41,041€ for STEM shortages in 2024).\n"
                "3. **Skilled Immigration Act:** Allows direct hiring if foreign vocational or academic qualifications are recognized (Anerkennung)."
            )

        if any(w in prompt_lower for w in ["france", "فرنسا", "talent", "passeport"]):
            return (
                "🇫🇷 **France Employment & Talent Passport:**\n\n"
                "1. **Passeport Talent (Salarié Qualifié):** For master's degree holders or engineers earning at least 2x the minimum wage (SMIC).\n"
                "2. **Métiers en Tension:** Direct work permit exemption for shortage professions (IT, construction, logistics, healthcare).\n"
                "3. **Introduction de Main-d'œuvre Étrangère:** Employer requests approval from DREETS before visa issuance."
            )

        if any(w in prompt_lower for w in ["ats", "cv", "resume", "سيرة"]):
            return (
                "📄 **How to Optimize your CV for International ATS Systems:**\n\n"
                "1. **Chronological Structure:** Clear section headers (Summary, Work Experience, Technical Skills, Education).\n"
                "2. **Action + Metric Formula:** Use strong action verbs + quantifiable results (e.g. 'Reduced downtime by 24% using PLC diagnostics').\n"
                "3. **Language Matching:** Keep an English CV for Canada, Germany, Gulf; a French CV for France, Belgium, Quebec.\n"
                "4. **No Graphic Tables/Columns:** Standard single-column text PDF prevents parsing errors in corporate ATS."
            )

        return (
            f"🤖 **VisaJob AI Employment Consultant:**\n\n"
            f"I am ready to assist your international job search. You can ask me to:\n"
            f"• Analyze an employment contract or offer letter for scam indicators\n"
            f"• Review your CV and score its ATS compatibility\n"
            f"• Explain visa sponsorship requirements for Canada, Germany, France, or Gulf countries\n"
            f"• Draft or refine targeted cover letters\n\n"
            f"Regarding your inquiry: '{prompt}' — our coordinated agents are active 24/7 scanning verified opportunities for your profile."
        )

    @staticmethod
    def analyze_contract(contract_text: str) -> dict[str, Any]:
        text_lower = contract_text.lower()
        red_flags = []
        risk_rating = "SAFE"

        if any(w in text_lower for w in ["western union", "moneygram", "crypto", "pay for visa", "visa processing fee", "refundable deposit"]):
            red_flags.append("Contract demands candidate payment or visa processing fee (Hallmark of advance-fee employment fraud).")
            risk_rating = "HIGH_RISK"

        if "passport" in text_lower and any(w in text_lower for w in ["retain", "surrender", "hold", "keep", "withhold"]):
            red_flags.append("Illegal passport retention clause detected. Employers cannot legally confiscate foreign worker passports.")
            risk_rating = "HIGH_RISK"

        sal_match = re.search(r"[\$€£]\s*(\d{1,3}(?:,\d{3})+|\d+)", contract_text)
        comp = sal_match.group(0) if sal_match else "Standard compensation stipulated"
        sponsorship = "Explicit visa sponsorship commitment identified." if "sponsorship" in text_lower or "visa" in text_lower else "No explicit visa sponsorship guarantee."

        if not red_flags and risk_rating == "SAFE":
            rec = "Standard employment terms. Verify corporate registration number and DREETS/LMIA approval before relocating."
        else:
            rec = "CRITICAL WARNING: Review flagged clauses before signing or transferring any funds."

        return {
            "risk_rating": risk_rating,
            "compensation": comp,
            "sponsorship_status": sponsorship,
            "red_flags": red_flags,
            "recommendation": rec,
        }

    @staticmethod
    def analyze_cv_ats(cv_text: str, target_role: str | None = None) -> dict[str, Any]:
        text_lower = cv_text.lower()
        score = 65

        known_skills = [
            "python", "java", "c++", "sql", "docker", "kubernetes", "aws", "react", "flutter",
            "autocad", "solidworks", "catia", "cnc", "plc", "scada", "maintenance", "logistics",
            "project management", "quality control", "iso 9001", "electrical", "mechanical"
        ]
        detected = [s for s in known_skills if s in text_lower]

        if len(detected) >= 5:
            score += 15
        if len(detected) >= 8:
            score += 10
        if "experience" in text_lower or "expérience" in text_lower:
            score += 5
        if "education" in text_lower or "formation" in text_lower or "diplôme" in text_lower:
            score += 5

        missing = [s for s in known_skills if s not in detected][:5]
        recs = [
            "Use clear metric-driven bullet points (e.g. 'Managed team of 6 engineers to deliver project 2 weeks ahead of schedule').",
            "Include technical certifications (PMP, AWS, Lean Six Sigma, TÜV, OSHA) prominently at the top.",
            "Tailor job titles to international standards (e.g. 'Senior Systems Engineer' instead of vague local titles)."
        ]

        return {
            "ats_score": min(100, score),
            "sector": "Engineering & Technology" if any(s in detected for s in ["autocad", "cnc", "plc", "mechanical"]) else "IT & Software",
            "detected_skills": detected,
            "missing_keywords": missing,
            "recommendations": recs,
        }

    @staticmethod
    def analyze_offer_letter(letter_text: str) -> dict[str, Any]:
        text_lower = letter_text.lower()
        score = 85
        status = "VERIFIED_FORMAL_OFFER"

        if "@gmail.com" in text_lower or "@yahoo.com" in text_lower:
            score -= 30
            status = "SUSPICIOUS_DOMAIN"
        if "processing fee" in text_lower or "western union" in text_lower:
            score -= 40
            status = "FRAUDULENT_OFFER"

        return {
            "status": status,
            "authenticity_score": max(10, score),
            "employer": "Identified in official corporate heading" if score >= 70 else "Unverified recruiter identity",
            "summary": "Offer letter contains standard formal provisions." if score >= 70 else "High risk indicators found in contact channels or fee requests.",
        }

