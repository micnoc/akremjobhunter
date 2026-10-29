import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);
  String _selectedBucket = 'all';
  List<ApplicationItem> _items = [];
  bool _loading = true;
  String? _error;

  final Map<String, String> _buckets = {
    'all': 'All Memory',
    'sent': 'Sent & Submitted',
    'responses': 'Interviews & Replies',
    'queue': 'Queued Pacing',
    'skipped': 'Skipped',
  };

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
      final items = await ApiService.getApplications(_selectedBucket);
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showDetail(ApplicationItem item) async {
    try {
      final full = await ApiService.getApplicationDetail(item.id);
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      full.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildStatusBadge(full.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${full.company} • ${full.location} (${full.country})',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.border),

              // Overview grid
              _buildRow('CV Profile Used', full.cvLabel ?? 'Standard'),
              _buildRow('Method', full.method == 'EMAIL' ? 'Automated SMTP' : 'Official Portal'),
              if (full.sentAt != null) _buildRow('Sent At', full.sentAt!.split('T')[0]),
              if (full.toEmail != null) _buildRow('Recipient Email', full.toEmail!),

              // Response info
              if (full.responseSummary != null) ...[
                const SizedBox(height: 16),
                const Text('LATEST EMPLOYER RESPONSE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary),
                  ),
                  child: Text(full.responseSummary!, style: const TextStyle(fontSize: 13)),
                ),
              ],

              // Events / interview prep
              if (full.events != null && full.events!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('EMAIL TIMELINE & PREPARATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                const SizedBox(height: 6),
                ...full.events!.map((ev) {
                  final cat = ev['category'] ?? '';
                  final summary = ev['summary'] ?? '';
                  final hasPrep = ev['has_prep'] == true;
                  final evId = ev['id'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(cat, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                            Text((ev['received_at'] ?? '').split('T')[0], style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(summary, style: const TextStyle(fontSize: 12)),
                        if (hasPrep) ...[
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
                            onPressed: () {
                              final url = '${ApiService.serverUrl}/api/v1/events/$evId/prep';
                              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.black),
                            label: Text(l10n.t('mem_download_prep'), style: TextStyle(color: Colors.black, fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],

              // Cover letter
              if (full.coverLetter != null && full.coverLetter!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.t('review_edit_letter'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (full.coverSubject != null) ...[
                        Text('Subject: ${full.coverSubject!}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 8),
                      ],
                      Text(full.coverLetter!, style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color c = AppTheme.textMuted;
    if (status == 'SENT' || status == 'APPLIED_MANUAL') c = AppTheme.secondary;
    if (status == 'INTERVIEW' || status == 'OFFER') c = Colors.purpleAccent;
    if (status == 'QUEUED') c = AppTheme.primary;
    if (status == 'REJECTED') c = AppTheme.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // l10n getter used
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('mem_title')),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: _buckets.entries.map((e) {
                final selected = _selectedBucket == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: selected,
                    label: Text(e.value),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? Colors.black : Colors.white70,
                    ),
                    backgroundColor: AppTheme.card,
                    selectedColor: AppTheme.primary,
                    side: BorderSide(color: selected ? AppTheme.primary : AppTheme.border),
                    onSelected: (val) {
                      setState(() => _selectedBucket = e.key);
                      _load();
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.textMuted)))
                    : _items.isEmpty
                        ? const Center(
                            child: Text('No applications in this category.', style: TextStyle(color: AppTheme.textMuted)),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _items.length,
                              itemBuilder: (ctx, i) => _buildItemCard(_items[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ApplicationItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showDetail(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  _buildStatusBadge(item.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${item.company} • ${item.country}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'CV: ${item.cvLabel ?? "Standard"}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.primary),
                      ),
                      if (item.probability != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: Text(
                            '🎯 ${item.probability!['total_probability'] ?? 75}% قبول',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (item.scamRiskLevel == 'HIGH' ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.scamRiskLevel == 'HIGH' ? '🚨 Scam' : '🛡️ Safe',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: item.scamRiskLevel == 'HIGH' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '⭐ ${item.employerScore}/100',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    (item.sentAt ?? item.createdAt ?? '').split('T')[0],
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
