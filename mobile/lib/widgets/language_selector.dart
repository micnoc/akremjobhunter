import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class LanguageSelectorSheet extends StatelessWidget {
  const LanguageSelectorSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppTheme.border),
      ),
      builder: (ctx) => const LanguageSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCode = LanguageController.instance.currentLocale.languageCode;

    final options = [
      {'code': 'ar', 'name': 'العربية', 'sub': 'Arabic (RTL)', 'flag': '🇹🇳'},
      {'code': 'fr', 'name': 'Français', 'sub': 'French', 'flag': '🇫🇷'},
      {'code': 'en', 'name': 'English', 'sub': 'English (Default)', 'flag': '🇬🇧'},
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: const [
                Icon(Icons.language_rounded, color: AppTheme.primary, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Language / Langue / اللغة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...options.map((opt) {
              final isSelected = opt['code'] == currentCode;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Text(opt['flag']!, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      opt['name']!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      opt['sub']!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary)
                        : null,
                    onTap: () async {
                      await LanguageController.instance.setLanguage(opt['code']!);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
