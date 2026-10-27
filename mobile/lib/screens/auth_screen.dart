import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../l10n/app_localizations.dart';
import 'developer_panel_screen.dart';
import '../widgets/arab_country_picker.dart';
import '../widgets/language_selector.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers for Sign In
  final _loginIdController = TextEditingController();
  final _loginPassController = TextEditingController();
  bool _loginRememberMe = true;
  bool _loginObscure = true;
  bool _loginLoading = false;
  String? _loginError;

  // Controllers for Sign Up
  final _regUsernameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regFullNameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  ArabCountry _selectedArabCountry = getArabCountry('TN');
  int _secretTaps = 0;
  final _regPassController = TextEditingController();
  final _regConfirmPassController = TextEditingController();
  bool _regObscure = true;
  bool _regConfirmObscure = true;
  bool _regLoading = false;
  String? _regError;

  // Password Policy & Strength
  Map<String, dynamic> _policy = {
    'min_length': 8,
    'require_uppercase': true,
    'require_lowercase': true,
    'require_numbers': true,
    'require_special': false,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    try {
      final p = await ApiService.getPasswordPolicy();
      if (mounted) setState(() => _policy = p);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginIdController.dispose();
    _loginPassController.dispose();
    _regUsernameController.dispose();
    _regEmailController.dispose();
    _regFullNameController.dispose();
    _regPhoneController.dispose();
    _regPassController.dispose();
    _regConfirmPassController.dispose();
    super.dispose();
  }

  // Password Strength Calculation
  double _calculateStrength(String pass) {
    if (pass.isEmpty) return 0.0;
    double score = 0.0;
    if (pass.length >= (_policy['min_length'] ?? 8)) score += 0.25;
    if (pass.length >= 12) score += 0.15;
    if (pass.contains(RegExp(r'[A-Z]'))) score += 0.20;
    if (pass.contains(RegExp(r'[a-z]'))) score += 0.15;
    if (pass.contains(RegExp(r'[0-9]'))) score += 0.15;
    if (pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\]~`]'))) score += 0.10;
    return score.clamp(0.0, 1.0);
  }

  Color _getStrengthColor(double strength) {
    if (strength < 0.4) return AppTheme.danger;
    if (strength < 0.7) return AppTheme.warning;
    if (strength < 0.9) return AppTheme.secondary;
    return AppTheme.primary;
  }

  String _getStrengthLabel(double strength, AppLocalizations l10n) {
    if (strength <= 0.0) return '...';
    if (strength < 0.4) return l10n.t('auth_strength_weak');
    if (strength < 0.7) return l10n.t('auth_strength_medium');
    if (strength < 0.9) return l10n.t('auth_strength_strong');
    return l10n.t('auth_strength_very_strong');
  }

  // --- Handlers
  Future<void> _handleLogin() async {
    final id = _loginIdController.text.trim();
    final pass = _loginPassController.text;

    if (id.isEmpty || pass.isEmpty) {
      setState(() => _loginError = 'Please enter both your identifier and password.');
      return;
    }

    setState(() {
      _loginLoading = true;
      _loginError = null;
    });

    try {
      await ApiService.login(
        usernameOrEmail: id,
        password: pass,
        remember: _loginRememberMe,
      );

      if (!mounted) return;
      _navigateToMain();
    } catch (e) {
      setState(() {
        _loginLoading = false;
        _loginError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _handleRegister() async {
    final username = _regUsernameController.text.trim();
    final email = _regEmailController.text.trim();
    final fullName = _regFullNameController.text.trim();
    final pass = _regPassController.text;
    final confirm = _regConfirmPassController.text;

    if (username.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _regError = 'Please fill in all required fields.');
      return;
    }

    if (pass != confirm) {
      setState(() => _regError = 'Passwords do not match.');
      return;
    }

    setState(() {
      _regLoading = true;
      _regError = null;
    });

    try {
      final regRes = await ApiService.register(
        username: username,
        email: email,
        password: pass,
        fullName: fullName.isNotEmpty ? fullName : null,
        countryCode: _selectedArabCountry.code,
        phone: _regPhoneController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _regLoading = false);

      final devCode = regRes['dev_verification_code'] as String?;
      // Prompt email verification (with fallback code if email is unconfigured)
      _showVerificationDialog(email, initialCode: devCode);
    } catch (e) {
      setState(() {
        _regLoading = false;
        _regError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _navigateToMain() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MainShell(
          onDisconnect: () async {
            await ApiService.logout();
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            }
          },
        ),
      ),
    );
  }

  // Verification Dialog
  void _showVerificationDialog(String email, {String? initialCode}) {
    final codeController = TextEditingController(text: initialCode ?? '');
    bool verifying = false;
    String? verifError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: Row(
            children: const [
              Icon(Icons.mark_email_read_outlined, color: AppTheme.primary, size: 24),
              SizedBox(width: 10),
              Text('Verify Email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A 6-digit verification code has been generated for $email.',
                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(letterSpacing: 4, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
              ),
              if (verifError != null) ...[
                const SizedBox(height: 8),
                Text(verifError!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _navigateToMain();
              },
              child: const Text('Skip for now', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: verifying
                  ? null
                  : () async {
                      final code = codeController.text.trim();
                      if (code.length != 6) {
                        setDialogState(() => verifError = 'Enter 6-digit code');
                        return;
                      }
                      setDialogState(() {
                        verifying = true;
                        verifError = null;
                      });
                      try {
                        final nav = Navigator.of(ctx);
                        await ApiService.verifyEmail(code);
                        if (!mounted) return;
                        nav.pop();
                        _navigateToMain();
                      } catch (err) {
                        setDialogState(() {
                          verifying = false;
                          verifError = err.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
              child: verifying
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Verify Account'),
            ),
          ],
        ),
      ),
    );
  }

  // Forgot Password Dialog
  void _showForgotPasswordSheet() {
    final emailController = TextEditingController();
    final tokenController = TextEditingController();
    final newPassController = TextEditingController();
    bool hasToken = false;
    bool processing = false;
    String? statusMsg;
    bool isSuccess = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppTheme.border),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    hasToken ? 'Reset Password' : 'Forgot Password',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Account Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              if (hasToken) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: tokenController,
                  decoration: const InputDecoration(
                    labelText: 'Reset Token',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: newPassController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (statusMsg != null)
                Text(
                  statusMsg!,
                  style: TextStyle(
                    color: isSuccess ? AppTheme.secondary : AppTheme.danger,
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: processing
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        if (email.isEmpty) {
                          setSheetState(() => statusMsg = 'Enter your email');
                          return;
                        }

                        setSheetState(() {
                          processing = true;
                          statusMsg = null;
                        });

                        try {
                          if (!hasToken) {
                            await ApiService.forgotPassword(email);
                            setSheetState(() {
                              processing = false;
                              hasToken = true;
                              isSuccess = true;
                              statusMsg = 'Instructions sent. Enter the token received below.';
                            });
                          } else {
                            final token = tokenController.text.trim();
                            final newPass = newPassController.text;
                            if (token.isEmpty || newPass.isEmpty) {
                              setSheetState(() {
                                processing = false;
                                statusMsg = 'Please enter token and new password';
                              });
                              return;
                            }
                            final nav = Navigator.of(ctx);
                            await ApiService.resetPassword(
                              email: email,
                              token: token,
                              newPassword: newPass,
                            );
                            setSheetState(() {
                              processing = false;
                              isSuccess = true;
                              statusMsg = 'Password reset successful! You can now log in.';
                            });
                            await Future.delayed(const Duration(milliseconds: 1400));
                            if (mounted && ctx.mounted) nav.pop();
                          }
                        } catch (err) {
                          setSheetState(() {
                            processing = false;
                            isSuccess = false;
                            statusMsg = err.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                child: processing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(hasToken ? 'Save New Password' : 'Send Reset Instructions'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setSheetState(() => hasToken = !hasToken),
                child: Text(
                  hasToken ? 'Back to email request' : 'I already have a reset token',
                  style: const TextStyle(color: AppTheme.primary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Server Settings Dialog
  void _showServerConfigDialog() {
    final serverController = TextEditingController(text: ApiService.serverUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Text('Cloud Server URL', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Specify your personal 24/7 backend server URL:',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: serverController,
              decoration: const InputDecoration(
                hintText: 'https://akremjobhunter.onrender.com',
                prefixIcon: Icon(Icons.cloud_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final newUrl = serverController.text.trim();
              if (newUrl.isNotEmpty) {
                await ApiService.saveServerUrl(newUrl);
                _loadPolicy();
              }
              if (mounted && ctx.mounted) nav.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Hooded Character Branding Asset
          Image.asset(
            'assets/branding/hooded_hunter.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: AppTheme.bgDark),
          ),

          // 2. 70% Dark Overlay + Blur Effect
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
            child: Container(
              color: AppTheme.bgDark.withValues(alpha: 0.72),
            ),
          ),

          // 3. Main Content
          SafeArea(
            child: Column(
              children: [
                // Top App Bar / Brand Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.primary, width: 1.5),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/branding/app_badge.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(Icons.radar_rounded, color: AppTheme.primary, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              _secretTaps++;
                              if (_secretTaps >= 5) {
                                _secretTaps = 0;
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeveloperPanelScreen()));
                              }
                            },
                            child: const Text(
                              'akremjobhunter',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => LanguageSelectorSheet.show(context),
                            icon: const Icon(Icons.language_rounded, size: 18, color: AppTheme.primary),
                            label: Text(
                              LanguageController.instance.currentLocale.languageCode.toUpperCase(),
                              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: AppTheme.textMuted),
                            tooltip: 'Server Connection',
                            onPressed: _showServerConfigDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Expanded Auth Container
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 440),
                        decoration: AppTheme.glassCardDecoration(opacity: 0.88, radius: 20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Tab Switcher
                                  Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppTheme.bgDark.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: TabBar(
                                      controller: _tabController,
                                      indicatorSize: TabBarIndicatorSize.tab,
                                      indicator: BoxDecoration(
                                        color: AppTheme.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      labelColor: Colors.black,
                                      unselectedLabelColor: AppTheme.textMuted,
                                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      dividerColor: Colors.transparent,
                                      tabs: [
                                        Tab(text: l10n.t('auth_sign_in')),
                                        Tab(text: l10n.t('auth_create_account')),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Tab Content
                                  AnimatedBuilder(
                                    animation: _tabController,
                                    builder: (context, _) {
                                      return _tabController.index == 0
                                          ? _buildSignInTab(l10n)
                                          : _buildSignUpTab(l10n);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Security Note
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.shield_outlined, size: 14, color: AppTheme.textMuted),
                      SizedBox(width: 6),
                      Text(
                        'Argon2id Hashing  •  JWT Authentication  •  Zero Fake Data',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Sign In View
  Widget _buildSignInTab(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _loginIdController,
          decoration: InputDecoration(
            labelText: l10n.t('auth_username_email'),
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _loginPassController,
          obscureText: _loginObscure,
          decoration: InputDecoration(
            labelText: l10n.t('auth_password'),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_loginObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _loginObscure = !_loginObscure),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _loginRememberMe,
                    activeColor: AppTheme.primary,
                    checkColor: Colors.black,
                    onChanged: (v) => setState(() => _loginRememberMe = v ?? true),
                  ),
                ),
                const SizedBox(width: 8),
                Text(l10n.t('auth_remember_me'), style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
              ],
            ),
            TextButton(
              onPressed: _showForgotPasswordSheet,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(l10n.t('auth_forgot_password'), style: const TextStyle(fontSize: 12.5, color: AppTheme.primary)),
            ),
          ],
        ),
        if (_loginError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.5)),
            ),
            child: Text(
              _loginError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
            ),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _loginLoading ? null : _handleLogin,
          child: _loginLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : Text(l10n.t('auth_sign_in')),
        ),
      ],
    );
  }

  // --- Sign Up View
  Widget _buildSignUpTab(AppLocalizations l10n) {
    final pass = _regPassController.text;
    final strength = _calculateStrength(pass);
    final strengthLabel = _getStrengthLabel(strength, l10n);
    final strengthColor = _getStrengthColor(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _regUsernameController,
          decoration: InputDecoration(
            labelText: l10n.t('auth_username'),
            prefixIcon: const Icon(Icons.alternate_email),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _regEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l10n.t('auth_email'),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _regFullNameController,
          decoration: InputDecoration(
            labelText: l10n.t('auth_full_name'),
            prefixIcon: const Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 14),
        ArabCountryPickerField(
          selectedCountry: _selectedArabCountry,
          onCountryChanged: (c) => setState(() => _selectedArabCountry = c),
          phoneController: _regPhoneController,
          currentLang: LanguageController.instance.currentLocale.languageCode,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _regPassController,
          obscureText: _regObscure,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.t('auth_choose_password'),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_regObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _regObscure = !_regObscure),
            ),
          ),
        ),
        if (pass.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: strength,
                    minHeight: 5,
                    backgroundColor: AppTheme.border,
                    valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                strengthLabel,
                style: TextStyle(color: strengthColor, fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _regConfirmPassController,
          obscureText: _regConfirmObscure,
          decoration: InputDecoration(
            labelText: l10n.t('auth_confirm_password'),
            prefixIcon: const Icon(Icons.check_circle_outline),
            suffixIcon: IconButton(
              icon: Icon(_regConfirmObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _regConfirmObscure = !_regConfirmObscure),
            ),
          ),
        ),
        if (_regError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.5)),
            ),
            child: Text(
              _regError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
            ),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _regLoading ? null : _handleRegister,
          child: _regLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : Text(l10n.t('auth_create_account')),
        ),
      ],
    );
  }
}
