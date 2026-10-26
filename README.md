# akremjobhunter — AI Job Hunter (24/7 Cloud Engine + Mobile App)

تطبيق ومحرك سحابي ذكي للبحث عن وظائف دولية (كندا، أوروبا، أمريكا) مخصص للمترشحين من تونس.
يعمل المحرك 24/7 على السحابة باستقلالية تامة عن الهاتف، مع إيقاع بشري ذكي (حد أقصى 20 ترشيح يومياً موزعة على مدار اليوم) لمنع الحظر، وذاكرة ترشحات دائمة تمنع التكرار نهائياً.

---

## 📁 بنية المشروع المنجز

```text
akremjobhunter/
├── akremjobhunter.apk               <-- ملف تطبيق الهاتف الجاهز للتثبيت المباشر
├── backend/
│   ├── app/
│   │   ├── main.py                  # خادم FastAPI بنظام lifespan الحديث
│   │   ├── config.py                # إعدادات البيئة والمجلدات
│   │   ├── security.py              # مصادقة Bearer وحماية التشفير للبيانات الحساسة
│   │   ├── settings_store.py        # تخزين الإعدادات مع تشفير كلمات المرور
│   │   ├── db.py                    # قاعدة بيانات SQLite (WAL Mode) على قرص دائم
│   │   ├── models.py                # نماذج قاعدة البيانات (CVs, Jobs, Applications, Events)
│   │   ├── filters.py               # فلاتر استبعاد الوظائف الحكومية والشروط المحلية
│   │   ├── ai.py                    # محرك الذكاء الاصطناعي (Gemini Pro) مع Strict Grounding
│   │   ├── mailer.py                # محرك البريد الآمن (IMAP BODY.PEEK + SMTP TLS)
│   │   ├── notifier.py              # بوت التليغرام التفاعلي مع أزرار الإجراء السريع + WhatsApp
│   │   ├── pdfgen.py                # توليد ملف PDF حقيقي للتحضير للمقابلة (fpdf2)
│   │   ├── pipeline.py              # دورة العمل: الفحص، التقييم، التقديم البشري، وقراءة الردود
│   │   ├── scheduler.py             # جدولة المهام المستمرة 24/7 (APScheduler)
│   │   ├── cvs.py                   # مستودع السير الذاتية (CV Vault) واستخراج المهارات
│   │   ├── api.py                   # واجهات REST API لتطبيق الهاتف
│   │   └── sources/
│   │       ├── jobbank.py           # سحب عروض Job Bank Canada (فلتر fglo=1 للمرشحين الدوليين)
│   │       ├── arbeitnow.py         # سحب عروض Arbeitnow (فلتر Visa Sponsorship)
│   │       ├── adzuna.py            # ربط واجهة Adzuna الرسمية لأوروبا وأمريكا
│   │       └── jobspy_src.py        # سحب عروض الويب العامة دون أي تسجيل دخول
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── .env.example
└── mobile/                          # تطبيق Flutter الكامل (Dart 3 / Material 3)
    ├── lib/
    │   ├── main.dart
    │   ├── theme/app_theme.dart     # الثيم الليلي العصري
    │   ├── services/api_service.dart
    │   ├── models/models.dart
    │   └── screens/
    │       ├── connection_screen.dart   # شاشة ربط السيرفر والمصادقة
    │       ├── dashboard_screen.dart    # لوحة المراقبة 24/7 والتحكم
    │       ├── review_screen.dart       # قائمة الموافقة بضغطة واحدة (1-Click Review)
    │       ├── cv_vault_screen.dart     # مستودع رفع وإدارة السير الذاتية (PDFs)
    │       ├── applications_screen.dart # ذاكرة الترشحات وتتبع الردود وتحميل ملف المقابلة
    │       ├── insights_screen.dart     # خريطة الطلب الجغرافي ومحلل فجوة المهارات
    │       └── settings_screen.dart     # إعدادات الربط مع Gmail، Gemini Pro، وتليغرام
    └── pubspec.yaml
```

---

## 🚀 خطوة 1: تشغيل السيرفر السحابي (Cloud Engine)

### أ. التشغيل السريع محلياً (للتجربة)
1. افتح Terminal في مجلد `backend`:
   ```powershell
   cd backend
   pip install -r requirements.txt
   ```
2. أنشئ ملف `.env`:
   ```ini
   ACCESS_KEY=my_secure_secret_token_12345
   SECRET_KEY=my_database_encryption_key_32chars!
   DATA_DIR=./data
   TIMEZONE=Africa/Tunis
   MAX_DAILY_APPLICATIONS=20
   ```
