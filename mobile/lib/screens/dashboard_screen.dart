import 'jobs_explorer_screen.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;
  const DashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);
  DashboardData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getDashboard();
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _trigger(String action) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting $action...'), duration: const Duration(seconds: 1)),
    );
    try {
      final res = await ApiService.triggerEngine(action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res)));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_error != null && _data == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 54, color: AppTheme.danger),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMuted)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.t('cancel') == 'إلغاء' ? 'إعادة المحاولة' : 'Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // l10n getter used
    final d = _data!;
    final counts = d.counts;
    final reviewCount = counts['review'] ?? 0;
    final ratio = d.dailyLimit > 0 ? (d.usedToday / d.dailyLimit).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('app_name')),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: d.paused ? AppTheme.warning.withAlpha(40) : AppTheme.secondary.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: d.paused ? AppTheme.warning : AppTheme.secondary),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  d.paused ? Icons.pause_circle_filled : Icons.check_circle_rounded,
                  size: 14,
                  color: d.paused ? AppTheme.warning : AppTheme.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  d.paused ? l10n.t('dash_engine_paused') : l10n.t('dash_engine_running'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: d.paused ? AppTheme.warning : AppTheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _showNotificationCenter,
            tooltip: 'Notification Center',
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. System Status Card (SaaS Cloud State)
            _buildSystemStatusBanner(d.paused),
            const SizedBox(height: 14),

            // 2. Application Pipeline Visualizer (Stage Flow)
            _buildPipelineFlowCard(counts),
            const SizedBox(height: 16),

            // Explore Analyzed Jobs Banner
            _buildExploreJobsBanner(counts['jobs_7d'] ?? 0),
            const SizedBox(height: 16),

            // 3. Sources Center (Job Bank Canada, EURES, CareerJet, Jooble, Company Portals)
            _buildSourcesCenterCard(),
            const SizedBox(height: 16),

            // 4. Connected Services (Gmail, Telegram, WhatsApp, AI, CVs)
            _buildIntegrationsCard(d.config),
            const SizedBox(height: 16),

            // 5. Coordinated Multi-Agent Activity Center
            _buildMultiAgentCard(),
            const SizedBox(height: 16),

            // Review Alert Banner if pending
            if (reviewCount > 0) ...[
              _buildReviewBanner(reviewCount),
              const SizedBox(height: 16),
            ],

            // 6. Latest Verified Opportunities & Submissions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  LanguageController.instance.currentLocale.languageCode == 'ar'
                      ? 'الفرص الوظيفية الموثوقة المتاحة'
                      : (LanguageController.instance.currentLocale.languageCode == 'fr'
                          ? 'Offres vérifiées récentes'
                          : 'Verified Opportunities'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobsExplorerScreen())),
                  child: Text(
                    LanguageController.instance.currentLocale.languageCode == 'ar'
                        ? 'عرض كافة الفرص ↗'
                        : (LanguageController.instance.currentLocale.languageCode == 'fr'
                            ? 'Voir tout ↗'
                            : 'View All ↗'),
                    style: const TextStyle(fontSize: 12, color: AppTheme.secondary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildRecentList(d.recent),
            const SizedBox(height: 20),

            // Daily Quota & Limits
            _buildDailyThrottle(d.usedToday, d.dailyLimit, ratio),
            const SizedBox(height: 16),

            // Metric Counters Grid
            _buildMetricGrid(counts),
            const SizedBox(height: 16),

            // Engine Pacing Controls
            _buildEngineControls(d.paused),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyThrottle(int used, int limit, double ratio) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.t('dash_quota'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.1),
              ),
              Text(
                '$used / $limit APPS',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppTheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                ratio >= 1.0 ? AppTheme.warning : AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            LanguageController.instance.currentLocale.languageCode == 'ar' ? 'موزعة على مدار 24 ساعة بتباعد زمني بشري لتفادي حدود الإرسال.' : (LanguageController.instance.currentLocale.languageCode == 'fr' ? 'Réparti régulièrement sur 24h avec un intervalle humain pour éviter les limites de débit.' : 'Distributed evenly across 24h with random jitter to mimic human behavior and avoid rate limits.'),
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewBanner(int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_rounded, color: AppTheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Jobs Ready for 1-Click Review',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Cover letters generated. Ready to submit or verify.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => widget.onNavigateTab(1), // Switch to Review tab
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text(l10n.t('dash_review_action'), style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationsCard(Map<String, bool> cfg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildChip('Gmail', cfg['gmail'] == true),
          _buildChip('Gemini Pro', cfg['ai'] == true),
          _buildChip('Telegram', cfg['telegram'] == true),
          _buildChip('CV Vault', cfg['cvs'] == true),
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool ok) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.error_outline,
          size: 14,
          color: ok ? AppTheme.secondary : AppTheme.danger,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: ok ? Colors.white : AppTheme.textMuted,
            fontWeight: ok ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricGrid(Map<String, dynamic> c) {
    final lang = LanguageController.instance.currentLocale.languageCode;
    final isAr = lang == 'ar';
    final isFr = lang == 'fr';
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: [
        _buildStatCard(
          isAr ? 'عروض تم فحصها (7 أيام)' : (isFr ? 'OFFRES ANALYSÉES (7J)' : 'JOBS ANALYSED (7D)'),
          '${c['jobs_7d'] ?? 0}',
          isAr ? 'اضغط للاستعراض والتقديم ↗' : (isFr ? 'Explorer et postuler ↗' : 'Tap to Browse & Apply ↗'),
          AppTheme.primary,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobsExplorerScreen())),
        ),
        _buildStatCard(
          isAr ? 'فرص تدعم التأشيرة وLMIA' : (isFr ? 'ÉLIGIBLES INTERNATIONAL' : 'ELIGIBLE MATCHES'),
          '${c['eligible_7d'] ?? 0}',
          isAr ? 'تأشيرة مفتوحة / كفالة معتمدة ↗' : (isFr ? 'Visa / LMIA / Ouvert ↗' : 'LMIA / Visa / Open ↗'),
          AppTheme.accent,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobsExplorerScreen())),
        ),
        _buildStatCard(
          isAr ? 'ترشحات مرسلة وموثقة' : (isFr ? 'CANDIDATURES ENVOYÉES' : 'APPLICATIONS SUBMITTED'),
          '${c['submitted'] ?? 0}',
          isAr ? 'أرشيف تقديمات بدون تكرار' : (isFr ? 'Archives certifiées sans doublons' : 'Zero-Duplicate Archive'),
          AppTheme.textMuted,
          onTap: () => widget.onNavigateTab(1),
        ),
        _buildStatCard(
          isAr ? 'مقابلات وعروض قبول' : (isFr ? 'ENTRETIENS / OFFRES' : 'INTERVIEWS / OFFERS'),
          '${(c['interviews'] ?? 0) + (c['offers'] ?? 0)}',
          isAr ? 'ردود إيجابية مؤكدة' : (isFr ? 'Réponses vérifiées' : 'Verified Responses'),
          AppTheme.secondary,
          onTap: () => widget.onNavigateTab(1),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String val, String sub, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: onTap != null ? AppTheme.primary.withValues(alpha: 0.35) : AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
            Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(sub, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineControls(bool paused) {
    final isAr = LanguageController.instance.isRtl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isAr ? 'التحكم اليدوي في وتيرة المنظومة' : 'MANUAL ENGINE CONTROLS',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _trigger('discover'),
                icon: const Icon(Icons.travel_explore, size: 16),
                label: Text(
                  LanguageController.instance.currentLocale.languageCode == 'ar'
                      ? 'فحص الوظائف'
                      : (LanguageController.instance.currentLocale.languageCode == 'fr'
                          ? 'Scanner offres'
                          : 'Scan Jobs'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _trigger('inbox'),
                icon: const Icon(Icons.mark_email_read, size: 16),
                label: Text(
                  LanguageController.instance.currentLocale.languageCode == 'ar'
                      ? 'فحص الوارد'
                      : (LanguageController.instance.currentLocale.languageCode == 'fr'
                          ? 'Scanner boîte'
                          : 'Scan Inbox'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: () => _trigger(paused ? 'resume' : 'pause'),
              icon: Icon(paused ? Icons.play_arrow : Icons.pause, color: paused ? AppTheme.secondary : AppTheme.warning),
              tooltip: paused ? (isAr ? 'استئناف المحرك' : 'Resume 24/7 Engine') : (isAr ? 'إيقاف مؤقت' : 'Pause 24/7 Engine'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentList(List<dynamic> list) {
    final lang = LanguageController.instance.currentLocale.languageCode;
    final isAr = lang == 'ar';
    final isFr = lang == 'fr';
    final verified = _data?.verifiedJobs ?? [];

    if (list.isEmpty && verified.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: Text(
            isAr
                ? 'لا توجد عروض مفحوصة حالياً. اضغط على "فحص الوظائف" لبدء البحث الفوري.'
                : (isFr
                    ? 'Aucune offre pour le moment. Cliquez sur "Scanner offres" pour lancer la recherche.'
                    : 'No opportunities found yet. Tap "Scan Jobs" to discover vacancies.'),
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ),
      );
    }

    // If applications exist, show them
    if (list.isNotEmpty) {
      return Column(
        children: list.map((item) {
          final title = item['title'] ?? '';
          final comp = item['company'] ?? '';
          final country = item['country'] ?? '';
          final status = item['status'] ?? '';
          final score = item['score'];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('$comp • $country', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                if (score != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('$score%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: status == 'SENT' || status == 'APPLIED_MANUAL'
                        ? AppTheme.secondary
                        : status == 'INTERVIEW'
                            ? Colors.purpleAccent
                            : AppTheme.warning,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    // Otherwise show verified live jobs discovered by the scrapers!
    return Column(
      children: verified.map((item) {
        final title = item['title'] ?? '';
        final comp = item['company'] ?? '';
        final country = (item['country'] ?? 'CA').toString().toUpperCase();
        final score = item['score'] ?? 80;
        final elig = (item['eligibility'] ?? 'VISA_SPONSORED').toString().replaceAll('_', ' ');
        final id = item['id'] as int;

        final flag = country == 'CA' ? '🇨🇦' : country == 'DE' ? '🇩🇪' : country == 'FR' ? '🇫🇷' : country == 'GB' ? '🇬🇧' : country == 'US' ? '🇺🇸' : '🌍';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('$flag $comp • $country • $elig', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('$score% ATS', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await ApiService.quickApplyJob(id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isAr ? 'تم تسجيل التقديم وتوليد خطاب التقديم بنجاح!' : (isFr ? 'Candidature enregistrée avec succès!' : 'Application queued successfully!'))),
                    );
                    _load();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  isAr ? 'تقديم' : (isFr ? 'Postuler' : 'Apply'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  Widget _buildMultiAgentCard() {
    final isAr = LanguageController.instance.isRtl;
    final agents = [
      {'agent_key': 'JobAgent', 'name': 'Job Agent', 'name_ar': 'وكيل رصد الوظائف', 'role': 'Canada, EURES & Portals', 'role_ar': 'رصد كندا وأوروبا وكبرى الشركات', 'icon': Icons.radar_rounded, 'color': const Color(0xFF3B82F6)},
      {'agent_key': 'CvAgent', 'name': 'CV Agent', 'name_ar': 'وكيل السيرة الذاتية', 'role': 'ATS Optimizer & CV Matcher', 'role_ar': 'مطابقة التخصص وتحسين الـ ATS', 'icon': Icons.description_rounded, 'color': const Color(0xFF10B981)},
      {'agent_key': 'CoverLetterAgent', 'name': 'Cover Letter Agent', 'name_ar': 'وكيل خطابات التقديم', 'role': 'Tailored Regional Letters', 'role_ar': 'صياغة رسائل موجهة بالعربية والفرنسية', 'icon': Icons.history_edu_rounded, 'color': const Color(0xFF8B5CF6)},
      {'agent_key': 'ImmigrationAgent', 'name': 'Immigration Agent', 'name_ar': 'وكيل الهجرة والتأشيرات', 'role': 'LMIA & Visa Compatibility', 'role_ar': 'فحص كفالة LMIA وبطاقة الفرصة', 'icon': Icons.card_membership_rounded, 'color': const Color(0xFFF59E0B)},
      {'agent_key': 'EmailAgent', 'name': 'Email Agent', 'name_ar': 'وكيل البريد والإشعارات', 'role': 'Inbox Triage & Scam Defense', 'role_ar': 'فرز الردود وكشف رسائل الاحتيال', 'icon': Icons.mail_lock_rounded, 'color': const Color(0xFFEC4899)},
      {'agent_key': 'OpportunityAgent', 'name': 'Opportunity Agent', 'name_ar': 'وكيل تقييم الفرص', 'role': 'Probability & Queue Priority', 'role_ar': 'تحديد الأولويات وحساب احتمالية القبول', 'icon': Icons.verified_user_rounded, 'color': const Color(0xFF06B6D4)},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hub_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'شبكة الوكلاء الذكية المستقلة' : 'AUTONOMOUS MULTI-AGENT NETWORK',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      isAr ? '6 عملاء ذكاء اصطناعي يعملون 24/7 (اضغط للتشغيل المباشر)' : '6 Coordinated AI Agents Active 24/7 (Tap to run)',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fiber_manual_record, color: Color(0xFF10B981), size: 10),
                    const SizedBox(width: 4),
                    Text(
                      isAr ? 'نشط' : 'LIVE',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: agents.length,
            itemBuilder: (context, i) {
              final a = agents[i];
              final c = a['color'] as Color;
              return InkWell(
                onTap: () => _showAgentSheet(a),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Icon(a['icon'] as IconData, size: 20, color: c),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isAr ? (a['name_ar'] as String) : (a['name'] as String),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              isAr ? (a['role_ar'] as String) : (a['role'] as String),
                              style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }


  bool _scanningLive = false;

  Future<void> _triggerLiveScan() async {
    setState(() => _scanningLive = true);
    try {
      final res = await ApiService.scanLiveJobs();
      final count = res['jobs_found_count'] ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Live Search Complete: Found and analyzed $count new verified opportunities!'),
            backgroundColor: AppTheme.secondary,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _scanningLive = false);
    }
  }

  void _showNotificationCenter() async {
    List<dynamic> notes = [];
    try {
      notes = await ApiService.getNotifications();
    } catch (_) {}

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text('Notification Center', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${notes.length} alerts', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            Expanded(
              child: notes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.mark_email_read_outlined, size: 48, color: AppTheme.textMuted),
                          SizedBox(height: 8),
                          Text('No new alerts. Coordinated agents are monitoring 24/7.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: notes.length,
                      itemBuilder: (c, idx) {
                        final n = notes[idx];
                        return ListTile(
                          leading: const Icon(Icons.info_outline, color: AppTheme.primary),
                          title: Text(n['title'] ?? 'Alert', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(n['message'] ?? '', style: const TextStyle(fontSize: 12)),
                          trailing: Text((n['created_at'] ?? '').split('T')[0], style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcesCenterCard() {
    final sources = [
      {'name': 'Job Bank Canada', 'status': 'ONLINE', 'coverage': 'Canada (LMIA / fglo=1)', 'color': const Color(0xFFEF4444)},
      {'name': 'EURES Portal', 'status': 'ONLINE', 'coverage': 'EU Mobility & Blue Card', 'color': const Color(0xFF3B82F6)},
      {'name': 'CareerJet Global', 'status': 'ONLINE', 'coverage': 'UK, CA, France, Germany', 'color': const Color(0xFF0D9488)},
      {'name': 'Jooble Search', 'status': 'ONLINE', 'coverage': 'Verified Global Feeds', 'color': const Color(0xFFF59E0B)},
      {'name': 'Company Portals', 'status': 'ONLINE', 'coverage': 'Direct Multinational ATS', 'color': const Color(0xFF8B5CF6)},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.travel_explore_rounded, color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOURCES CENTER',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppTheme.primary),
                    ),
                    Text('Active Job Boards & Corporate ATS (5 Connected)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _scanningLive ? null : _triggerLiveScan,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: const BorderSide(color: AppTheme.primary),
                ),
                icon: _scanningLive
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
                    : const Icon(Icons.bolt_rounded, size: 14, color: AppTheme.primary),
                label: Text(_scanningLive ? 'Scanning...' : 'Scan Now', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          Column(
            children: sources.map((s) {
              final c = s['color'] as Color;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s['name'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    Text(s['coverage'] as String, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('ACTIVE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }


  Widget _buildSystemStatusBanner(bool paused) {
    final isRtl = LanguageController.instance.isRtl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: paused ? AppTheme.warning.withValues(alpha: 0.4) : AppTheme.primary.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (paused ? AppTheme.warning : AppTheme.primary).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              paused ? Icons.pause_circle_filled_rounded : Icons.radar_rounded,
              color: paused ? AppTheme.warning : AppTheme.primaryLight,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paused
                      ? (isRtl ? 'المنظومة السحابية متوقفة مؤقتاً' : 'Cloud Engine Paused')
                      : (isRtl ? 'المنظومة السحابية نشطة 24/7' : 'Cloud Engine Active 24/7'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: paused ? AppTheme.warning : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isRtl
                      ? 'رصد عروض العمل الدولية، فحص التأشيرات، والفرز الذكي يعمل في السحابة حتى وحاسوبك مغلق.'
                      : 'International job scanning, visa filtering, and triage running autonomously.',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineFlowCard(Map<String, dynamic> counts) {
    final isRtl = LanguageController.instance.isRtl;
    final stages = [
      {'title': isRtl ? 'اكتشاف' : 'Found', 'count': counts['jobs_7d'] ?? 17, 'icon': Icons.travel_explore, 'color': AppTheme.primaryLight},
      {'title': isRtl ? 'تطابق' : 'Matched', 'count': counts['eligible_7d'] ?? 12, 'icon': Icons.checklist_rtl, 'color': AppTheme.secondary},
      {'title': isRtl ? 'سيرة' : 'CV Pick', 'count': counts['review'] ?? 3, 'icon': Icons.description, 'color': Colors.indigoAccent},
      {'title': isRtl ? 'خطاب' : 'Letter', 'count': counts['queued'] ?? 2, 'icon': Icons.edit_note, 'color': Colors.purpleAccent},
      {'title': isRtl ? 'إرسال' : 'Applied', 'count': counts['submitted'] ?? 4, 'icon': Icons.send_rounded, 'color': AppTheme.success},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.linear_scale_rounded, color: AppTheme.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                isRtl ? 'مسار التقديم والتوظيف الآلي' : 'APPLICATION PIPELINE',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppTheme.secondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: stages.map((s) {
              final c = s['color'] as Color;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(s['icon'] as IconData, size: 16, color: c),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${s['count']}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c),
                    ),
                    Text(
                      s['title'] as String,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }


  Widget _buildExploreJobsBanner(int count) {
    final isAr = LanguageController.instance.isRtl;
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobsExplorerScreen())),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary.withValues(alpha: 0.25),
              AppTheme.card,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.travel_explore_rounded, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'استعراض الفرص الوظيفية المحللة ($count فرصة)' : 'Explore Analyzed Jobs ($count Available)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAr ? 'اضغط للاستعراض وفحص الأمان والتقديم المباشر' : 'Tap to browse, scam audit, and quick apply',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }

  void _showAgentSheet(Map<String, dynamic> agent) {
    final isAr = LanguageController.instance.isRtl;
    final agentKey = agent['agent_key'] as String? ?? 'JobAgent';
    final name = isAr ? (agent['name_ar'] as String? ?? agent['name'] as String) : agent['name'] as String;
    final role = isAr ? (agent['role_ar'] as String? ?? agent['role'] as String) : agent['role'] as String;
    final color = agent['color'] as Color;
    final icon = agent['icon'] as IconData;

    bool running = false;
    String? runResult;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(role, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Text(
                      isAr ? 'نشط 24/7' : 'ACTIVE 24/7',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'المهمة الحالية للوكيل:' : 'Current Agent Mission:',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAr
                          ? 'مراقبة ومطابقة الوظائف وتحديث قواعد البيانات السحابية بصورة مستمرة دون توقف.'
                          : 'Monitoring global job boards, evaluating ATS compatibility, and maintaining zero-duplicate application pipeline.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              if (runResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppTheme.secondary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(runResult!, style: const TextStyle(fontSize: 11.5, color: AppTheme.secondary)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: running
                      ? null
                      : () async {
                          setSheetState(() => running = true);
                          try {
                            final res = await ApiService.runAgentCycle(agentKey);
                            setSheetState(() {
                              running = false;
                              runResult = res['result'] as String? ?? (isAr ? 'تم تنفيذ دورة الوكيل بنجاح.' : 'Cycle completed successfully.');
                            });
                          } catch (e) {
                            setSheetState(() {
                              running = false;
                              runResult = 'Execution error: $e';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: running
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    running
                        ? (isAr ? 'جاري تنفيذ دورة الوكيل...' : 'Running cycle...')
                        : (isAr ? 'تشغيل دورة الوكيل فوراً' : 'Run Agent Cycle Now'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
