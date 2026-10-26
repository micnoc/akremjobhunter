import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/arab_country_picker.dart';

class DeveloperPanelScreen extends StatefulWidget {
  const DeveloperPanelScreen({super.key});

  @override
  State<DeveloperPanelScreen> createState() => _DeveloperPanelScreenState();
}

class _DeveloperPanelScreenState extends State<DeveloperPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _overview;
  List<dynamic> _candidates = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overviewFuture = ApiService.getAdminOverview();
      final usersFuture = ApiService.getAdminUsers();

      final results = await Future.wait([overviewFuture, usersFuture]);
      if (mounted) {
        setState(() {
          _overview = results[0];
          _candidates = results[1]['candidates'] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _showCandidateDetail(Map<String, dynamic> candidate) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _CandidateDetailDialog(userId: candidate['id']),
    );
  }

  Future<void> _triggerWorker(String type) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(type == 'collector' ? 'جاري تشغيل مسح الوظائف...' : 'جاري تشغيل التقييم...'),
        backgroundColor: const Color(0xFF0284C7),
      ),
    );
    try {
      final msg = type == 'collector'
          ? await ApiService.triggerAdminCollector()
          : await ApiService.triggerAdminEvaluator();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: const Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التشغيل: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: const [
            Text('⚡', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'لوحة تحكم المطورين (Admin & Dev)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF38BDF8)),
            onPressed: _loadAllData,
            tooltip: 'تحديث البيانات',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined), text: 'نظرة عامة'),
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'المترشحين'),
            Tab(icon: Icon(Icons.admin_panel_settings_outlined), text: 'تحكم النظام'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'تعذر الاتصال بلوحة الإدارة: $_error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadAllData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildCandidatesTab(),
                    _buildSystemToolsTab(),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab() {
    final metrics = _overview?['metrics'] as Map<String, dynamic>? ?? {};
    final countries = _overview?['country_distribution'] as Map<String, dynamic>? ?? {};
    final sources = _overview?['jobs_by_source'] as Map<String, dynamic>? ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Metrics Grid
        Row(
          children: [
            Expanded(child: _metricCard('👥 إجمالي المترشحين', '${metrics['total_candidates'] ?? 0}', Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _metricCard('📄 السير الذاتية', '${metrics['total_cvs'] ?? 0}', Colors.indigo)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _metricCard('🔍 وظائف مرصودة', '${metrics['total_jobs_scanned'] ?? 0}', Colors.cyan)),
            const SizedBox(width: 12),
            Expanded(child: _metricCard('📨 طلبات مرسلة', '${metrics['sent_applications'] ?? 0}', Colors.amber)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _metricCard('🎯 مقابلات وعروض', '${metrics['positive_leads'] ?? 0}', Colors.green)),
            const SizedBox(width: 12),
            Expanded(child: _metricCard('✅ حسابات مفعلة', '${metrics['verified_candidates'] ?? 0}', Colors.teal)),
          ],
        ),
        const SizedBox(height: 24),

        // Arab Countries Distribution
        const Text(
          '🌍 توزيع المترشحين حسب الدول العربية',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: countries.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد بيانات دول مسجلة حالياً', style: TextStyle(color: Colors.white54)),
                )
              : Column(
                  children: countries.entries.map((entry) {
                    final country = getArabCountry(entry.key);
                    return ListTile(
                      leading: Text(country.flag, style: const TextStyle(fontSize: 24)),
                      title: Text(country.nameAr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${entry.value} مترشح',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 24),

        // Sources Breakdown
        const Text(
          '🌐 مصادر الوظائف النشطة في السحابة',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              _sourceTile('Job Bank Canada (fglo=1)', sources['jobbank'] ?? 0, '🇨🇦'),
              const Divider(color: Colors.white12, height: 1),
              _sourceTile('EURES European Mobility', sources['eures'] ?? 0, '🇪🇺'),
              const Divider(color: Colors.white12, height: 1),
              _sourceTile('Indeed / LinkedIn (JobSpy)', sources['jobspy'] ?? 0, '💼'),
              const Divider(color: Colors.white12, height: 1),
              _sourceTile('Remote Portals (RemoteOK)', sources['remote_portals'] ?? 0, '🌍'),
              const Divider(color: Colors.white12, height: 1),
              _sourceTile('Adzuna Global', sources['adzuna'] ?? 0, '📊'),
              const Divider(color: Colors.white12, height: 1),
              _sourceTile('Arbeitnow EU', sources['arbeitnow'] ?? 0, '🇩🇪'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sourceTile(String name, int count, String emoji) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 22)),
      title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14)),
      trailing: Text(
        '$count وظيفة',
        style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _metricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidatesTab() {
    final filtered = _candidates.where((c) {
      final q = _searchQuery.toLowerCase();
      final username = (c['username'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final name = (c['full_name'] ?? '').toString().toLowerCase();
      return username.contains(q) || email.contains(q) || name.contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'بحث عن مترشح بالاسم أو البريد...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('لا يوجد مترشحين مطابقين', style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final candidate = filtered[idx];
                    final country = getArabCountry(candidate['country_code'] ?? 'TN');
                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.white12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF0F172A),
                          child: Text(country.flag, style: const TextStyle(fontSize: 20)),
                        ),
                        title: Row(
                          children: [
                            Text(
                              candidate['full_name'] != 'N/A' && (candidate['full_name'] ?? '').isNotEmpty
                                  ? candidate['full_name']
                                  : candidate['username'],
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            if (candidate['is_verified'] == true) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: Color(0xFF38BDF8), size: 16),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(candidate['email'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(
                              '📞 ${candidate['phone']} | ${country.nameAr}',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${candidate['cv_count']} CV',
                                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 12),
                          ],
                        ),
                        onTap: () => _showCandidateDetail(candidate),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSystemToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⚙️ أوامر السحابة المباشرة (Cloud Operations)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'تسمح لك هذه العمليات بإطلاق فحص الوظائف أو التقييم فورا دون انتظار مجدول السحابة.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _triggerWorker('collector'),
                icon: const Icon(Icons.travel_explore),
                label: const Text('تشغيل مسح الوظائف العالمية فوراً'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _triggerWorker('evaluator'),
                icon: const Icon(Icons.psychology),
                label: const Text('تشغيل تقييم الوظائف ومطابقة الـ CVs'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📡 معطيات الخادم السحابي النشط',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text('عنوان السيرفر: ${ApiService.serverUrl}', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13)),
              const SizedBox(height: 6),
              const Text('حالة التشغيل: السحابة متصلة 24/7 (الكمبيوتر مطفأ تماماً)', style: TextStyle(color: Colors.greenAccent, fontSize: 13)),
              const SizedBox(height: 6),
              const Text('محرك الذكاء الاصطناعي: محرك محلي مدمج + ترقية لـ Gemini عند توفره', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CandidateDetailDialog extends StatefulWidget {
  final int userId;

  const _CandidateDetailDialog({required this.userId});

  @override
  State<_CandidateDetailDialog> createState() => _CandidateDetailDialogState();
}

class _CandidateDetailDialogState extends State<_CandidateDetailDialog> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final res = await ApiService.getAdminUserDetail(widget.userId);
      if (mounted) {
        setState(() {
          _detail = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
            : _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 40),
                      const SizedBox(height: 10),
                      Text('خطأ: $_error', style: const TextStyle(color: Colors.white70)),
                    ],
                  )
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final candidate = _detail?['candidate'] ?? {};
    final cvs = _detail?['cvs'] as List<dynamic>? ?? [];
    final apps = _detail?['applications'] as List<dynamic>? ?? [];
    final country = getArabCountry(candidate['country_code'] ?? 'TN');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(country.flag, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate['full_name'] != 'N/A' && (candidate['full_name'] ?? '').isNotEmpty
                              ? candidate['full_name']
                              : candidate['username'],
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(candidate['email'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const Divider(color: Colors.white12, height: 20),
        Expanded(
          child: ListView(
            children: [
              // Contact info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone, color: Color(0xFF38BDF8), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      candidate['phone'] ?? 'غير محدد',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      country.nameAr,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Uploaded CV section
              const Text(
                '📄 السيرة الذاتية (CV & Skills)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              if (cvs.isEmpty)
                const Text('لم يقم المترشح برفع سيرة ذاتية بعد.', style: TextStyle(color: Colors.white54))
              else
                ...cvs.map((cv) {
                  final skills = (cv['skills'] as List<dynamic>? ?? []).take(10).join(', ');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${cv['label']} (${(cv['language'] ?? 'EN').toUpperCase()})',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                        ),
                        if (skills.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('المهارات المستخرجة: $skills', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                        if ((cv['text_snippet'] ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            cv['text_snippet'],
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 16),

              // Applications section
              const Text(
                '📨 طلبات التوظيف ومؤشر القبول',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              if (apps.isEmpty)
                const Text('لا توجد طلبات توظيف مرسلة بعد.', style: TextStyle(color: Colors.white54))
              else
                ...apps.map((app) {
                  final prob = app['probability'] as Map<String, dynamic>?;
                  final probPct = prob?['total_probability'] ?? 75;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                app['job_title'] ?? '',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: probPct >= 75 ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'احتمال القبول $probPct%',
                                style: TextStyle(
                                  color: probPct >= 75 ? Colors.greenAccent : Colors.orangeAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${app['company']} | ${app['location'] ?? ''} [${app['status']}]',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}
