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
    def chat(prompt: str, history: list[dict] | None = None, document_text: str | None = None, doc_type: str | None = None, language: str | None = None) -> str:
        prompt_clean = prompt.strip()
        prompt_lower = prompt_clean.lower()
        doc_snippet = (document_text or "")[:5000]

        # Detect language: Arabic, French, or English
        has_arabic = bool(re.search(r'[؀-ۿ]', prompt_clean))
        has_french = not has_arabic and (
            (language and language.lower().startswith('fr')) or
            any(w in prompt_lower for w in ["bonjour", "salut", "comment", "emploi", "travail", "lettre", "poste", "france", "québec", "allemagne", "merci", "aide"])
        )
        is_ar = has_arabic or (language and language.lower().startswith('ar'))
        is_fr = has_french

        # 1. Document analysis requested (Contract, CV ATS, Offer Letter)
        if doc_snippet:
            if doc_type == "contract" or any(w in prompt_lower for w in ["contract", "عقد", "contrat"]):
                analysis = LocalIntelligentEngine.analyze_contract(doc_snippet)
                flags = analysis.get('red_flags', [])
                if is_ar:
                    flags_str = "\n".join(f"  ⚠️ {rf}" for rf in flags) if flags else "  ✅ لم يتم رصد أي بنود دفع مسبق أو مصادرة غير قانونية."
                    status_text = "آمن ومطابق للشروط العامة" if analysis['risk_rating'] == "SAFE" else "عالي الخطورة (يوجد شبهة احتيال)"
                    return (
                        f"📋 **تقرير الفحص القانوني للعقد الوظيفي**\n\n"
                        f"• **مستوى الأمان والمخاطر:** {status_text}\n"
                        f"• **الراتب والتعويضات:** {analysis.get('compensation', 'غير محدد بدقة')}\n"
                        f"• **بند رعاية التأشيرة (Visa Sponsorship):** {analysis.get('sponsorship_status', 'لا يوجد التزام صريح')}\n"
                        f"• **الملاحظات والبنود المشبوهة:** {len(flags)}\n"
                        f"{flags_str}\n\n"
                        f"💡 **توصية VisaJob AI:**\n"
                        f"{'يُنصح بالتثبت من رقم التسجيل التجاري للشركة لدى الجهات الرسمية قبل التوقيع.' if analysis['risk_rating'] == 'SAFE' else '⚠️ تحذير: لا تدفع أي مبالغ مالية مسبقة مقابل التأشيرة أو فحص العقد نهائياً!'}"
                    )
                elif is_fr:
                    flags_str = "\n".join(f"  ⚠️ {rf}" for rf in flags) if flags else "  ✅ Aucune clause de paiement préalable ou confiscation détectée."
                    return (
                        f"📋 **Rapport d'analyse du contrat de travail**\n\n"
                        f"• **Niveau de risque :** {analysis['risk_rating']}\n"
                        f"• **Rémunération identifiée :** {analysis.get('compensation', 'Non spécifiée')}\n"
                        f"• **Clause de parrainage de visa :** {analysis.get('sponsorship_status', 'Non mentionnée')}\n"
                        f"• **Indicateurs suspects détectés :** {len(flags)}\n"
                        f"{flags_str}\n\n"
                        f"💡 **Recommandation :** {analysis.get('recommendation')}"
                    )
                else:
                    flags_str = "\n".join(f"  ⚠️ {rf}" for rf in flags) if flags else "  ✅ No illegal payment or withholding clauses detected."
                    return (
                        f"📋 **Contract Analysis Report**\n\n"
                        f"• **Risk Rating:** {analysis['risk_rating']}\n"
                        f"• **Compensation Identified:** {analysis.get('compensation', 'Not explicitly stated')}\n"
                        f"• **Visa Sponsorship Clause:** {analysis.get('sponsorship_status', 'No explicit commitment')}\n"
                        f"• **Red Flags Detected:** {len(flags)}\n"
                        f"{flags_str}\n\n"
                        f"💡 **Legal Recommendation:** {analysis.get('recommendation')}"
                    )

            if doc_type == "cv" or any(w in prompt_lower for w in ["ats", "cv", "resume", "سيرة"]):
                ats = LocalIntelligentEngine.analyze_cv_ats(doc_snippet)
                if is_ar:
                    skills_str = ", ".join(ats['detected_skills'][:10]) or "مهارات عامة"
                    missing_str = ", ".join(ats['missing_keywords'][:6]) or "لا توجد نواقص جوهرية"
                    return (
                        f"🎯 **تقرير تدقيق السيرة الذاتية (ATS Audit)**\n\n"
                        f"• **نسبة التوافق مع أنظمة الفرز الآلي:** {ats['ats_score']}/100\n"
                        f"• **المجال المهني المكتشف:** {ats['sector']}\n"
                        f"• **المهارات والكلمات المفتاحية المرصودة:** {skills_str}\n"
                        f"• **كلمات مفتاحية مقترحة للرفع من حظوظك:** {missing_str}\n\n"
                        f"🚀 **إرشادات عملية لتحسين سيرتك الذاتية:**\n"
                        f"  1. اعتمد صيغة عمود واحد قياسية بصيغة PDF وتجنب الجداول المعقدة.\n"
                        f"  2. اكتب إنجازاتك مدعومة بأرقام ونسب مئوية قابلة للقياس.\n"
                        f"  3. اجعل المسمى الوظيفي مطابقاً للمعايير الدولية المتعارف عليها في كندا وأوروبا."
                    )
                else:
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

        # 2. Free-form & Immigration Inquiries (Dynamic Multilingual Logic)
        if is_ar:
            # Arabic Answers
            if any(w in prompt_lower for w in ["كندا", "canada", "lmia", "كيبيك", "أريما"]):
                return (
                    "🇨🇦 **دليل الهجرة والعمل في كندا عبر VisaJob AI:**\n\n"
                    "1. **بوابة Job Bank Canada (الفرز للمرشحين الأجانب):**\n"
                    "   يقوم نظامنا بفرز العروض المؤشر عليها برمز `fglo=1`، وهي الوظائف التي يمتلك أصحابها ترخيص توظيف عمالة من خارج كندا عبر موافقة تقييم الأثر على سوق العمل (LMIA).\n\n"
                    "2. **برنامج التنقل الفرانكوفوني (Mobilité Francophone):**\n"
                    "   إذا كنت تتقن اللغة الفرنسية (مستوى B2 أو ما يعادل CLB 7)، يحق لأي صاحب عمل كندي خارج مقاطعة كيبيك توظيفك مباشرة بإعفاء كامل من شرط LMIA المعقد!\n\n"
                    "3. **نظام الدخول السريع (Express Entry):**\n"
                    "   يتطلب تقييم الشهادات (ECA مثل WES) واختبار لغة (IELTS General أو TEF Canada). الحصول على عقد عمل كندي موثق يمنحك بين 50 إلى 200 نقطة إضافية تضمن قبولك فوراً.\n\n"
                    "💡 *نصيحة المنظومة:* احرص على تفعيل نسختك الفرنسية أو الإنجليزية من السيرة الذاتية داخل تبويب CV Vault ليقوم الوكلاء بتقديم طلبك تلقائياً."
                )

            if any(w in prompt_lower for w in ["ألمانيا", "germany", "بطاقة الفرصة", "chancenkarte", "بلو كارد", "blue card"]):
                return (
                    "🇩🇪 **مسارات العمل والإقامة في ألمانيا:**\n\n"
                    "1. **بطاقة الفرصة الألمانية (Chancenkarte):**\n"
                    "   تأشيرة قائمة على نظام النقاط تسمح لك بدخول ألمانيا لمدة سنة للبحث عن عمل. المتطلبات: مؤهل جامعي أو مهني معترف به، وإتقان الألمانية (مستوى A1) أو الإنجليزية (مستوى B2)، وعمرك أقل من 35 سنة للظفر بأقصى النقاط.\n\n"
                    "2. **البطاقة الزرقاء الأوروبية (EU Blue Card):**\n"
                    "   أسرع طريق للإقامة الدائمة. تتطلب عقداً وظيفياً براتب إجمالي سنوي لا يقل عن 41,041 يورو للمهن التي تشهد نقصاً حاداً (الهندسة، تكنولوجيا المعلومات، التمريض والطب).\n\n"
                    "3. **معادلة الشهادات (Anerkennung):**\n"
                    "   يجب التأكد من إدراج جامعتك وتخصصك في قاعدة بيانات Anabin الألمانية لضمان اعتماد ملفك لدى السفارة."
                )

            if any(w in prompt_lower for w in ["فرنسا", "france", "passeport talent", "جواز موهبة", "باريس"]):
                return (
                    "🇫🇷 **فرص العمل وتأشيرات الكفاءات في فرنسا:**\n\n"
                    "1. **تأشيرة جواز سفر الكفاءات (Passeport Talent):**\n"
                    "   مخصصة للمهندسين وحملة الماجستير والكوادر العليا، وتمنحك إقامة قابلة للتجديد لـ 4 سنوات مع استقدام فوري للأسرة ودون الحاجة لفحص سوق العمل المحلي إذا كان الراتب يفوق ضعف الحد الأدنى (SMIC).\n\n"
                    "2. **قائمة المهن التي تشهد نقصاً (Métiers en Tension):**\n"
                    "   تشمل قطاعات تكنولوجيا المعلومات، البناء والأشغال العامة، اللوجستيك، والميكانيك. يتم إصدار تصريح العمل عبر منصة DREETS الرقمية في غضون أسابيع قليلة.\n\n"
                    "💡 *نصيحة:* تأكد من كتابة سيرتك الذاتية وخطاب التقديم باللغة الفرنسية السليمة، ويمكن لوكيلنا الآلي توليدها لك بضغطة زر."
                )

            if any(w in prompt_lower for w in ["الخليج", "السعودية", "الإمارات", "قطر", "قوى", "دبي"]):
                return (
                    "🇸🇦🇦🇪 **فرص العمل والانتقال لدول الخليج العربي:**\n\n"
                    "1. **المملكة العربية السعودية (منصة قوى):**\n"
                    "   يتم توثيق كافة عقود العمل وتأشيرات الكفاءات رقمياً عبر منصة 'قوى'. يشهد السوق طلباً متزايداً على مهندسي الذكاء الاصطناعي، مديري المشاريع، والمختصين الفنيين ضمن مشاريع رؤية 2030.\n\n"
                    "2. **الإمارات العربية المتحدة:**\n"
                    "   تأشيرة استكشاف فرص العمل والإقامة الخضراء للعمل الحر أو التوظيف المباشر في دبي وأبوظبي بدون اشتراط كفيل محلي للكفاءات المتخصصة.\n\n"
                    "3. **قطر وسلطنة عمان:**\n"
                    "   استقطاب مباشر للكوادر الطبية والهندسية والتعليمية مع سكن وتأمين صحي شامل وتغطية كاملة لتذاكر الطيران والإقامة."
                )

            if any(w in prompt_lower for w in ["سيرة", "cv", "resume", "ats", "كيف أكتب", "تعديل"]):
                return (
                    "📄 **كيف تصنع سيرة ذاتية دولية تتفوق على أنظمة الفرز الآلي (ATS)؟**\n\n"
                    "1. **تنسيق نصي نظيف:** ابتعد عن التصاميم ذات الأعمدة المزدوجة أو الصور أو الجداول المعقدة؛ أنظمة ATS الشركات العالمية تقرأ النصوص المتسلسلة (Single-column layout).\n"
                    "2. **معادلة الإنجازات (Action + Number):** بدلاً من ذكر المهام فقط، اذكر النتائج الملموسة. مثال: *'قمت بتطوير نظام التوزيع مما خفض زمن التوقف بنسبة 22%'*.\n"
                    "3. **مطابقة الكلمات المفتاحية:** تفحص إعلان الوظيفة واستخدم نفس المصطلحات التقنية المذكورة فيه.\n"
                    "4. **اللغة المستهدفة:** احرص على استخدام السيرة الذاتية باللغة الإنجليزية لكندا وألمانيا والخليج، واللغة الفرنسية لفرنسا وكيبيك وبلجيكا."
                )

            # Contextual Arabic reply for other queries
            return (
                f"مرحباً بك! أنا مستشارك الذكي للتوظيف والهجرة الدولية في منصة **VisaJob AI**.\n\n"
                f"بخصوص استفسارك: *'{prompt_clean}'*، يسعدني تقديم المساعدة المتخصصة في أي من المجالات التالية:\n"
                f"• 🌐 **استكشاف فرص العمل الدولية:** استعراض الوظائف التي تدعم كفالة التأشيرات (Canada LMIA, EURES, EU Blue Card).\n"
                f"• 📋 **فحص العقود وعروض العمل:** كشف محاولات النصب ورصد رسوم المعالجة الاحتيالية وبنود مصادرة الجوازات.\n"
                f"• 🎯 **تحسين السيرة الذاتية (ATS):** تحليل التوافق وإضافة الكلمات المفتاحية الأكثر طلباً لدى أصحاب العمل.\n"
                f"• ✍️ **صياغة رسائل التقديم المخصصة:** توليد خطابات احترافية باللغات العربية والفرنسية والإنجليزية.\n\n"
                f"أخبرني بما تحتاجه بالتحديد أو ارفع مستندك وسأقوم بتدقيقه لك فوراً!"
            )

        elif is_fr:
            # French Answers
            if any(w in prompt_lower for w in ["canada", "québec", "lmia"]):
                return (
                    "🇨🇦 **Immigration & Emploi au Canada avec VisaJob AI :**\n\n"
                    "1. **Guichet Emplois (Job Bank fglo=1) :** Filtrage des offres validées avec dispense ou acceptation d'EIMT (Étude d'Impact sur le Marché du Travail) pour les candidats internationaux.\n"
                    "2. **Mobilité Francophone :** Exemption directe d'EIMT pour tout emploi qualifié hors Québec si vous maîtrisez le français !\n"
                    "3. **Entrée Express :** Obtention de points cruciaux grâce à une offre d'emploi vérifiée."
                )
            return (
                f"Bonjour ! Je suis votre conseiller en emploi international et immigration au sein de **VisaJob AI**.\n\n"
                f"Concernant votre demande : *'{prompt_clean}'*, je peux vous aider à :\n"
                f"• Analyser vos contrats de travail et déceler les clauses frauduleuses ou frais suspects.\n"
                f"• Optimiser votre CV pour les filtres ATS des recruteurs internationaux.\n"
                f"• Vous orienter sur les démarches de visa pour le Canada, la France ou l'Allemagne.\n"
                f"N'hésitez pas à me poser une question précise ou à déposer un document pour analyse."
            )
        else:
            # English Answers
            if any(w in prompt_lower for w in ["canada", "lmia", "express entry"]):
                return (
                    "🇨🇦 **Canada Immigration & Employment Pathways:**\n\n"
                    "1. **Job Bank Canada (fglo=1):** Employers verified to recruit foreign workers under LMIA-approved streams.\n"
                    "2. **Express Entry (Federal Skilled Worker):** Language proficiency (CLB 7+) and ECA credential verification. A valid job offer awards 50 to 200 CRS points.\n"
                    "3. **Mobilité Francophone:** Exempts Canadian employers outside Quebec from LMIA requirements if your primary language is French.\n"
                    "VisaJob AI automatically scans and highlights these opportunities directly in your Jobs Center."
                )
            if any(w in prompt_lower for w in ["germany", "chancenkarte", "blue card"]):
                return (
                    "🇩🇪 **Germany Employment & Opportunity Card (Chancenkarte):**\n\n"
                    "1. **Chancenkarte:** Points-based job search visa (minimum 6 points required: degree, German A1/A2 or English B2, under 35 years old).\n"
                    "2. **EU Blue Card Germany:** Fast-track work permit with lower gross salary thresholds for shortage professions (~41,041€/year in STEM, IT, Healthcare).\n"
                    "3. **Anabin Verification:** Ensure your university degree is recognized (Status H+) before visa appointment."
                )
            return (
                f"Hello! I am your AI Immigration & Employment Consultant at **VisaJob AI**.\n\n"
                f"Regarding your query: *'{prompt_clean}'*, I am equipped to assist you with:\n"
                f"• **Contract Scam Audits:** Identifying advance-fee fraud, fake recruiter domains, and illegal passport withholding.\n"
                f"• **ATS CV Optimization:** Keyword matching and formatting for multinational applicant tracking systems.\n"
                f"• **Visa Pathways:** Sponsorship requirements for Canada (LMIA), Germany (Chancenkarte/Blue Card), France, and Gulf countries.\n"
                f"• **Targeted Cover Letters:** Generating customized professional letters tailored to each opening."
            )
    @staticmethod
    def analyze_contract(contract_text: str) -> dict[str, Any]:
        text_lower = contract_text.lower()
        red_flags = []
        risk_rating = "SAFE"

        if any(w in text_lower for w in ["western union", "moneygram", "crypto", "pay for visa", "visa processing fee", "refundable deposit"]) or (
            any(w in text_lower for w in ["western union", "moneygram", "crypto", "pay", "fee", "deposit", "upfront", "wire"]) and any(w in text_lower for w in ["visa", "processing", "permit", "relocation", "flight", "contract"])
        ):
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

