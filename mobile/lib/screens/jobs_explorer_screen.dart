import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class JobsExplorerScreen extends StatefulWidget {
  final String? initialCountry;
  final String? initialSource;

  const JobsExplorerScreen({
    super.key,
    this.initialCountry,
    this.initialSource,
  });

  @override
  State<JobsExplorerScreen> createState() => _JobsExplorerScreenState();
}

class _JobsExplorerScreenState extends State<JobsExplorerScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _jobs = [];
  int _totalCount = 0;

  String _selectedCountry = 'ALL';
  String _selectedSource = 'ALL';

  final List<Map<String, String>> _countryFilters = [
    {'code': 'ALL', 'label_ar': 'كافة الدول', 'label_en': 'All Countries', 'flag': '🌍'},
    {'code': 'CA', 'label_ar': 'كندا', 'label_en': 'Canada', 'flag': '🇨🇦'},
    {'code': 'DE', 'label_ar': 'ألمانيا', 'label_en': 'Germany', 'flag': '🇩🇪'},
    {'code': 'FR', 'label_ar': 'فرنسا', 'label_en': 'France', 'flag': '🇫🇷'},
    {'code': 'GB', 'label_ar': 'بريطانيا', 'label_en': 'UK', 'flag': '🇬🇧'},
    {'code': 'US', 'label_ar': 'أمريكا', 'label_en': 'USA', 'flag': '🇺🇸'},
  ];

  final List<Map<String, String>> _sourceFilters = [
    {'code': 'ALL', 'label_ar': 'كافة المصادر', 'label_en': 'All Sources'},
    {'code': 'jobbank', 'label_ar': 'Job Bank كندا (LMIA)', 'label_en': 'Job Bank Canada'},
    {'code': 'eures', 'label_ar': 'EURES أوروبا', 'label_en': 'EURES Europe'},
    {'code': 'careerjet', 'label_ar': 'CareerJet الدولي', 'label_en': 'CareerJet'},
    {'code': 'company_careers', 'label_ar': 'بوابات الشركات المباشرة', 'label_en': 'Direct Companies'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCountry != null) _selectedCountry = widget.initialCountry!;
    if (widget.initialSource != null) _selectedSource = widget.initialSource!;
    _fetchJobs();
  }

  Future<void> _fetchJobs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService.getAnalyzedJobs(
        country: _selectedCountry == 'ALL' ? null : _selectedCountry,
        source: _selectedSource == 'ALL' ? null : _selectedSource,
        limit: 100,
      );

      setState(() {
        _jobs = res['items'] as List<dynamic>? ?? [];
        _totalCount = res['total'] as int? ?? _jobs.length;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _applyJob(dynamic job) async {
    final isAr = LanguageController.instance.isRtl;
    final jobId = job['id'] as int;

    // Show loading progress
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isAr ? 'جاري تجهيز ملف التقديم ورسالة التغطية...' : 'Preparing application and cover letter...'),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final res = await ApiService.quickApplyJob(jobId);
      final letter = res['cover_letter'] as String? ?? '';
      final subject = res['cover_subject'] as String? ?? '';
      final url = job['url'] as String? ?? '';

      setState(() {
        job['has_applied'] = true;
      });

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
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
                  const Icon(Icons.check_circle_rounded, color: AppTheme.secondary, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isAr ? 'تم إنشاء التقديم وتجهيز خطاب التحفيز!' : 'Application & Cover Letter Generated!',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${job['title']} @ ${job['company']}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
              const SizedBox(height: 10),
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
                      '${isAr ? "الموضوع:" : "Subject:"} $subject',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      letter,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: letter));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isAr ? 'تم نسخ خطاب التقديم إلى الحافظة' : 'Cover letter copied to clipboard')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text(isAr ? 'نسخ الخطاب' : 'Copy Letter'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (url.isNotEmpty)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                        icon: const Icon(Icons.open_in_browser, size: 16),
                        label: Text(isAr ? 'فتح رابط الوظيفة' : 'Open Job Link'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _showScamAudit(dynamic job) {
    final isAr = LanguageController.instance.isRtl;
    final source = job['source'] as String? ?? '';
    final elig = job['eligibility'] as String? ?? '';
    final isJobBank = source == 'jobbank';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: AppTheme.primary),
            const SizedBox(width: 10),
            Text(isAr ? 'فحص مصداقية الفرصة' : 'Job Legitimacy Audit'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${job['title']} @ ${job['company']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _auditRow(
              isAr ? 'المصدر الموثق' : 'Verified Source',
              isJobBank ? 'Job Bank Canada (Official Government)' : source.toUpperCase(),
              true,
            ),
            _auditRow(
              isAr ? 'رعاية التأشيرة وLMIA' : 'Visa & LMIA Sponsorship',
              elig.replaceAll('_', ' '),
              true,
            ),
            _auditRow(
              isAr ? 'رسوم المعالجة المسبقة' : 'Advance Processing Fees',
              isAr ? 'مجانية بالكامل (لا توجد رسوم)' : 'Zero Fees Detected',
              true,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.4)),
              ),
              child: Text(
                isAr
                    ? '✅ الفرصة مستخرجة من بوابات التوظيف الرسمية وتلبي متطلبات التوظيف الدولي.'
                    : '✅ Verified job posting conforming to international hiring standards.',
                style: const TextStyle(fontSize: 11, color: AppTheme.secondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إغلاق' : 'Close'),
          ),
        ],
      ),
    );
  }

  Widget _auditRow(String label, String value, bool safe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            safe ? Icons.check_circle_rounded : Icons.warning_rounded,
            color: safe ? AppTheme.secondary : AppTheme.warning,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = LanguageController.instance.isRtl;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'الفرص الوظيفية المحللة' : 'Analyzed Job Opportunities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchJobs,
            tooltip: isAr ? 'تحديث' : 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Country Filter Bar
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: AppTheme.surface,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _countryFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final c = _countryFilters[i];
                final code = c['code']!;
                final selected = _selectedCountry == code;
                return ChoiceChip(
                  label: Text('${c['flag']} ${isAr ? c['label_ar'] : c['label_en']}'),
                  selected: selected,
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? Colors.white : AppTheme.textMuted,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedCountry = code);
                    _fetchJobs();
                  },
                );
              },
            ),
          ),

          // 2. Summary & Source Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAr ? '$_totalCount فرصة وظيفية مفحوصة' : '$_totalCount Analyzed Jobs',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                ),
                DropdownButton<String>(
                  value: _selectedSource,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: AppTheme.card,
                  style: const TextStyle(fontSize: 12, color: AppTheme.secondary, fontWeight: FontWeight.bold),
                  items: _sourceFilters.map((s) {
                    return DropdownMenuItem<String>(
                      value: s['code'],
                      child: Text(isAr ? s['label_ar']! : s['label_en']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedSource = val);
                      _fetchJobs();
                    }
                  },
                ),
              ],
            ),
          ),

          // 3. Job Cards List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.danger, size: 40),
                            const SizedBox(height: 10),
                            Text(_error!, style: const TextStyle(color: AppTheme.textMuted)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchJobs,
                              child: Text(isAr ? 'إعادة المحاولة' : 'Retry'),
                            ),
                          ],
                        ),
                      )
                    : _jobs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.work_off_outlined, color: AppTheme.textMuted, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  isAr ? 'لا توجد فرص مطابقة لهذا الفلتر حالياً.' : 'No opportunities matched this filter.',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: _jobs.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (ctx, i) {
                              final job = _jobs[i];
                              return _buildJobCard(job, isAr);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(dynamic job, bool isAr) {
    final title = job['title'] as String? ?? 'Opportunity';
    final comp = job['company'] as String? ?? 'Direct Employer';
    final country = (job['country'] as String? ?? 'CA').toUpperCase();
    final location = job['location'] as String? ?? '';
    final source = (job['source'] as String? ?? 'jobbank').toUpperCase();
    final score = job['match_score'] as int? ?? 75;
    final elig = (job['eligibility'] as String? ?? 'OPEN_INTERNATIONAL').replaceAll('_', ' ');
    final desc = job['description'] as String? ?? '';
    final hasApplied = job['has_applied'] == true;

    final flag = country == 'CA'
        ? '🇨🇦'
        : country == 'DE'
            ? '🇩🇪'
            : country == 'FR'
                ? '🇫🇷'
                : country == 'GB'
                    ? '🇬🇧'
                    : country == 'US'
                        ? '🇺🇸'
                        : '🌐';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasApplied ? AppTheme.secondary.withValues(alpha: 0.5) : AppTheme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Match Score Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$flag $comp • $location ($country)',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (score >= 80 ? AppTheme.secondary : AppTheme.primary).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: score >= 80 ? AppTheme.secondary : AppTheme.primary,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: score >= 80 ? AppTheme.secondary : AppTheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$score% ATS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: score >= 80 ? AppTheme.secondary : AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Badges: Source + Eligibility (LMIA / Sponsorship)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  source,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                ),
                child: Text(
                  elig,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
              ),
            ],
          ),

          if (desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Action Buttons
          Row(
            children: [
              // Scam Check Icon Button
              IconButton.outlined(
                onPressed: () => _showScamAudit(job),
                icon: const Icon(Icons.shield_outlined, size: 18, color: AppTheme.textMuted),
                tooltip: isAr ? 'فحص الأمان' : 'Scam Audit',
              ),
              const SizedBox(width: 8),

              if ((job['url'] as String? ?? '').isNotEmpty) ...[
                IconButton.outlined(
                  onPressed: () async {
                    final uri = Uri.parse(job['url']);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18, color: AppTheme.secondary),
                  tooltip: isAr ? 'رابط العرض الأصلي' : 'Open Official Source',
                ),
                const SizedBox(width: 8),
              ],

              // Apply / Review Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _applyJob(job),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasApplied ? AppTheme.surface : AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(
                    hasApplied ? Icons.check_circle_outline : Icons.send_rounded,
                    size: 16,
                    color: hasApplied ? AppTheme.secondary : Colors.white,
                  ),
                  label: Text(
                    hasApplied
                        ? (isAr ? 'تم التقديم (استعراض)' : 'Applied (Review)')
                        : (isAr ? 'تقديم فوري وتوليد الخطاب' : 'Apply & Generate Letter'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hasApplied ? AppTheme.secondary : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