3. شغّل السيرفر:
   ```powershell
   uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```

### ب. النشر على سحابة مجانية دائمة 24/7 (Oracle Cloud Always Free)
1. في لوحة تحكم Oracle Cloud، أنشئ مثيل **Compute Instance** مجاني دائم (Ubuntu / Always Free AMD or ARM Ampere).
2. ثبّت Docker و Docker Compose على السيرفر:
   ```bash
   sudo apt update && sudo apt install -y docker.io docker-compose
   ```
3. ارفع مجلد `backend` للسيرفر وشغّله بأمر واحد:
   ```bash
   docker-compose up -d
   ```
4. افتح المنفذ `8000` في الـ Security List للسيرفر.

---

## 📱 خطوة 2: تثبيت التطبيق على هاتفك وتشغيله

1. انسخ ملف **`akremjobhunter.apk`** إلى هاتفك وثبّته.
2. عند فتح التطبيق، ستظهر لك شاشة الربط:
   - **Cloud Server URL:** اكتب عنوان سيرفرك (مثال: `http://192.168.1.50:8000` أو رابط سيرفرك السحابي).
   - **Access Key:** المفتاح السري الذي وضعته في ملف `.env` (لحماية التطبيق من أي استخدام غير مصرح به).
3. اضغط **Connect to Cloud Engine**.

---

## 📄 خطوة 3: رفع سيرتك الذاتية في CV Vault

من شاشة **CV Vault** في التطبيق:
1. اضغط على زر **Upload CV (PDF)**.
2. اختر ملفات الـ PDF الخاصة بك من الهاتف (مثلاً: سيفي السياقة الثقيلة الفرنسي، سيفي السياقة الثقيلة الإنجليزي، سيفي التصميم و CNC).
3. سيقوم الذكاء الاصطناعي (Gemini Pro) تلقائياً بتحليل السيفي واستخراج:
   - لغة السيفي (فرنسية / إنجليزية).
   - المسمى الوظيفي المستهدف والمهارات الحقيقية والشهادات.
   - اسمك ورقم هاتفك لاعتمادها في التوقيع ورسائل التغطية.
4. **مبدأ الالتزام التام (Strict Grounding):** يمنع المحرك نهائياً اختراع أي سنوات خبرة أو شهادات غير موجودة في الـ PDF.

---

## ⚙️ خطوة 4: ضبط الربط في شاشة Settings

1. **Gmail Bridge:**
   - أدخل عنوان بريدك: `Hidouri.akrem@gmail.com`.
   - أدخل كلمة مرور التطبيقات الجديدة (App Password) المكونة من 16 حرفاً.
   - اضغط **Test IMAP / SMTP Connection** للتأكد من نجاح الربط.
2. **Gemini Pro:**
   - أدخل مفتاح الـ Gemini API.
   - اختر النموذج المفضل (أو اتركه تلقائياً لأقوى نموذج Gemini Pro متاح).
   - اضغط **Test Gemini Pro Model**.
3. **Telegram Bot:**
   - أدخل الـ Bot Token من `@BotFather`.
   - افتح بوتك في تليغرام واضغط `/start`، وسيرتبط البوت تلقائياً بحسابك لتلقي إشعارات المقابلات وأزرار التقديم بضغطة واحدة.
4. **Targeting & Throttle:**
   - حدد الدول المستهدفة (كندا، فرنسا، ألمانيا، بلجيكا، لوكسمبورغ، إلخ).
   - حدد الحد اليومي (الافتراضي 20 ترشيحاً موزعة بتدرج زمني طبيعي).

---

## 🎯 الميزات الذكية المدمجة
- **Job Bank Canada fglo=1:** يجلب فقط الوظائف المصنفة رسمياً للمترشحين الدوليين خارج كندا والمدعومة بـ LMIA.
- **Arbeitnow Visa Sponsorship:** يجلب العروض الأوروبية المعلن صراحة عن دعمها للفيزا.
- **توليد Cover Letter دقيقة:** مخصصة لكل عرض، ومستندة 100% فقط على محتويات السيفي.
- **رصد الردود وتوليد ملف المقابلة الآلي:** عند رصد دعوة مقابلة في الإيميل، يتم فوراً البحث عن الشركة وتوليد ملف PDF متكامل لتحضير المقابلة مع الأسئلة المقترحة وإرساله إلى تليغرام والتطبيق.
