import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<ApplicationItem> _items = [];
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
      final items = await ApiService.getReviewQueue();
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

  Future<void> _act(ApplicationItem item, String action) async {
    try {
      final res = await ApiService.postApplicationAction(item.id, action);
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

  Future<void> _openPortal(ApplicationItem item) async {
    if (item.url != null && item.url!.isNotEmpty) {
      final uri = Uri.parse(item.url!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Portal Application'),
          content: Text('Did you submit your application on ${item.company}\'s official portal?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not yet')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _act(item, 'applied');
              },
              child: const Text('Mark as Submitted'),
            ),
          ],
        ),
      );
    }
  }

  void _showLetterDialog(ApplicationItem item) async {
    // fetch full details
    try {
      final full = await ApiService.getApplicationDetail(item.id);
      if (!mounted) return;
      final subjectCtrl = TextEditingController(text: full.coverSubject ?? '');
      final bodyCtrl = TextEditingController(text: full.coverLetter ?? '');

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Cover Letter: ${full.title}'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: subjectCtrl,
                    decoration: const InputDecoration(labelText: 'Subject'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyCtrl,
                    decoration: const InputDecoration(labelText: 'Body (Strictly Grounded in CV)'),
                    maxLines: 8,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await ApiService.updateCoverLetter(item.id, subjectCtrl.text, bodyCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('1-Click Review Queue'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.textMuted)))
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.done_all_rounded, size: 54, color: AppTheme.secondary),
                          SizedBox(height: 12),
                          Text('Review Queue is Clear!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 4),
                          Text(
                            'All eligible international matches have been reviewed or queued.',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) => _buildCard(_items[i]),
                      ),
                    ),
    );
  }

  Widget _buildCard(ApplicationItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                if (item.score != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primary),
                    ),
                    child: Text(
                      '${item.score}% Match',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                if (item.probability != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Text(
                      '🎯 ${item.probability!['total_probability'] ?? 75}% احتمال قبول',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${item.company} • ${item.location} (${item.country})',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),

            // Profile & Method Badge
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildBadge(item.method == 'EMAIL' ? 'Direct Email' : 'Official Portal', Icons.send_rounded),
                if (item.cvLabel != null) _buildBadge('CV: ${item.cvLabel}', Icons.description_outlined),
                if (item.source != null) _buildBadge(item.source!, Icons.public),
                if (item.probability?['immigration_pathway'] != null)
                  _buildBadge('🛂 ${item.probability!['immigration_pathway']}', Icons.card_membership_outlined),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 12),

            // Action Buttons Row
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showLetterDialog(item),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Letter', style: TextStyle(fontSize: 11)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _act(item, 'skip'),
                  child: const Text('Skip', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ),
                const SizedBox(width: 6),
                if (item.method == 'EMAIL')
                  ElevatedButton.icon(
                    onPressed: () => _act(item, 'send'),
                    icon: const Icon(Icons.send_rounded, size: 14),
                    label: const Text('Send Email', style: TextStyle(fontSize: 12)),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => _openPortal(item),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text('Open & Submit', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}
