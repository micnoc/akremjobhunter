import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/arab_country_picker.dart';
import '../widgets/language_selector.dart';
import 'developer_panel_screen.dart';
import 'setup_wizard_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onDisconnect;
  const SettingsScreen({super.key, required this.onDisconnect});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  // Settings map

  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  ArabCountry _selectedArabCountry = getArabCountry('TN');
  int _secretTaps = 0;

  final _emailCtrl = TextEditingController();
  final _waPhoneCtrl = TextEditingController();
  final _tgChatCtrl = TextEditingController();

  // Advanced Drawer
  bool _showAdvancedAi = false;
  final _aiKeyCtrl = TextEditingController();

  double _dailyLimit = 20;
  double _minScore = 70;
  bool _enginePaused = false;
  List<String> _targetCountries = [];
  List<String> _allCountries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _waPhoneCtrl.dispose();
    _tgChatCtrl.dispose();
    _aiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await ApiService.getSettings();

      setState(() {

        _fullNameCtrl.text = s['full_name'] ?? '';
        _phoneCtrl.text = s['phone'] ?? '';
        final user = ApiService.currentUser ?? {};
        if (user['country_code'] != null && user['country_code'].toString().isNotEmpty) {
          _selectedArabCountry = getArabCountry(user['country_code'].toString());
        }
        _emailCtrl.text = s['gmail_address'] ?? '';
        _tgChatCtrl.text = s['telegram_chat_id'] ?? '';
        _waPhoneCtrl.text = s['whatsapp_phone'] ?? '';

        _dailyLimit = (s['daily_limit'] as num?)?.toDouble() ?? 20;
        _minScore = (s['min_match_score'] as num?)?.toDouble() ?? 70;
        _enginePaused = s['engine_paused'] == true;

        _targetCountries = (s['target_countries'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        _allCountries = (s['all_countries'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load settings: $e')));
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'full_name': _fullNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'gmail_address': _emailCtrl.text.trim(),
        'telegram_chat_id': _tgChatCtrl.text.trim(),
        'whatsapp_phone': _waPhoneCtrl.text.trim(),
        'daily_limit': _dailyLimit.toInt(),
        'min_match_score': _minScore.toInt(),
        'engine_paused': _enginePaused,
        'target_countries': _targetCountries,
      };

      if (_aiKeyCtrl.text.isNotEmpty) {
        payload['ai_api_key'] = _aiKeyCtrl.text.trim();
      }

      await ApiService.saveSettings(payload);
      try {
        await ApiService.updateProfile(
          fullName: _fullNameCtrl.text.trim(),
          countryCode: _selectedArabCountry.code,
          phone: _phoneCtrl.text.trim(),
        );
      } catch (_) {}

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('set_saved')), backgroundColor: const Color(0xFF10B981)),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testIntegration(String target) async {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.t('loading')} ($target)...')),
    );
    try {
      final res = await ApiService.testIntegration(target);
      if (mounted) {
        final ok = res['ok'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'OK'),
            backgroundColor: ok ? const Color(0xFF10B981) : AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _showGmailConnectDialog() {
    final tempCtrl = TextEditingController(text: _emailCtrl.text);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: const [
                Icon(Icons.mail_rounded, color: Colors.redAccent, size: 28),
                SizedBox(width: 10),
                Text('ربط حساب Gmail', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'أدخل بريدك الإلكتروني. يقوم النظام بالربط وتأمين إرسال طلبات العمل ومتابعة الردود تلقائياً.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: tempCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'عنوان البريد الإلكتروني',
                hintText: 'yourname@gmail.com',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                if (tempCtrl.text.trim().isNotEmpty) {
                  setState(() => _emailCtrl.text = tempCtrl.text.trim());
                  Navigator.pop(ctx);
                  _save();
                }
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('تأكيد وحفظ الربط'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            ),
          ],
        ),
      ),
    );
  }

  void _showWhatsAppConnectDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: const [
                Icon(Icons.chat_bubble_rounded, color: Color(0xFF10B981), size: 28),
                SizedBox(width: 10),
                Text('تفعيل إشعارات واتساب 💬', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'اختر دولتك ورقم هاتفك لتلقي دعوات المقابلات وتحديثات القبول فورياً عبر واتساب بدون أي تعقيد.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            ArabCountryPickerField(
              selectedCountry: _selectedArabCountry,
              onCountryChanged: (c) => setState(() => _selectedArabCountry = c),
              phoneController: _phoneCtrl,
              currentLang: LanguageController.instance.currentLocale.languageCode,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                final fullNum = '${_selectedArabCountry.dialCode}${_phoneCtrl.text.trim()}';
                setState(() => _waPhoneCtrl.text = fullNum);
                Navigator.pop(ctx);
                _save();
                _testIntegration('whatsapp');
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('تفعيل وتجربة الإرسال'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            ),
          ],
        ),
      ),
    );
  }

  void _openTelegramLink() async {
    const url = 'https://t.me/akremjobhunter_bot';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        setState(() => _tgChatCtrl.text = 'connected');
        _save();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح تيليغرام مباشرة')),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    final curCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('تغيير كلمة السر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: curCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'كلمة السر الحالية'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'كلمة السر الجديدة'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.changePassword(
                  currentPassword: curCtrl.text,
                  newPassword: newCtrl.text,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تغيير كلمة السر بنجاح ✅'), backgroundColor: Color(0xFF10B981)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ApiService.currentUser ?? {};
    final username = user['username'] ?? 'Candidate';
    final email = user['email'] ?? '';
    final fullName = user['full_name'] ?? _fullNameCtrl.text;
    final role = (user['role'] ?? 'USER').toString().toUpperCase();
    final isVerified = user['is_verified'] == true;

    final gmailConnected = _emailCtrl.text.trim().isNotEmpty;
    final waConnected = _waPhoneCtrl.text.trim().isNotEmpty;
    final tgConnected = _tgChatCtrl.text.trim().isNotEmpty;

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(l10n.t('set_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_rounded, color: AppTheme.primary),
            tooltip: l10n.t('save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Developer Panel Quick Access for Admins
          if (role == 'ADMIN') ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF0D9488)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: ListTile(
                leading: const Text('⚡', style: TextStyle(fontSize: 26)),
                title: const Text('لوحة تحكم المطورين والإدارة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('مرصد المترشحين، السير الذاتية، وإحصائيات السحابة 24/7', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeveloperPanelScreen()));
                },
              ),
            ),
          ],

          // 1. Official Character Branding & Profile Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Official Character Avatar
                    Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.primary, width: 2),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/branding/app_badge.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: AppTheme.primary.withValues(alpha: 0.2),
                                child: const Icon(Icons.person, color: AppTheme.primary, size: 32),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: Color(0xFF0F172A), shape: BoxShape.circle),
                            child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  fullName.isNotEmpty ? fullName : username,
                                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(_selectedArabCountry.flag, style: const TextStyle(fontSize: 18)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(email, style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isVerified ? 'حساب موثق ومفعل ✅' : 'بانتظار التأكيد',
                              style: const TextStyle(color: AppTheme.primary, fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _showChangePasswordDialog,
                      icon: const Icon(Icons.vpn_key_outlined, size: 16, color: AppTheme.primary),
                      label: Text(l10n.t('set_change_pass'), style: const TextStyle(color: AppTheme.primary, fontSize: 12.5)),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SetupWizardScreen()));
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF38BDF8)),
                      label: const Text('معالج الإعداد 🚀', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Language Selection Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.language_rounded, color: AppTheme.primary, size: 22),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('set_language'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                        Text(
                          LanguageController.instance.currentLocale.languageCode == 'ar'
                              ? 'العربية (RTL) 🇹🇳'
                              : (LanguageController.instance.currentLocale.languageCode == 'fr'
                                  ? 'Français 🇫🇷'
                                  : 'English 🇬🇧'),
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: () => LanguageSelectorSheet.show(context),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  child: const Text('تغيير / Change', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. CANDIDATE PROFILE & COUNTRY SECTION
          _buildSectionHeader('بيانات وتوقيع المترشح 👤'),
          TextField(
            controller: _fullNameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'الاسم الكامل الرسمي (يظهر في رسائل التحفيز)'),
          ),
          const SizedBox(height: 12),
          ArabCountryPickerField(
            selectedCountry: _selectedArabCountry,
            onCountryChanged: (c) => setState(() => _selectedArabCountry = c),
            phoneController: _phoneCtrl,
            currentLang: LanguageController.instance.currentLocale.languageCode,
          ),
          const SizedBox(height: 24),

          // 4. GUIDED ZERO-TECHNICAL INTEGRATION CARDS
          _buildSectionHeader('قنوات التواصل والربط السحابي ⚡'),
          const Text(
            'ربط موجه ومبسط دون الحاجة لأي مفاتيح تقنية أو كلمات سر بريد معقدة.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),

          // Gmail Card
          _buildIntegrationCard(
            title: 'Gmail - بريد إرسال ومتابعة الترشحات',
            subtitle: gmailConnected ? _emailCtrl.text : 'غير متصل (اضغط للربط الموجه)',
            icon: Icons.mail_rounded,
            iconColor: Colors.redAccent,
            connected: gmailConnected,
            onAction: _showGmailConnectDialog,
            actionLabel: gmailConnected ? 'تغيير' : 'ربط Gmail',
          ),
          const SizedBox(height: 12),

          // WhatsApp Card
          _buildIntegrationCard(
            title: 'WhatsApp - تنبيهات المقابلات والقبول',
            subtitle: waConnected ? _waPhoneCtrl.text : 'تفعيل إشعارات الواتساب الفورية',
            icon: Icons.chat_bubble_rounded,
            iconColor: const Color(0xFF10B981),
            connected: waConnected,
            onAction: _showWhatsAppConnectDialog,
            actionLabel: waConnected ? 'تحديث' : 'تفعيل واتساب',
          ),
          const SizedBox(height: 12),

          // Telegram Card
          _buildIntegrationCard(
            title: 'Telegram - بوت الإشعارات السحابي',
            subtitle: tgConnected ? 'البوت متصل ويعمل 24/7' : 'ربط بضغطة زر عبر تطبيق تيليغرام',
            icon: Icons.send_rounded,
            iconColor: const Color(0xFF38BDF8),
            connected: tgConnected,
            onAction: _openTelegramLink,
            actionLabel: tgConnected ? 'إعادة الفحص' : 'فتح البوت',
          ),
          const SizedBox(height: 12),

          // AI Engine Card (Zero API Key)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology_rounded, color: Color(0xFFF59E0B), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('محرك الذكاء الاصطناعي الذاتي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5)),
                          SizedBox(height: 2),
                          Text('يعمل محلياً وسحابياً 100% مجاناً بدون الحاجة لأي API Key', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('نشط 24/7', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _testIntegration('ai'),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('اختبار المحرك', style: TextStyle(fontSize: 12)),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _showAdvancedAi = !_showAdvancedAi),
                      child: Text(_showAdvancedAi ? 'إخفاء الإعداد المتقدم' : 'ترقية لـ Gemini Pro (اختياري)', style: const TextStyle(fontSize: 11.5, color: Color(0xFF38BDF8))),
                    ),
                  ],
                ),
                if (_showAdvancedAi) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _aiKeyCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'مفتاح Gemini API Key (اختياري تماماً)',
                      hintText: 'AIzaSy...',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 5. JOB QUOTAS & COUNTRIES
          _buildSectionHeader('إعدادات البحث والدول المستهدفة 🌍'),
          Text('الحصة اليومية القصوى: ${_dailyLimit.toInt()} ترشح / يوم', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          Slider(
            value: _dailyLimit,
            min: 5,
            max: 50,
            divisions: 9,
            activeColor: AppTheme.primary,
            label: '${_dailyLimit.toInt()}',
            onChanged: (val) => setState(() => _dailyLimit = val),
          ),
          const SizedBox(height: 12),
          Text('الحد الأدنى لنسبة التطابق: ${_minScore.toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          Slider(
            value: _minScore,
            min: 50,
            max: 95,
            divisions: 9,
            activeColor: const Color(0xFF10B981),
            label: '${_minScore.toInt()}%',
            onChanged: (val) => setState(() => _minScore = val),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('الدول المشمولة بالبحث 🌐'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _allCountries.map((c) {
              final sel = _targetCountries.contains(c);
              return FilterChip(
                selected: sel,
                label: Text(c),
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: sel ? Colors.black : Colors.white70,
                  fontSize: 11,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _targetCountries.add(c);
                    } else {
                      _targetCountries.remove(c);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Save Button
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? '...' : l10n.t('save')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 16),

          // Sign Out Button
          TextButton.icon(
            onPressed: widget.onDisconnect,
            icon: const Icon(Icons.logout_rounded, color: AppTheme.danger, size: 16),
            label: Text(l10n.t('set_sign_out'), style: const TextStyle(color: AppTheme.danger)),
          ),
          const SizedBox(height: 20),

          // Secret tap footer
          GestureDetector(
            onTap: () {
              _secretTaps++;
              if (_secretTaps >= 5) {
                _secretTaps = 0;
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeveloperPanelScreen()));
              }
            },
            child: const Center(
              child: Text(
                'akremjobhunter Cloud v3.0.0 (Tap 5x for Developer Mode)',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white70),
      ),
    );
  }

  Widget _buildIntegrationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool connected,
    required VoidCallback onAction,
    required String actionLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: connected ? const Color(0xFF10B981).withValues(alpha: 0.4) : Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: connected ? const Color(0xFF10B981) : AppTheme.textMuted, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: connected ? const Color(0xFF10B981) : AppTheme.primary,
              side: BorderSide(color: connected ? const Color(0xFF10B981) : AppTheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(actionLabel, style: const TextStyle(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}
