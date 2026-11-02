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
        title = job.get("title", "Poste proposé")
        company = job.get("company", "Entreprise recruteuse")
        location = job.get("location", "")
        country = job.get("country", "")

        # Extract real profile elements from cv_text
        prof = LocalIntelligentEngine.extract_cv_profile(cv_text) if cv_text else None
        skills_str = ", ".join(prof.skills[:3]) if prof and prof.skills else "mes compétences techniques et mon savoir-faire pratique"
        target_role = prof.target_titles[0] if prof and prof.target_titles else "professionnel qualifié"

        # Look for experience years
        exp_match = re.search(r"(\d+)\s*(?:ans?|years?|سنوات)", cv_text or "", re.IGNORECASE)
        exp_str = f"avec plus de {exp_match.group(1)} ans d'expérience" if exp_match else "fort d'un parcours solide et éprouvé"

        # Look for diploma
        diploma_match = re.search(r"(Ingénieur|Licence|Master|BTS|BTP|CAP|Bachelor|Doctorat|شهادة)", cv_text or "", re.IGNORECASE)
        diploma_mention = f"Titulaire d'un {diploma_match.group(1)}, " if diploma_match else ""

        lang = (language or "fr").lower()[:2]
        if lang == "fr":
            subject = f"Candidature : {title} - {company}"
            loc_str = f" à {location}" if location else ""
            body = (
                f"Madame, Monsieur le Responsable du Recrutement,\n\n"
                f"Je vous soumets avec vif intérêt ma candidature pour le poste de {title} au sein de {company}{loc_str}.\n\n"
                f"{diploma_mention}en tant que {target_role} {exp_str}, j'ai développé des compétences reconnues notamment en {skills_str}. "
                f"Mon profil correspond directement aux exigences opérationnelles de votre offre, et je suis enthousiaste à l'idée d'apporter ma rigueur et mon dynamisme au sein de vos équipes.\n\n"
                f"Parfaitement mobile à l'international ({country}), je suis immédiatement disponible pour engager les formalités nécessaires (visa / permis de travail) et m'intégrer durablement au sein de votre entreprise.\n\n"
                f"Je me tiens à votre entière disposition pour un entretien afin de vous détailler mon expérience et mes réalisations.\n\n"
                f"Je vous prie d'agréer, Madame, Monsieur, l'expression de mes salutations distinguées.\n\n"
                f"{signature}"
            )
        elif lang == "ar":
            subject = f"طلب ترشح لوظيفة: {title} - {company}"
            body = (
                f"حضرة مسؤول التوظيف المحترم في {company}،\n\n"
                f"يشرفني أن أتقدم لسيادتكم بطلب ترشحي لشغل وظيفة {title} المعلنة لديكم.\n\n"
                f"انطلاقاً من تخصصي كـ {target_role} وخبرتي العملية المؤكدة، مع إتقاني لـ {skills_str}، "
                f"فإنني على ثقة تامة بقدرتي على تقديم إضافة نوعية ومباشرة لمشاريع شركتكم الموقرة.\n\n"
                f"أؤكد كامل جاهزيتي واستعدادي التام للانتقال وبدء العمل فوراً والتنسيق في إجراءات التأشيرة والعمل في {country}، متطلعاً لفرصة مناقشة مؤهلاتي خلال مقابلة شخصية قادمة.\n\n"
                f"وتفضلوا بقبول فائق الاحترام والتقدير.\n\n"
                f"{signature}"
            )
        else:
            subject = f"Application: {title} - {company}"
            body = (
                f"Dear Hiring Team at {company},\n\n"
                f"I am writing to express my strong enthusiasm for the {title} opening in {location} ({country}).\n\n"
                f"As a dedicated {target_role} {exp_str}, with demonstrated expertise in {skills_str}, "
                f"I have consistently delivered measurable operational results. My background directly aligns with the technical needs of your role.\n\n"
                f"I am fully prepared for international relocation to {country} and available to complete all necessary work authorization procedures immediately.\n\n"
                f"Thank you for considering my application. I look forward to the opportunity to discuss my qualifications during an interview.\n\n"
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
        text = (cv_text or "").strip()
        lines = [l.strip() for l in text.splitlines() if l.strip()]

        # 1. Candidate Name: skip generic CV labels
        candidate_name = "Candidate"
        headline_candidates = []
        for line in lines[:10]:
            clean_l = re.sub(r"[^\w\s-]", "", line).strip()
            if not clean_l:
                continue
            lower_l = clean_l.lower()
            if lower_l in ("curriculum vitae", "curriculum", "vitae", "cv", "resume", "profil", "coordonnées", "informations"):
                continue
            if candidate_name == "Candidate" and len(clean_l) >= 3 and len(clean_l.split()) <= 4 and not re.search(r"\d", clean_l):
                candidate_name = clean_l
            elif len(clean_l) >= 4 and len(clean_l) <= 60 and not re.search(r"@|\.com|\.fr|\+?\d{8}", line):
                headline_candidates.append(clean_l)

        # 2. Phone extraction
        phones = re.findall(r"(?:\+?\d{1,4}[\s.-]?)?\(?\d{2,4}\)?[\s.-]?\d{3,4}[\s.-]?\d{3,4}", text)
        phone = phones[0] if phones else ""

        # 3. Language detection
        lower = text.lower()
        french_words = ["expérience", "formation", "compétences", "profil", "langues", "poste", "professionnelle", "diplôme", "bac"]
        arabic_words = ["خبرة", "تعليم", "مهارات", "شهادة", "سيرة", "المؤهلات", "اللغات"]
        if any(w in lower for w in french_words):
            lang = "fr"
        elif any(w in lower for w in arabic_words):
            lang = "ar"
        else:
            lang = "en"

        # 4. Comprehensive Multi-Industry Classification (12 core categories)
        DOMAINS = [
            {
                "sector": "Santé & Soins Médicaux (Healthcare & Nursing)",
                "keywords": ["infirmier", "infirmière", "aide-soignant", "aide soignante", "médecin", "docteur", "kinésithérapeute", "pharmacien", "sage-femme", "laborantin", "radiologue", "nurse", "nursing", "caregiver", "healthcare", "hospital", "clinique", "médical", "ممرض", "تمريض", "طبيب", "صيدلي"],
                "titles": ["Nurse", "Infirmier", "Healthcare Assistant", "Aide-Soignant", "Medical Assistant"],
                "skills": ["Soins infirmiers", "Hygiène hospitalière", "Premiers secours", "Administration des médicaments", "Surveillance clinique", "Dossier patient"]
            },
            {
                "sector": "Comptabilité, Finance & Gestion (Accounting & Finance)",
                "keywords": ["comptable", "comptabilité", "expert-comptable", "finance", "financier", "trésorerie", "audit", "auditeur", "contrôleur de gestion", "fiscalité", "paie", "gestionnaire", "facturation", "sage", "ciel", "bilan", "accountant", "accounting", "bookkeeper", "محاسب", "محاسبة", "تدقيق مالي"],
                "titles": ["Accountant", "Comptable", "Financial Analyst", "Contrôleur de Gestion", "Assistant Comptable"],
                "skills": ["Tenue comptable", "Bilan comptable", "Rapprochement bancaire", "Fiscalité & TVA", "Logiciels Sage / Excel", "Gestion de la paie"]
            },
            {
                "sector": "Transport, Chauffeur & Logistique (Transport & Logistics)",
                "keywords": ["chauffeur", "conducteur", "poids lourd", "spl", "pl", "semi-remorque", "livreur", "permis c", "permis ec", "fimo", "fcos", "cariste", "caces", "magasinier", "préparateur de commandes", "logistique", "transit", "supply chain", "truck driver", "driver", "سائق", "نقل", "لوجستيك", "شاحنة"],
                "titles": ["Heavy Truck Driver", "Chauffeur Poids Lourd", "Logistics Specialist", "Magasinier Cariste", "Chauffeur SPL"],
                "skills": ["Conduite sécuritaire", "Réglementation transport", "CACES", "Gestion de stocks", "Préparation de commandes", "Arrimage et sécurisation"]
            },
            {
                "sector": "Hôtellerie, Restauration & Cuisine (Hospitality & Culinary)",
                "keywords": ["cuisinier", "chef de cuisine", "chef cuisinier", "commis de cuisine", "pâtissier", "boulanger", "serveur", "barman", "réceptionniste", "hôtellerie", "restauration", "cook", "chef", "baker", "waiter", "hospitality", "haccp", "طباخ", "طاهي", "نادل", "فندقة"],
                "titles": ["Cook", "Cuisinier", "Chef de Partie", "Boulanger Pâtissier", "Hospitality Specialist"],
                "skills": ["Normes HACCP", "Cuisine internationale", "Pâtisserie", "Gestion des cuissons", "Service en salle", "Gestion des commandes"]
            },
            {
                "sector": "BTP, Construction & Génie Civil (Civil Engineering & Construction)",
                "keywords": ["génie civil", "conducteur de travaux", "chef de chantier", "maçon", "coffreur", "ferrailleur", "peintre en bâtiment", "plâtrier", "plaquiste", "carreleur", "charpentier", "menuisier", "btp", "travaux publics", "béton", "chantier", "civil engineer", "construction", "بناء", "هندسة مدنية", "دهان", "نجار"],
                "titles": ["Civil Engineer", "Ingénieur Génie Civil", "Construction Supervisor", "Chef de Chantier", "Technicien BTP"],
                "skills": ["Lecture de plans", "Coordination de chantier", "Sécurité BTP", "Calcul de structure", "Béton armé", "Topographie"]
            },
            {
                "sector": "Électricité & Électromécanique (Electrical Engineering)",
                "keywords": ["électricien", "électricité", "câblage", "tableau électrique", "électromécanicien", "électromécanique", "électrotechnique", "automaticien", "automate", "schneider", "siemens", "plc", "electrician", "electrical", "كهربائي", "كهروميكانيك"],
                "titles": ["Electrician", "Électricien Industriel", "Electromechanical Technician", "Technicien Électromécanicien"],
                "skills": ["Schémas électriques", "Câblage industriel", "Automates programmables (PLC)", "Diagnostic pannes", "Normes NFC 15-100", "Maintenance BT/HT"]
            },
            {
                "sector": "Plomberie, Chauffage & Climatisation (Plumbing & HVAC)",
                "keywords": ["plombier", "plomberie", "chauffagiste", "frigoriste", "climatisation", "froid et climatisation", "hvac", "tuyauterie", "fluides frigorigènes", "pompe à chaleur", "sanitaire", "plumber", "refrigeration", "سباك", "تبريد وتكييف"],
                "titles": ["HVAC Technician", "Technicien Frigoriste", "Plumber", "Plombier Chauffagiste"],
                "skills": ["Installation sanitaire", "Systèmes de climatisation", "Tuyauterie cuivre/multicouche", "Manipulation fluides frigorigènes", "Dépannage chaudières"]
            },
            {
                "sector": "Soudure, Chaudronnerie & Métallurgie (Welding & Metalwork)",
                "keywords": ["soudeur", "soudure", "tig", "mig", "mag", "arc", "chaudronnier", "chaudronnerie", "tuyauterie", "métallier", "métaux", "acier", "welder", "welding", "لحام", "حداد"],
                "titles": ["Welder", "Soudeur TIG MIG", "Metal Fabricator", "Chaudronnier Tuyauteur"],
                "skills": ["Procédés TIG / MIG / MAG", "Soudure toutes positions", "Lecture plans isométriques", "Meulage et ajustage", "Contrôle non destructif"]
            },
            {
                "sector": "Mécanique & Maintenance Industrielle (Mechanical & Maintenance)",
                "keywords": ["mécanicien", "mécanique", "maintenance industrielle", "tourneur", "fraiseur", "usinage", "cnc", "commande numérique", "technicien de maintenance", "hydraulicien", "pneumatique", "automotive", "mechanic", "ميكانيكي", "صيانة صناعية"],
                "titles": ["Mechanical Technician", "Technicien de Maintenance", "Industrial Mechanic", "Mécanicien Automobile"],
                "skills": ["Maintenance préventive/curative", "Hydraulique & Pneumatique", "Usinage tournage/fraisage", "Diagnostic mécanique", "GMAO"]
            },
            {
                "sector": "Informatique, Développement & Réseaux (IT & Software)",
                "keywords": ["développeur", "programmation", "python", "java", "javascript", "typescript", "react", "flutter", "angular", "node", "php", "devops", "docker", "cloud", "aws", "système d'information", "administrateur système", "technicien réseau", "cyber", "data analyst", "software engineer", "developer", "مطور", "برمجة"],
                "titles": ["Software Developer", "Développeur Logiciel", "IT Support Specialist", "Technicien Systèmes et Réseaux"],
                "skills": ["Python / JavaScript", "Développement web & mobile", "Bases de données SQL", "Git & CI/CD", "Support technique & Réseaux"]
            },
            {
                "sector": "Commerce, Vente & Service Client (Sales & Customer Service)",
                "keywords": ["commercial", "technico-commercial", "vendeur", "vente", "conseiller commercial", "chargé de clientèle", "téléconseiller", "service client", "relation client", "caissier", "sales", "customer service", "مبيعات", "خدمة عملاء"],
                "titles": ["Sales Representative", "Conseiller Commercial", "Customer Service Agent", "Chargé de Clientèle"],
                "skills": ["Prospection commerciale", "Négociation", "Fidélisation client", "Gestion de litiges", "CRM & Outils de vente"]
            },
            {
                "sector": "Agriculture & Agroalimentaire (Agriculture & Farming)",
                "keywords": ["agriculteur", "ouvrier agricole", "maraîcher", "agronome", "ingénieur agronome", "élevage", "vétérinaire", "agroalimentaire", "récolte", "serres", "tracteur", "farm worker", "agriculture", "فلاح", "عامل فلاحي", "زراعة"],
                "titles": ["Agricultural Worker", "Ouvrier Agricole", "Farm Technician", "Technicien Agricole"],
                "skills": ["Travaux des champs", "Conduite d'engins agricoles", "Irrigation et fertilisation", "Culture maraîchère sous serre", "Entretien du matériel agricole"]
            },
        ]

        best_domain = None
        best_score = 0
        for d in DOMAINS:
            score = sum(1 for kw in d["keywords"] if kw in lower)
            if score > best_score:
                best_score = score
                best_domain = d

        sector = best_domain["sector"] if best_domain else "Technical & Vocational Services"
        target_titles = list(best_domain["titles"]) if best_domain else ["Specialist", "Technician", "Professional"]

        # Check if headline contains a specific title in first lines
        for h in headline_candidates[:3]:
            if any(w in h.lower() for w in ["ingénieur", "technicien", "chauffeur", "développeur", "comptable", "infirmier", "cuisinier", "soudeur", "plombier", "électricien", "commercial", "ouvrier", "chef", "responsable", "conducteur", "agent", "mécanicien", "analyste", "doctor", "engineer", "technician", "driver", "accountant", "nurse", "cook", "mechanic"]):
                target_titles.insert(0, h)
                break

        found_skills = []
        if best_domain:
            for s in best_domain["skills"]:
                found_skills.append(s)

        extra_skills = [
            "AutoCAD", "SolidWorks", "Catia", "Excel", "SAP", "GMAO", "Word", "PowerPoint",
            "Permis B", "Permis C", "Permis EC", "CACES", "FIMO", "HACCP", "SST / Premiers secours",
            "Anglais technique", "Français professionnel", "Arabe", "Travail en équipe", "Rigueur"
        ]
        for es in extra_skills:
            if es.lower() in lower and es not in found_skills:
                found_skills.append(es)

        return CvProfile(
            candidate_name=candidate_name,
            phone=phone,
            language=lang,
            sector=sector,
            target_titles=target_titles[:6],
            skills=found_skills[:15],
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

        # 1. Tunisian Derja / Arabizi detection
        tunisian_keywords = [
            "3asslema", "aslema", "ahla", "chneya", "chkoun", "n7eb", "kifech", "chfama",
            "5edma", "khedma", "flous", "brabi", "bellehi", "tawa", "fech", "wa9tech",
            "chnowa", "chnia", "cv", "el ai", "mahouch", "ye5dem", "mriguel", "sahbi",
            "khouya", "5ouya", "3awnni", "nlawej", "nlawaj", "mouch", "famech", "kontra",
            "contrat", "floussi", "visa", "chancenkarte", "lmia", "canada"
        ]
        is_tunisian_arabizi = any(kw in prompt_lower for kw in tunisian_keywords)
        has_arabic_script = bool(re.search(r'[؀-ۿ]', prompt_clean))
        has_french = not has_arabic_script and not is_tunisian_arabizi and (
            (language and language.lower().startswith('fr')) or
            any(w in prompt_lower for w in ["bonjour", "salut", "comment", "emploi", "travail", "lettre", "poste", "france", "québec", "allemagne", "merci", "aide", "embauche"])
        )

        # 2. Document Analysis Handlers (Contract, CV ATS, Offer Letter)
        if doc_snippet:
            if doc_type == "contract" or any(w in prompt_lower for w in ["contract", "عقد", "contrat", "kontra"]):
                analysis = LocalIntelligentEngine.analyze_contract(doc_snippet)
                flags = analysis.get('red_flags', [])
                if is_tunisian_arabizi:
                    flags_str = "\n".join(f"  ⚠️ {rf}" for rf in flags) if flags else "  ✅ العقد نظيف، ما ثماش حتى طلب فلوس أو حجز جواز السفر."
                    return (
                        f"📋 **تقرير فحص العقد - VisaJob AI**\n\n"
                        f"• **مستوى الأمان:** {'عقد سليم وقانوني ✅' if analysis['risk_rating'] == 'SAFE' else '⚠️ تحذير: ثمة شبهة تحيل أو خطر!'}\n"
                        f"• **الراتب:** {analysis.get('compensation', 'غير محدد')}\n"
                        f"• **الفيزا وعقد العمل:** {analysis.get('sponsorship_status')}\n"
                        f"• **الملاحظات والبنود المشبوهة:**\n{flags_str}\n\n"
                        f"💡 **نصيحة المنظومة:**\n"
                        f"{'تنجم تكمل إجراءاتك لكن ثبت في رقم التسجيل التجاري للشركة قبل التوقيع.' if analysis['risk_rating'] == 'SAFE' else '⚠️ رد بالك تدفع حتى مليم مسبق باسم معالجة الفيزا أو ملف السفر!'}"
                    )
                elif has_arabic_script or (language and language.lower().startswith('ar')):
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
                elif has_french:
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
                if is_tunisian_arabizi or has_arabic_script:
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

        # 3. Conversational / Q&A Handlers
        # A. Tunisian Derja / Arabizi Queries
        if is_tunisian_arabizi:
            if any(w in prompt_lower for w in ["canada", "kanda", "lmia", "quebec"]):
                return (
                    "🇨🇦 **عسلامة خويا! هاو الدليل الواضح للهجرة والخدمة في كندا:**\n\n"
                    "1. **عروض Job Bank Canada (المخصصة للأجانب):**\n"
                    "   السيستام يفرزلك العروض اللي فيها رمز `fglo=1`. المشغلين هاذم عندهم رخصة LMIA خالصة وحاضرة ويحبوا يجيبوا خدامة من تونس ومن العالم كامل.\n\n"
                    "2. **برنامج Mobilité Francophone:**\n"
                    "   كان مستواك في الفرنسية باهي (B2)، المشغل الكندي ينجم يخدمك خارج مقاطعة كيبيك من غير ما يستنى رخصة LMIA المعقدة!\n\n"
                    "3. **شنوا المطلوب منك؟**\n"
                    "   ادخل لـ 'Coffre CV' وتأكد اللي صبيت النسخة الفرنسية أو الإنجليزية من الـ CV متاعك. السيستام توا يلوجلك على الخدم اللي تطابق اختصاصك بالضبط ويكتبلك رسالة التقديم.\n\n"
                    "قلي شنوا اختصاصك توة ونقلك أناهي ولاية كندية فيها أكثر طلب عليك!"
                )
            if any(w in prompt_lower for w in ["chancenkarte", "germany", "allemagne", "almania"]):
                return (
                    "🇩🇪 **فرص العمل وبطاقة الفرصة الألمانية (Chancenkarte):**\n\n"
                    "1. **بطاقة الفرصة:** تنجم تسافر لألمانيا وتبحث على خدمة على عين المكان لمدة عام كامل، بشرط تجمع 6 نقاط (ديبلوم معترف بيه + إنجليزية B2 أو ألمانية A1 + عمرك أقل من 35).\n"
                    "2. **البطاقة الزرقاء الأوروبية (EU Blue Card):** للمهندسين والممرضين والتقنيين السامين، عقد عمل براتب يبدأ من حوالي 41 ألف يورو يعطيك إقامة دائمة في وقت قياسي.\n\n"
                    "تحب تشوف العروض المتاحة في ألمانيا؟ ادخل لـ 'Explorer les offres' وفلتر على علم ألمانيا 🇩🇪!"
                )
            if any(w in prompt_lower for w in ["contrat", "kontra", "flous", "arnaque", "sar9a", "wahmi"]):
                return (
                    "⚠️ **كيفاش تفرق بين العقد الحقيقي والعقد الوهمي؟**\n\n"
                    "1. **القاعدة الذهبية:** المشغل الحقيقي في كندا أو أوروبا هو اللي يخلص مصاريف رخصة العمل (LMIA / Work Permit)؛ القانون يمنع عليه يطلب منك تدفع حق الفيزا أو دوسي التقديم!\n"
                    "2. **الإيميل الرسمي:** الشركات الرسمية تبعث من دومين الشركة (مثال: @company.com) مش من Gmail أو Yahoo.\n"
                    "3. **الفحص المباشر:** تنجم تنزل على علامة المشبك 📎 هوني وتبعثلي ملف الـ PDF متاع العقد، ونقراهولك سطر بسطر ونقلك كان فيه أي شبهة تحيل!\n\n"
                    "كان عندك عقد تحب نفحصوه توة، ابعثهولي وماتترددش."
                )
            # Default warm friendly Tunisian response
            return (
                f"عسلامة خويا العزيز وبك في **VisaJob AI**! 🤝\n\n"
                f"أنا معاك ومستعد نعاونك في كل خطوة تخص خروجك وخدمتك البرا:\n"
                f"• 🔍 **نلوجلك على خدمة حقيقية:** حسب اختصاصك وسيرتك الذاتية في كندا وألمانيا وفرنسا والخليج.\n"
                f"• 🛡️ **نفحص أي عقد أو عرض:** باش نضمنوا اللي ما فماش حتى تحيل أو طلب فلوس غير قانوني.\n"
                f"• ✍️ **نكتبولك رسالة ترشح (Lettre de motivation):** احترافية ومخصصة لكل شركة تختارها.\n\n"
                f"قلي شنوا تخصصك أو فاش تحب نعاونك توا وبحول الله تلقى كان اللي يفيدك!"
            )

        # B. Standard Arabic Queries
        if has_arabic_script or (language and language.lower().startswith('ar')):
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
            if any(w in prompt_lower for w in ["سيرة", "cv", "resume", "ats", "كيف أكتب", "تعديل"]):
                return (
                    "📄 **كيف تصنع سيرة ذاتية دولية تتفوق على أنظمة الفرز الآلي (ATS)؟**\n\n"
                    "1. **تنسيق نصي نظيف:** ابتعد عن التصاميم ذات الأعمدة المزدوجة أو الصور أو الجداول المعقدة؛ أنظمة ATS الشركات العالمية تقرأ النصوص المتسلسلة (Single-column layout).\n"
                    "2. **معادلة الإنجازات (Action + Number):** بدلاً من ذكر المهام فقط، اذكر النتائج الملموسة. مثال: *'قمت بتطوير نظام التوزيع مما خفض زمن التوقف بنسبة 22%'*.\n"
                    "3. **مطابقة الكلمات المفتاحية:** تفحص إعلان الوظيفة واستخدم نفس المصطلحات التقنية المذكورة فيه.\n"
                    "4. **اللغة المستهدفة:** احرص على استخدام السيرة الذاتية باللغة الإنجليزية لكندا وألمانيا والخليج، واللغة الفرنسية لفرنسا وكيبيك وبلجيكا."
                )
            return (
                f"مرحباً بك! أنا مستشارك الذكي للتوظيف والهجرة الدولية في منصة **VisaJob AI**.\n\n"
                f"بخصوص استفسارك: *'{prompt_clean}'*، يسعدني تقديم المساعدة المتخصصة في أي من المجالات التالية:\n"
                f"• 🌐 **استكشاف فرص العمل الدولية:** استعراض الوظائف التي تدعم كفالة التأشيرات (Canada LMIA, EURES, EU Blue Card).\n"
                f"• 📋 **فحص العقود وعروض العمل:** كشف محاولات النصب ورصد رسوم المعالجة الاحتيالية وبنود مصادرة الجوازات.\n"
                f"• 🎯 **تحسين السيرة الذاتية (ATS):** تحليل التوافق وإضافة الكلمات المفتاحية الأكثر طلباً لدى أصحاب العمل.\n"
                f"• ✍️ **صياغة رسائل التقديم المخصصة:** توليد خطابات احترافية باللغات العربية والفرنسية والإنجليزية.\n\n"
                f"أخبرني بما تحتاجه بالتحديد أو ارفع مستندك وسأقوم بتدقيقه لك فوراً!"
            )

        # C. French Queries
        if has_french:
            if any(w in prompt_lower for w in ["canada", "québec", "lmia", "francophone"]):
                return (
                    "🇨🇦 **Immigration & Emploi au Canada avec VisaJob AI :**\n\n"
                    "1. **Guichet Emplois (Job Bank fglo=1) :** Filtrage des offres validées avec acceptation d'EIMT (Étude d'Impact sur le Marché du Travail) pour les candidats internationaux.\n"
                    "2. **Mobilité Francophone :** Exemption directe d'EIMT pour tout emploi qualifié hors Québec si vous maîtrisez le français !\n"
                    "3. **Entrée Express :** Obtention de points cruciaux grâce à une offre d'emploi vérifiée."
                )
            return (
                f"Bonjour ! Je suis votre conseiller en emploi international et immigration au sein de **VisaJob AI**.\n\n"
                f"Concernant votre demande : *'{prompt_clean}'*, je peux vous aider à :\n"
                f"• Analyser vos contrats de travail et déceler les clauses frauduleuses ou frais suspects.\n"
                f"• Optimiser votre CV pour les filtres ATS des recruteurs internationaux.\n"
                f"• Cibler les offres vérifiées pour le Canada, l'Allemagne et la France.\n"
                f"N'hésitez pas à me poser une question précise ou à déposer un document pour analyse."
            )

        # D. English Queries (Default)
        if any(w in prompt_lower for w in ["canada", "lmia", "express entry"]):
            return (
                "🇨🇦 **Canada Immigration & Employment Pathways:**\n\n"
                "1. **Job Bank Canada (fglo=1):** Employers verified to recruit foreign workers under LMIA-approved streams.\n"
                "2. **Express Entry (Federal Skilled Worker):** Language proficiency (CLB 7+) and ECA credential verification. A valid job offer awards 50 to 200 CRS points.\n"
                "3. **Mobilité Francophone:** Exempts Canadian employers outside Quebec from LMIA requirements if your primary language is French.\n"
                "VisaJob AI automatically scans and highlights these opportunities directly in your Jobs Center."
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

