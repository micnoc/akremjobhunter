import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'about_screen.dart';
import 'developer_panel_screen.dart';
import '../widgets/arab_country_picker.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_selector.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onDisconnect;
  const SettingsScreen({super.key, required this.onDisconnect});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic> _settings = {};

  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  ArabCountry _selectedArabCountry = getArabCountry('TN');
  int _secretTaps = 0;
  final _emailCtrl = TextEditingController();
  final _gmailPassCtrl = TextEditingController();
  final _aiKeyCtrl = TextEditingController();
  final _tgTokenCtrl = TextEditingController();
  final _tgChatCtrl = TextEditingController();
  final _waPhoneCtrl = TextEditingController();
  final _waKeyCtrl = TextEditingController();

  double _dailyLimit = 20;
  double _minScore = 70;
  bool _enginePaused = false;
  List<String> _targetCountries = [];
  List<String> _allCountries = [];

  List<String> _aiModels = [];
  String? _selectedModel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await ApiService.getSettings();
      final models = await ApiService.getAiModels();

      setState(() {
        _settings = s;
        _aiModels = models;

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

        _selectedModel = s['ai_model'];
        if (_selectedModel != null && !_aiModels.contains(_selectedModel)) {
          _aiModels.add(_selectedModel!);
        }

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
        'ai_model': _selectedModel ?? '',
      };

      if (_gmailPassCtrl.text.isNotEmpty) payload['gmail_app_password'] = _gmailPassCtrl.text;
      if (_aiKeyCtrl.text.isNotEmpty) payload['ai_api_key'] = _aiKeyCtrl.text;
      if (_tgTokenCtrl.text.isNotEmpty) payload['telegram_bot_token'] = _tgTokenCtrl.text;
      if (_waKeyCtrl.text.isNotEmpty) payload['callmebot_apikey'] = _waKeyCtrl.text;

      await ApiService.saveSettings(payload);
      try {
        await ApiService.updateProfile(
          fullName: _fullNameCtrl.text.trim(),
          countryCode: _selectedArabCountry.code,
          phone: _phoneCtrl.text.trim(),
        );
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved securely on Cloud Server')));
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

  Future<void> _test(String target) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Testing $target integration...')));
      final res = await ApiService.testIntegration(target);
      if (mounted) {
        final ok = res['ok'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ok ? AppTheme.secondary : AppTheme.danger,
            content: Text('$target: ${res['message']}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Test failed: $e')));
      }
    }
  }

  void _showChangePasswordDialog() {
    final sm = ScaffoldMessenger.of(context);
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool saving = false;
    String? err;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: const Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password', prefixIcon: Icon(Icons.lock_outline)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password', prefixIcon: Icon(Icons.vpn_key_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password', prefixIcon: Icon(Icons.check_circle_outline)),
              ),
              if (err != null) ...[
                const SizedBox(height: 10),
                Text(err!, style: const TextStyle(color: AppTheme.danger, fontSize: 12.5)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (newCtrl.text != confirmCtrl.text) {
                        setDialogState(() => err = 'Passwords do not match');
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        err = null;
                      });
                      try {
                        await ApiService.changePassword(
                          currentPassword: currentCtrl.text,
                          newPassword: newCtrl.text,
                        );
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          sm.showSnackBar(
                            const SnackBar(content: Text('Password updated successfully')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          err = e.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final gmailIsSet = (_settings['gmail_app_password'] as Map<String, dynamic>?)?['is_set'] == true;
    final aiIsSet = (_settings['ai_api_key'] as Map<String, dynamic>?)?['is_set'] == true;
    final tgIsSet = (_settings['telegram_bot_token'] as Map<String, dynamic>?)?['is_set'] == true;
    final waIsSet = (_settings['callmebot_apikey'] as Map<String, dynamic>?)?['is_set'] == true;

    final user = ApiService.currentUser ?? {};
    final username = user['username'] ?? 'Candidate';
    final email = user['email'] ?? '';
    final role = (user['role'] ?? 'ADMIN').toString().toUpperCase();
    final isVerified = user['is_verified'] == true;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('set_title')),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_rounded, color: AppTheme.primary),
            tooltip: 'Save Settings',
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0D9488)],
                ),
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
          // 1. User Profile & Security Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppTheme.glassCardDecoration(radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                      child: Text(
                        username.isNotEmpty ? username[0].toUpperCase() : 'A',
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  username,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  role,
                                  style: const TextStyle(color: AppTheme.primary, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(email, style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    Icon(
                      isVerified ? Icons.verified_rounded : Icons.pending_outlined,
                      color: isVerified ? AppTheme.secondary : AppTheme.warning,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: AppTheme.border, height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _showChangePasswordDialog,
                      icon: const Icon(Icons.vpn_key_outlined, size: 16, color: AppTheme.primary),
                      label: Text(l10n.t('set_change_pass'), style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen()));
                      },
                      icon: const Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
                      label: Text(l10n.t('set_about'), style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Candidate Identity
          // Language Selection Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: AppTheme.glassCardDecoration(radius: 14),
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
                        Text(
                          l10n.t('set_language'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
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
                  child: const Text('Change / تغيير', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildSection(l10n.t('set_candidate')),
          TextField(controller: _fullNameCtrl, decoration: const InputDecoration(labelText: 'Full Name (Signature)')),
          const SizedBox(height: 12),
          ArabCountryPickerField(
            selectedCountry: _selectedArabCountry,
            onCountryChanged: (c) => setState(() => _selectedArabCountry = c),
            phoneController: _phoneCtrl,
            currentLang: LanguageController.instance.currentLocale.languageCode,
          ),
          const SizedBox(height: 24),

          // Gmail Bridge
          _buildSection(l10n.t('set_gmail')),
          TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Gmail Address')),
          const SizedBox(height: 10),
          TextField(
            controller: _gmailPassCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Gmail App Password',
              hintText: gmailIsSet ? '•••••••••••••••• (Encrypted on Server)' : 'Enter 16-char App Password',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _test('gmail'),
            icon: const Icon(Icons.sync_rounded, size: 16),
            label: const Text('Test Gmail Connection'),
          ),
          const SizedBox(height: 24),

          // AI Engine
          _buildSection(l10n.t('set_ai')),
          TextField(
            controller: _aiKeyCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Gemini API Key',
              hintText: aiIsSet ? '•••••••••••••••• (Encrypted on Server)' : 'AIzaSy...',
            ),
          ),
          const SizedBox(height: 10),
          if (_aiModels.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedModel,
              decoration: const InputDecoration(labelText: 'AI Model (Auto-selects Pro by default)'),
              items: _aiModels.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (val) => setState(() => _selectedModel = val),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: () => _test('ai'),
            icon: const Icon(Icons.smart_toy_outlined, size: 16),
            label: const Text('Test AI Engine'),
          ),
          const SizedBox(height: 24),

          // Telegram
          _buildSection(l10n.t('set_telegram')),
          TextField(
            controller: _tgTokenCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Telegram Bot Token',
              hintText: tgIsSet ? '•••••••••••••••• (Encrypted on Server)' : '123456:ABC-DEF...',
            ),
          ),
          const SizedBox(height: 10),
          TextField(controller: _tgChatCtrl, decoration: const InputDecoration(labelText: 'Telegram Chat ID')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _test('telegram'),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Test Telegram Notification'),
          ),
          const SizedBox(height: 24),

          // WhatsApp
          _buildSection(l10n.t('set_whatsapp')),
          TextField(controller: _waPhoneCtrl, decoration: const InputDecoration(labelText: 'WhatsApp Phone (+CountryCode...)')),
          const SizedBox(height: 10),
          TextField(
            controller: _waKeyCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'CallMeBot API Key',
              hintText: waIsSet ? '•••••••••••••••• (Encrypted on Server)' : 'Key from CallMeBot',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _test('whatsapp'),
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: const Text('Test WhatsApp Notification'),
          ),
          const SizedBox(height: 24),

          // Engine Controls
          _buildSection(l10n.t('set_engine')),
          SwitchListTile(
            title: const Text('Pause Autonomous Engine', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text('Suspends automated discovering, sending, and email checking.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            value: _enginePaused,
            activeTrackColor: AppTheme.warning,
            onChanged: (val) => setState(() => _enginePaused = val),
          ),
          const SizedBox(height: 14),
          Text('Daily Application Throttle: ${_dailyLimit.toInt()} / 20 apps', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          Slider(
            value: _dailyLimit,
            min: 1,
            max: 20,
            divisions: 19,
            activeColor: AppTheme.primary,
            label: '${_dailyLimit.toInt()}',
            onChanged: (val) => setState(() => _dailyLimit = val),
          ),
          const SizedBox(height: 14),
          Text('Minimum Match Score: ${_minScore.toInt()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          Slider(
            value: _minScore,
            min: 50,
            max: 95,
            divisions: 9,
            activeColor: AppTheme.secondary,
            label: '${_minScore.toInt()}%',
            onChanged: (val) => setState(() => _minScore = val),
          ),
          const SizedBox(height: 24),

          // Target Countries
          _buildSection(l10n.t('set_countries')),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _allCountries.map((c) {
              final sel = _targetCountries.contains(c);
              return FilterChip(
                selected: sel,
                label: Text(c),
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(color: sel ? Colors.black : Colors.white70, fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal),
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

          // Save button
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? '...' : l10n.t('save')),
          ),
          const SizedBox(height: 16),

          // Log Out / Disconnect
          TextButton.icon(
            onPressed: widget.onDisconnect,
            icon: const Icon(Icons.logout_rounded, color: AppTheme.danger, size: 16),
            label: Text(l10n.t('set_sign_out'), style: TextStyle(color: AppTheme.danger)),
          ),
          const SizedBox(height: 20),
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

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.1),
      ),
    );
  }
}
