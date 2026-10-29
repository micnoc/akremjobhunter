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
            // Daily Throttle Card
            _buildDailyThrottle(d.usedToday, d.dailyLimit, ratio),
            const SizedBox(height: 14),

            // Review Alert Banner
            if (reviewCount > 0) ...[
              _buildReviewBanner(reviewCount),
              const SizedBox(height: 14),
            ],

            // Sources Center (Job Bank, EURES, CareerJet, Jooble, Company Portals)
            _buildSourcesCenterCard(),
            const SizedBox(height: 16),

            // Autonomous Multi-Agent Activity Center
            _buildMultiAgentCard(),
            const SizedBox(height: 16),

            // System Integrations Status Chips
            _buildIntegrationsCard(d.config),
            const SizedBox(height: 16),

            // Metric Cards Grid
            _buildMetricGrid(counts),
            const SizedBox(height: 20),

            // Engine Controls
            _buildEngineControls(d.paused),
            const SizedBox(height: 20),

            // Recent Submissions
            Text(l10n.t('dash_recent'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMuted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            _buildRecentList(d.recent),
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
          const Text(
            'Distributed evenly across 24h with random jitter to mimic human behavior and avoid rate limits.',
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
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.7,
      children: [
        _buildStatCard('JOBS ANALYSED (7D)', '${c['jobs_7d'] ?? 0}', 'International Scrapers', AppTheme.primary),
        _buildStatCard('ELIGIBLE MATCHES', '${c['eligible_7d'] ?? 0}', 'LMIA / Visa / Open', AppTheme.accent),
        _buildStatCard('APPLICATIONS SUBMITTED', '${c['submitted'] ?? 0}', 'Zero-Duplicate Archive', AppTheme.textMuted),
        _buildStatCard('INTERVIEWS / OFFERS', '${(c['interviews'] ?? 0) + (c['offers'] ?? 0)}', 'Verified Responses', AppTheme.secondary),
      ],
    );
  }

  Widget _buildStatCard(String title, String val, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
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
    );
  }

  Widget _buildEngineControls(bool paused) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MANUAL ENGINE CONTROLS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.1),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _trigger('discover'),
                icon: const Icon(Icons.travel_explore, size: 16),
                label: const Text('Scan Jobs', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _trigger('inbox'),
                icon: const Icon(Icons.mark_email_read, size: 16),
                label: const Text('Scan Inbox', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: () => _trigger(paused ? 'resume' : 'pause'),
              icon: Icon(paused ? Icons.play_arrow : Icons.pause, color: paused ? AppTheme.secondary : AppTheme.warning),
              tooltip: paused ? 'Resume 24/7 Engine' : 'Pause 24/7 Engine',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentList(List<dynamic> list) {
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Text('No submissions recorded yet.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ),
      );
    }

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
  Widget _buildMultiAgentCard() {
    final agents = [
      {'name': 'Job Agent', 'role': 'Canada, EURES, Indeed & Jooble', 'icon': Icons.radar_rounded, 'color': const Color(0xFF3B82F6)},
      {'name': 'CV Agent', 'role': 'Auto-Select CV & ATS Optimizer', 'icon': Icons.description_rounded, 'color': const Color(0xFF10B981)},
      {'name': 'Cover Letter Agent', 'role': 'FR/EN/AR Tailored Letters', 'icon': Icons.history_edu_rounded, 'color': const Color(0xFF8B5CF6)},
      {'name': 'Immigration Agent', 'role': 'LMIA & Visa Compatibility', 'icon': Icons.card_membership_rounded, 'color': const Color(0xFFF59E0B)},
      {'name': 'Email Agent', 'role': '24/7 IMAP, Scam & Offer Triage', 'icon': Icons.mail_lock_rounded, 'color': const Color(0xFFEC4899)},
      {'name': 'Opportunity Agent', 'role': 'Scam Defense & Score Prioritizer', 'icon': Icons.verified_user_rounded, 'color': const Color(0xFF06B6D4)},
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
                    const Text(
                      'AUTONOMOUS MULTI-AGENT NETWORK',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      '6 Coordinated AI Agents Active 24/7',
                      style: TextStyle(
                        fontSize: 11,
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
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, color: Color(0xFF10B981), size: 10),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
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
              childAspectRatio: 2.6,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: agents.length,
            itemBuilder: (context, i) {
              final a = agents[i];
              final c = a['color'] as Color;
              return Container(
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
                            a['name'] as String,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            a['role'] as String,
                            style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
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

}
