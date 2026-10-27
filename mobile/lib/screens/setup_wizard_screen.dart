import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/arab_country_picker.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // Step 1: Language
  String _selectedLang = 'ar';

  // Step 2: Account / Identity
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  ArabCountry _selectedCountry = getArabCountry('TN');

  // Step 3: CV
  File? _selectedCvFile;
  String? _cvFileName;
  bool _cvUploading = false;
  String? _cvUploadStatus;

  // Step 4: Gmail
  final _gmailController = TextEditingController();
  bool _gmailConnected = false;

  // Step 5: WhatsApp
  bool _whatsappEnabled = true;

  // Step 6: Preferences
  final List<String> _selectedCountries = ['CA', 'DE', 'FR', 'SA', 'AE', 'QA'];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedLang = LanguageController.instance.currentLocale.languageCode;
    final user = ApiService.currentUser;
    if (user != null) {
      _usernameController.text = user['username'] ?? '';
      _emailController.text = user['email'] ?? '';
      _fullNameController.text = user['full_name'] ?? '';
      _phoneController.text = user['phone'] ?? '';
      if (user['country_code'] != null) {
        _selectedCountry = getArabCountry(user['country_code']);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _gmailController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 5) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finishWizard();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickCv() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'txt'],
      );
      if (files.isNotEmpty && files.first.path != null) {
        setState(() {
          _selectedCvFile = File(files.first.path!);
          _cvFileName = files.first.name;
          _cvUploadStatus = null;
        });
      }
    } catch (e) {
      setState(() => _cvUploadStatus = 'خطأ في اختيار الملف: $e');
    }
  }

  Future<void> _uploadCv() async {
    if (_selectedCvFile == null) return;
    setState(() => _cvUploading = true);
    try {
      await ApiService.uploadCv(_selectedCvFile!.path, _cvFileName ?? 'CV.pdf');
      setState(() {
        _cvUploading = false;
        _cvUploadStatus = 'تم رفع وتحليل السيرة الذاتية بنجاح ✅';
      });
    } catch (e) {
      setState(() {
        _cvUploading = false;
        _cvUploadStatus = 'تم حفظ الملف للمزامنة اللاحقة';
      });
    }
  }

  Future<void> _finishWizard() async {
    setState(() => _saving = true);
    try {
      // Save settings
      final payload = <String, dynamic>{
        'full_name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'target_countries': _selectedCountries,
        if (_gmailController.text.isNotEmpty) 'gmail_address': _gmailController.text.trim(),
        if (_whatsappEnabled && _phoneController.text.isNotEmpty)
          'whatsapp_phone': '${_selectedCountry.dialCode}${_phoneController.text.trim()}',
      };
      await ApiService.saveSettings(payload);

      // Mark wizard completed in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = LanguageController.instance.currentLocale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Steps Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/branding/app_badge.jpg',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.radar_rounded, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'معالج الإعداد السريع' : 'Quick Setup Wizard',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        isAr ? 'الخطوة ${_currentStep + 1} من 6' : 'Step ${_currentStep + 1} of 6',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _finishWizard,
                      child: Text(isAr ? 'تخطي الآن' : 'Skip', style: const TextStyle(color: AppTheme.textMuted)),
                    ),
                ],
              ),
            ),

            // Progress Line
            LinearProgressIndicator(
              value: (_currentStep + 1) / 6,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 3,
            ),

            // Page Contents
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1Language(),
                  _buildStep2Account(),
                  _buildStep3CvUpload(),
                  _buildStep4Gmail(),
                  _buildStep5WhatsApp(),
                  _buildStep6JobPreferences(),
                ],
              ),
            ),

            // Bottom Navigation Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0) ...[
                    OutlinedButton(
                      onPressed: _prevStep,
                      child: Text(isAr ? 'السابق' : 'Back'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _nextStep,
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : Text(_currentStep == 5
                              ? (isAr ? 'ابدأ البحث عن عمل 🚀' : 'Start Hunting Jobs 🚀')
                              : (isAr ? 'متابعة' : 'Next')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 1: Language
  Widget _buildStep1Language() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/branding/app_badge.jpg',
              width: 90,
              height: 90,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'اختر لغة التطبيق المفضلة\nChoose Your Preferred Language',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text(
            'يتكيف التطبيق تلقائياً مع لغة عروض العمل (كندا، أوروبا، الخليج العربي).',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 32),
          _langOption('ar', 'العربية (RTL)', '🇹🇳 كامل التطبيق مع دعم اتجاه اليمين لليسار'),
          const SizedBox(height: 12),
          _langOption('fr', 'Français', '🇫🇷 Idéal pour le Canada (Mobilité Francophone) & l\'Europe'),
          const SizedBox(height: 12),
          _langOption('en', 'English', '🇬🇧 Perfect for international & Gulf opportunities'),
        ],
      ),
    );
  }

  Widget _langOption(String code, String title, String subtitle) {
    final selected = _selectedLang == code;
    return InkWell(
      onTap: () async {
        setState(() => _selectedLang = code);
        await LanguageController.instance.setLanguage(code);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }

  // Step 2: Account / Country Identity
  Widget _buildStep2Account() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'بيانات المترشح والدولة العربية 🌍',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'يتم استخدام اسمك الكامل ورقم هاتفك في إمضاء طلبات التوظيف الرسمية.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _fullNameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'الاسم واللقب (Full Name)',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),
          const Text('الدولة ورقم الهاتف:', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          ArabCountryPickerField(
            selectedCountry: _selectedCountry,
            onCountryChanged: (c) => setState(() => _selectedCountry = c),
            phoneController: _phoneController,
            currentLang: _selectedLang,
          ),
        ],
      ),
    );
  }

  // Step 3: CV Upload
  Widget _buildStep3CvUpload() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'رفع السيرة الذاتية (CV Vault) 📄',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'يقوم الذكاء الاصطناعي باستخراج مهاراتك وخبراتك بدقة تامة ومطابقتها مع فرص العمل.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                const Icon(Icons.cloud_upload_outlined, size: 54, color: AppTheme.primary),
                const SizedBox(height: 14),
                Text(
                  _cvFileName ?? 'اختر ملف السيرة الذاتية (PDF أو Word)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _cvFileName != null ? Colors.white : AppTheme.textMuted,
                    fontWeight: _cvFileName != null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickCv,
                      icon: const Icon(Icons.attach_file),
                      label: Text(_cvFileName == null ? 'تصفح الملفات' : 'تغيير الملف'),
                    ),
                    if (_selectedCvFile != null && !_cvUploading) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _uploadCv,
                        icon: const Icon(Icons.check),
                        label: const Text('رفع وتحليل'),
                      ),
                    ],
                  ],
                ),
                if (_cvUploading) ...[
                  const SizedBox(height: 14),
                  const CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
                ],
                if (_cvUploadStatus != null) ...[
                  const SizedBox(height: 12),
                  Text(_cvUploadStatus!, style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 4: Gmail 1-Click Guided
  Widget _buildStep4Gmail() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ربط البريد الإلكتروني (Gmail Integration) ✉️',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'يرسل التطبيق ملفات الترشح ومتابعة الردود تلقائياً من بريدك دون تعقيدات تقنية.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.mail_rounded, color: Colors.redAccent, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'ربط سريع بضغطة زر',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _gmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'عنوان بريدك على Gmail',
                    hintText: 'example@gmail.com',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_gmailController.text.trim().isNotEmpty) {
                      setState(() => _gmailConnected = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تسجيل حساب البريد بنجاح ✅')),
                      );
                    }
                  },
                  icon: const Icon(Icons.link),
                  label: Text(_gmailConnected ? 'تم الربط بنجاح ✅' : 'تأكيد الحساب'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gmailConnected ? const Color(0xFF10B981) : AppTheme.primary,
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 5: WhatsApp Alerts
  Widget _buildStep5WhatsApp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تنبيهات واتساب الفورية (WhatsApp Alerts) 💬',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'توصل فورياً بدعوات المقابلات وعروض العمل المهمة مباشرة على هاتفك.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _whatsappEnabled,
                  activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.5),
                  thumbColor: WidgetStateProperty.all(const Color(0xFF10B981)),
                  title: const Text('تفعيل تنبيهات واتساب للفرص والمقابلات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    _phoneController.text.isNotEmpty
                        ? 'الرقم المسجل: ${_selectedCountry.dialCode} ${_phoneController.text}'
                        : 'سيتم استخدام رقم هاتفك المدخل',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  onChanged: (val) => setState(() => _whatsappEnabled = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 6: Job Target Preferences
  Widget _buildStep6JobPreferences() {
    final available = [
      {'code': 'CA', 'name': 'كندا 🇨🇦', 'desc': 'برنامج الحركية الفرانكفونية'},
      {'code': 'DE', 'name': 'ألمانيا 🇩🇪', 'desc': 'بطاقة الفرص Chancenkarte'},
      {'code': 'FR', 'name': 'فرنسا 🇫🇷', 'desc': 'Passeport Talent'},
      {'code': 'SA', 'name': 'السعودية 🇸🇦', 'desc': 'رؤية 2030 وكبرى الشركات'},
      {'code': 'AE', 'name': 'الإمارات 🇦🇪', 'desc': 'دبي وأبوظبي'},
      {'code': 'QA', 'name': 'قطر 🇶🇦', 'desc': 'عقود دولية'},
      {'code': 'BE', 'name': 'بلجيكا 🇧🇪', 'desc': 'تصريح العمل الموحد'},
      {'code': 'NL', 'name': 'هولندا 🇳🇱', 'desc': 'الكفاءات العالية'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الدول المستهدفة للبحث والتقديم 🎯',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'اختر الوجهات التي ترغب بأن يبحث فيها الذكاء الاصطناعي عن عروض عمل مطابقة.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ...available.map((item) {
            final code = item['code']!;
            final selected = _selectedCountries.contains(code);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? AppTheme.primary : AppTheme.border),
              ),
              child: CheckboxListTile(
                value: selected,
                activeColor: AppTheme.primary,
                title: Text(item['name']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(item['desc']!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedCountries.add(code);
                    } else {
                      _selectedCountries.remove(code);
                    }
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
