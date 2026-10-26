import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  static const String keyPref = 'user_language';
  static const Locale arabic = Locale('ar');
  static const Locale french = Locale('fr');
  static const Locale english = Locale('en');

  static const List<Locale> supportedLocales = [
    arabic,
    french,
    english,
  ];
}

class LanguageController extends ChangeNotifier {
  static final LanguageController instance = LanguageController._();
  LanguageController._();

  Locale _currentLocale = AppLanguage.english;
  Locale get currentLocale => _currentLocale;
  bool get isRtl => _currentLocale.languageCode == 'ar';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(AppLanguage.keyPref);

    if (savedCode != null && savedCode.isNotEmpty) {
      _currentLocale = Locale(savedCode);
    } else {
      // Auto-detect device language
      final deviceLocale = PlatformDispatcher.instance.locale;
      final code = deviceLocale.languageCode.toLowerCase();
      if (code == 'ar') {
        _currentLocale = AppLanguage.arabic;
      } else if (code == 'fr') {
        _currentLocale = AppLanguage.french;
      } else {
        _currentLocale = AppLanguage.english;
      }
      await prefs.setString(AppLanguage.keyPref, _currentLocale.languageCode);
    }
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (_currentLocale.languageCode == languageCode) return;
    _currentLocale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppLanguage.keyPref, languageCode);
    notifyListeners();
  }
}

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(LanguageController.instance.currentLocale);
  }

  String t(String key) {
    final lang = locale.languageCode;
    return _translations[lang]?[key] ?? _translations['en']?[key] ?? key;
  }

  static const Map<String, Map<String, String>> _translations = {
    // ================================================================= English
    'en': {
      'app_name': 'akremjobhunter',
      'app_tagline': 'AUTONOMOUS 24/7 AI RECRUITMENT AGENT',

      // Navigation
      'nav_dashboard': 'Dashboard',
      'nav_review': 'Review',
      'nav_memory': 'Memory',
      'nav_cv_vault': 'CV Vault',
      'nav_insights': 'Insights',
      'nav_settings': 'Settings',

      // Common
      'cancel': 'Cancel',
      'save': 'Save',
      'close': 'Close',
      'done': 'Done',
      'skip': 'Skip',
      'error': 'Error',
      'success': 'Success',
      'loading': 'Loading...',

      // Auth
      'auth_sign_in': 'Sign In',
      'auth_create_account': 'Create Account',
      'auth_username_email': 'Username or Email',
      'auth_username': 'Choose Username *',
      'auth_email': 'Email Address *',
      'auth_full_name': 'Full Name (Optional)',
      'auth_password': 'Password',
      'auth_choose_password': 'Choose Password *',
      'auth_confirm_password': 'Confirm Password *',
      'auth_remember_me': 'Remember Me',
      'auth_forgot_password': 'Forgot Password?',
      'auth_reset_password': 'Reset Password',
      'auth_verify_email': 'Verify Email',
      'auth_verify_account': 'Verify Account',
      'auth_skip_for_now': 'Skip for now',
      'auth_send_reset': 'Send Reset Instructions',
      'auth_save_new_pass': 'Save New Password',
      'auth_have_token': 'I already have a reset token',
      'auth_back_to_email': 'Back to email request',
      'auth_server_url': 'Cloud Server URL',
      'auth_security_badge': 'Argon2id Hashing  •  JWT Authentication  •  Zero Fake Data',
      'auth_strength_weak': 'Weak',
      'auth_strength_medium': 'Medium',
      'auth_strength_strong': 'Strong',
      'auth_strength_very_strong': 'Very Strong',
      'auth_passwords_dont_match': 'Passwords do not match',
      'auth_fill_all_fields': 'Please fill in all required fields',

      // Dashboard
      'dash_title': 'Cloud Engine Dashboard',
      'dash_quota': 'Daily Application Quota',
      'dash_review_banner': 'Applications Awaiting Your Review',
      'dash_review_action': 'Open Queue',
      'dash_integrations': 'Cloud Integrations',
      'dash_stats': '7-Day Activity & Metrics',
      'dash_jobs_scanned': 'Jobs Scanned',
      'dash_eligible': 'International Eligible',
      'dash_applied': 'Applications Sent',
      'dash_interviews': 'Interviews',
      'dash_offers': 'Job Offers',
      'dash_engine_status': 'Autonomous Engine Status',
      'dash_engine_running': 'ENGINE ACTIVE 24/7',
      'dash_engine_paused': 'ENGINE PAUSED',
      'dash_pause': 'Pause Engine',
      'dash_resume': 'Resume Engine',
      'dash_scan_now': 'Scan Jobs Now',
      'dash_recent': 'Recent Applications',

      // Review
      'review_title': 'Application Review Queue',
      'review_empty': 'Queue is Empty',
      'review_empty_sub': 'No applications waiting for manual review right now.',
      'review_send_now': 'Send Now',
      'review_mark_applied': 'Mark Applied',
      'review_open_portal': 'Open Portal',
      'review_edit_letter': 'Edit Letter',
      'review_match_score': 'Match Score',
      'review_evidence': 'Visa & Eligibility Evidence',

      // Memory / Applications
      'mem_title': 'Application Memory',
      'mem_all': 'All',
      'mem_review': 'Review',
      'mem_queue': 'Queue',
      'mem_sent': 'Sent',
      'mem_responses': 'Responses',
      'mem_skipped': 'Skipped',
      'mem_empty': 'No applications recorded yet',
      'mem_detail': 'Application Details',
      'mem_download_prep': 'Download Interview Prep Pack (PDF)',

      // CV Vault
      'cv_title': 'CV Vault',
      'cv_upload': 'Upload New CV (PDF)',
      'cv_empty': 'Vault is Empty',
      'cv_empty_sub': 'Upload your CVs in English and French. The AI strictly matches them to job languages.',
      'cv_active': 'Active for Applications',
      'cv_inactive': 'Paused',
      'cv_delete': 'Delete CV',
      'cv_sector': 'Sector',
      'cv_target_titles': 'Target Job Titles',
      'cv_language': 'Language',

      // Insights
      'ins_title': 'Recruitment Insights',
      'ins_countries': 'Country Heatmap & Eligibility',
      'ins_conversion': 'Conversion Rate',
      'ins_skill_gaps': 'Most Common Missing Skills',
      'ins_sources': 'Source Performance',

      // Settings
      'set_title': 'Settings & Integrations',
      'set_language': 'Language / Langue / اللغة',
      'set_candidate': 'Candidate Signature & Contact',
      'set_gmail': 'Gmail Bridge (IMAP & SMTP 24/7)',
      'set_ai': 'Gemini Pro AI Engine',
      'set_telegram': 'Telegram Notifier',
      'set_whatsapp': 'WhatsApp Alerts',
      'set_engine': 'Engine Pacing & Quotas',
      'set_countries': 'Target Countries',
      'set_change_pass': 'Change Password',
      'set_about': 'About Platform',
      'set_sign_out': 'Sign Out & Disconnect',
      'set_saved': 'Settings saved on Cloud Server',

      // About
      'about_title': 'About akremjobhunter',
      'about_version': 'Version 2.0.0 (Cloud SaaS)',
      'about_mission_title': 'Autonomous 24/7 Recruitment Agent',
      'about_mission_body': 'akremjobhunter operates continuously in the cloud even when your mobile phone or PC is powered off. It screens international opportunities, filters visa sponsorship, and drafts tailored applications.',
      'about_grounding_title': 'Strict CV Grounding Guarantee',
      'about_grounding_body': 'The AI will NEVER fabricate skills, qualifications, or experiences not explicitly present in your uploaded CVs.',
      'about_security_title': 'Privacy & Security Architecture',
      'about_security_body': 'Argon2id password hashing, JWT session rotation, AES-encrypted cloud credentials, and zero telemetry tracking.',
    },

    // ================================================================= French
    'fr': {
      'app_name': 'akremjobhunter',
      'app_tagline': 'AGENT DE RECRUTEMENT IA AUTONOME 24/7',

      // Navigation
      'nav_dashboard': 'Tableau de bord',
      'nav_review': 'À réviser',
      'nav_memory': 'Mémoire',
      'nav_cv_vault': 'Coffre CV',
      'nav_insights': 'Analytique',
      'nav_settings': 'Paramètres',

      // Common
      'cancel': 'Annuler',
      'save': 'Enregistrer',
      'close': 'Fermer',
      'done': 'Terminé',
      'skip': 'Passer',
      'error': 'Erreur',
      'success': 'Succès',
      'loading': 'Chargement...',

      // Auth
      'auth_sign_in': 'Se connecter',
      'auth_create_account': 'Créer un compte',
      'auth_username_email': 'Identifiant ou E-mail',
      'auth_username': 'Nom d\'utilisateur *',
      'auth_email': 'Adresse E-mail *',
      'auth_full_name': 'Nom complet (Optionnel)',
      'auth_password': 'Mot de passe',
      'auth_choose_password': 'Choisir un mot de passe *',
      'auth_confirm_password': 'Confirmer le mot de passe *',
      'auth_remember_me': 'Se souvenir de moi',
      'auth_forgot_password': 'Mot de passe oublié ?',
      'auth_reset_password': 'Réinitialiser le mot de passe',
      'auth_verify_email': 'Vérifier l\'e-mail',
      'auth_verify_account': 'Vérifier le compte',
      'auth_skip_for_now': 'Passer pour le moment',
      'auth_send_reset': 'Envoyer les instructions',
      'auth_save_new_pass': 'Enregistrer le mot de passe',
      'auth_have_token': 'J\'ai déjà un jeton de réinitialisation',
      'auth_back_to_email': 'Retour à la saisie de l\'e-mail',
      'auth_server_url': 'URL du serveur Cloud',
      'auth_security_badge': 'Hachage Argon2id  •  Authentification JWT  •  Zéro fausse donnée',
      'auth_strength_weak': 'Faible',
      'auth_strength_medium': 'Moyen',
      'auth_strength_strong': 'Fort',
      'auth_strength_very_strong': 'Très fort',
      'auth_passwords_dont_match': 'Les mots de passe ne correspondent pas',
      'auth_fill_all_fields': 'Veuillez remplir tous les champs obligatoires',

      // Dashboard
      'dash_title': 'Tableau de bord Cloud',
      'dash_quota': 'Quota quotidien de candidatures',
      'dash_review_banner': 'Candidatures en attente de révision',
      'dash_review_action': 'Ouvrir la file',
      'dash_integrations': 'Intégrations Cloud',
      'dash_stats': 'Activité sur 7 jours',
      'dash_jobs_scanned': 'Offres analysées',
      'dash_eligible': 'Éligibles international',
      'dash_applied': 'Candidatures envoyées',
      'dash_interviews': 'Entretiens',
      'dash_offers': 'Offres reçues',
      'dash_engine_status': 'Statut du moteur autonome',
      'dash_engine_running': 'MOTEUR ACTIF 24/7',
      'dash_engine_paused': 'MOTEUR EN PAUSE',
      'dash_pause': 'Mettre en pause',
      'dash_resume': 'Reprendre',
      'dash_scan_now': 'Scanner maintenant',
      'dash_recent': 'Candidatures récentes',

      // Review
      'review_title': 'File de révision',
      'review_empty': 'File vide',
      'review_empty_sub': 'Aucune candidature en attente de révision manuelle.',
      'review_send_now': 'Envoyer maintenant',
      'review_mark_applied': 'Marquer comme postulé',
      'review_open_portal': 'Ouvrir l\'offre',
      'review_edit_letter': 'Modifier la lettre',
      'review_match_score': 'Score de correspondance',
      'review_evidence': 'Preuve de visa & éligibilité',

      // Memory / Applications
      'mem_title': 'Mémoire des candidatures',
      'mem_all': 'Toutes',
      'mem_review': 'À réviser',
      'mem_queue': 'En file',
      'mem_sent': 'Envoyées',
      'mem_responses': 'Réponses',
      'mem_skipped': 'Ignorées',
      'mem_empty': 'Aucune candidature enregistrée pour le moment',
      'mem_detail': 'Détails de la candidature',
      'mem_download_prep': 'Télécharger le pack d\'entretien (PDF)',

      // CV Vault
      'cv_title': 'Coffre-fort CV',
      'cv_upload': 'Téléverser un nouveau CV (PDF)',
      'cv_empty': 'Le coffre est vide',
      'cv_empty_sub': 'Téléversez vos CVs en français et en anglais. L\'IA adaptera le CV à la langue de l\'offre.',
      'cv_active': 'Actif pour les candidatures',
      'cv_inactive': 'En pause',
      'cv_delete': 'Supprimer le CV',
      'cv_sector': 'Secteur',
      'cv_target_titles': 'Postes ciblés',
      'cv_language': 'Langue',

      // Insights
      'ins_title': 'Analytique & Tendances',
      'ins_countries': 'Carte des pays & éligibilité',
      'ins_conversion': 'Taux de conversion',
      'ins_skill_gaps': 'Compétences manquantes fréquentes',
      'ins_sources': 'Performance des sources',

      // Settings
      'set_title': 'Paramètres & Intégrations',
      'set_language': 'Langue / Language / اللغة',
      'set_candidate': 'Signature & Contact candidat',
      'set_gmail': 'Passerelle Gmail (IMAP & SMTP 24/7)',
      'set_ai': 'Moteur IA Gemini Pro',
      'set_telegram': 'Notifications Telegram',
      'set_whatsapp': 'Alertes WhatsApp',
      'set_engine': 'Cadence & Quotas du moteur',
      'set_countries': 'Pays ciblés',
      'set_change_pass': 'Changer le mot de passe',
      'set_about': 'À propos de la plateforme',
      'set_sign_out': 'Déconnexion du Cloud',
      'set_saved': 'Paramètres enregistrés sur le serveur Cloud',

      // About
      'about_title': 'À propos d\'akremjobhunter',
      'about_version': 'Version 2.0.0 (Cloud SaaS)',
      'about_mission_title': 'Agent de recrutement autonome 24/7',
      'about_mission_body': 'akremjobhunter fonctionne en continu dans le cloud, même lorsque votre téléphone ou PC est éteint. Il détecte les opportunités internationales, filtre les visas et rédige des candidatures personnalisées.',
      'about_grounding_title': 'Garantie stricte de fidélité au CV',
      'about_grounding_body': 'L\'IA n\'inventera JAMAIS de compétences, de diplômes ou d\'expériences absents de vos CVs téléversés.',
      'about_security_title': 'Sécurité & Confidentialité',
      'about_security_body': 'Hachage Argon2id, sessions JWT, chiffrement AES des identifiants et zéro collecte de données.',
    },

    // ================================================================= Arabic (RTL)
    'ar': {
      'app_name': 'akremjobhunter',
      'app_tagline': 'وكيل التوظيف الذكي المستقل 24/7',

      // Navigation
      'nav_dashboard': 'الرئيسية',
      'nav_review': 'المراجعة',
      'nav_memory': 'السجل',
      'nav_cv_vault': 'خزنة السير',
      'nav_insights': 'التحليلات',
      'nav_settings': 'الإعدادات',

      // Common
      'cancel': 'إلغاء',
      'save': 'حفظ',
      'close': 'إغلاق',
      'done': 'تم',
      'skip': 'تخطي',
      'error': 'خطأ',
      'success': 'نجاح',
      'loading': 'جار التحميل...',

      // Auth
      'auth_sign_in': 'تسجيل الدخول',
      'auth_create_account': 'إنشاء حساب جديد',
      'auth_username_email': 'اسم المستخدم أو الإيميل',
      'auth_username': 'اختر اسم المستخدم *',
      'auth_email': 'البريد الإلكتروني *',
      'auth_full_name': 'الاسم الكامل (اختياري)',
      'auth_password': 'كلمة السر',
      'auth_choose_password': 'اختر كلمة السر *',
      'auth_confirm_password': 'تأكيد كلمة السر *',
      'auth_remember_me': 'تذكرني',
      'auth_forgot_password': 'نسيت كلمة السر؟',
      'auth_reset_password': 'إعادة تعيين كلمة السر',
      'auth_verify_email': 'تأكيد البريد الإلكتروني',
      'auth_verify_account': 'تأكيد الحساب',
      'auth_skip_for_now': 'تخطي حالياً',
      'auth_send_reset': 'إرسال تعليمات الاستعادة',
      'auth_save_new_pass': 'حفظ كلمة السر الجديدة',
      'auth_have_token': 'لدي رمز الاستعادة مسبقاً',
      'auth_back_to_email': 'الرجوع لإدخال الإيميل',
      'auth_server_url': 'رابط الخادم السحابي',
      'auth_security_badge': 'تشفير Argon2id  •  جلسات JWT الآمنة  •  بدون أي بيانات وهمية',
      'auth_strength_weak': 'ضعيفة',
      'auth_strength_medium': 'متوسطة',
      'auth_strength_strong': 'قوية',
      'auth_strength_very_strong': 'قوية جداً',
      'auth_passwords_dont_match': 'كلمات السر غير متطابقة',
      'auth_fill_all_fields': 'الرجاء ملء جميع الحقول الإلزامية',

      // Dashboard
      'dash_title': 'لوحة تحكم الخادم السحابي',
      'dash_quota': 'الحصة اليومية للترشحات',
      'dash_review_banner': 'ترشحات بانتظار مراجعتك',
      'dash_review_action': 'فتح المراجعة',
      'dash_integrations': 'التكاملات السحابية',
      'dash_stats': 'نشاط وإحصائيات 7 أيام',
      'dash_jobs_scanned': 'عروض تم فحصها',
      'dash_eligible': 'تدعم المترشح الدولي',
      'dash_applied': 'ترشحات مرسلة',
      'dash_interviews': 'مقابلات عمل',
      'dash_offers': 'عروض قبول',
      'dash_engine_status': 'حالة المحرك الآلي',
      'dash_engine_running': 'المحرك نشط 24/7',
      'dash_engine_paused': 'المحرك متوقف مؤقتاً',
      'dash_pause': 'إيقاف مؤقت',
      'dash_resume': 'استئناف العمل',
      'dash_scan_now': 'فحص العروض الآن',
      'dash_recent': 'أحدث الترشحات',

      // Review
      'review_title': 'قائمة مراجعة الترشحات',
      'review_empty': 'القائمة فارغة',
      'review_empty_sub': 'لا توجد ترشحات بانتظار المراجعة اليدوية حالياً.',
      'review_send_now': 'إرسال الآن',
      'review_mark_applied': 'تأكيد التقديم',
      'review_open_portal': 'فتح العرض',
      'review_edit_letter': 'تعديل الرسالة',
      'review_match_score': 'نسبة التطابق',
      'review_evidence': 'إثبات الفيزا والأهلية',

      // Memory / Applications
      'mem_title': 'سجل وذاكرة الترشحات',
      'mem_all': 'الكل',
      'mem_review': 'للمراجعة',
      'mem_queue': 'في الانتظار',
      'mem_sent': 'مرسلة',
      'mem_responses': 'الردود',
      'mem_skipped': 'تم تخطيها',
      'mem_empty': 'لم يتم تسجيل أي ترشح حتى الآن',
      'mem_detail': 'تفاصيل الترشح',
      'mem_download_prep': 'تحميل ملف التحضير للمقابلة (PDF)',

      // CV Vault
      'cv_title': 'خزنة السير الذاتية',
      'cv_upload': 'رفع سيرة ذاتية جديدة (PDF)',
      'cv_empty': 'الخزنة فارغة',
      'cv_empty_sub': 'قم برفع سيرتك الذاتية بالفرنسية والإنجليزية. الذكاء الاصطناعي يختار تلقائياً النسخة المطابقة للغة العرض.',
      'cv_active': 'نشط للتقديم الآلي',
      'cv_inactive': 'متوقف مؤقتاً',
      'cv_delete': 'حذف السيرة',
      'cv_sector': 'القطاع المهني',
      'cv_target_titles': 'المسميات الوظيفية المستهدفة',
      'cv_language': 'اللغة',

      // Insights
      'ins_title': 'تحليلات فرص التوظيف',
      'ins_countries': 'خريطة الدول وفرص التأشيرة',
      'ins_conversion': 'نسبة الاستجابة والقبول',
      'ins_skill_gaps': 'المهارات الأكثر طلباً والناقصة',
      'ins_sources': 'أداء مصادر التوظيف',

      // Settings
      'set_title': 'الإعدادات والربط السحابي',
      'set_language': 'اللغة / Language / Langue',
      'set_candidate': 'بيانات وإمضاء المترشح',
      'set_gmail': 'جسر إيميل Gmail (IMAP و SMTP 24/7)',
      'set_ai': 'محرك الذكاء الاصطناعي Gemini Pro',
      'set_telegram': 'إشعارات تيليغرام الفورية',
      'set_whatsapp': 'تنبيهات واتساب',
      'set_engine': 'سرعة وجدولة المحرك',
      'set_countries': 'الدول المستهدفة للبحث',
      'set_change_pass': 'تغيير كلمة السر',
      'set_about': 'عن المنصة',
      'set_sign_out': 'تسجيل الخروج وقطع الاتصال',
      'set_saved': 'تم حفظ الإعدادات على السيرفر السحابي',

      // About
      'about_title': 'عن akremjobhunter',
      'about_version': 'الإصدار 2.0.0 (المنصة السحابية)',
      'about_mission_title': 'وكيل توظيف آلي يعمل 24/7',
      'about_mission_body': 'يعمل akremjobhunter بشكل متواصل على الخادم السحابي حتى لو كان هاتفك أو حاسوبك مغلقاً تماماً. يفرز فرص العمل الدولية، يتحقق من كفالة التأشيرات ورعاية تصاريح العمل، ويرسل الطلبات باحترافية.',
      'about_grounding_title': 'ضمان المصداقية التامة وعدم التزييف',
      'about_grounding_body': 'يضمن النظام بشكل قاطع أن الذكاء الاصطناعي لن يبتكر أو يزيف أي خبرة أو شهادة أو مهارة غير مذكورة صراحة في سيرتك الذاتية المرفوعة.',
      'about_security_title': 'الأمان والخصوصية المطلقة',
      'about_security_body': 'تشفير كلمات السر بـ Argon2id، جلسات JWT الآمنة، تشفير المفاتيح والبيانات بـ AES، وعدم مشاركة أي بيانات مع أطراف خارجية.',
    },
  };
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'fr', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
