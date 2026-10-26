import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(l10n.t('about_title')),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Banner with Hooded Character Branding Asset (70% dark overlay)
            Stack(
              children: [
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Image.asset(
                    'assets/branding/hooded_hunter.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) => Container(color: AppTheme.surface),
                  ),
                ),
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.bgDark.withValues(alpha: 0.4),
                        AppTheme.bgDark.withValues(alpha: 0.85),
                        AppTheme.bgDark,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.surface,
                          border: Border.all(color: AppTheme.primary, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.35),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.radar_rounded, color: AppTheme.primary, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'akremjobhunter',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              l10n.t('about_version'),
                              style: const TextStyle(fontSize: 12, color: AppTheme.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 2. Body Details
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionCard(
                    title: l10n.t('about_mission_title'),
                    icon: Icons.auto_awesome_rounded,
                    content: l10n.t('about_mission_body'),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: l10n.t('about_grounding_title'),
                    icon: Icons.verified_user_outlined,
                    content: l10n.t('about_grounding_body'),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: l10n.t('about_security_title'),
                    icon: Icons.lock_outline_rounded,
                    content: l10n.t('about_security_body'),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'akremjobhunter • 2026',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted.withValues(alpha: 0.6)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required String content}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
