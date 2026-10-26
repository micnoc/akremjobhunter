import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CvVaultScreen extends StatefulWidget {
  const CvVaultScreen({super.key});

  @override
  State<CvVaultScreen> createState() => _CvVaultScreenState();
}

class _CvVaultScreenState extends State<CvVaultScreen> {
  List<CvItem> _cvs = [];
  bool _loading = true;
  bool _uploading = false;
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
      final cvs = await ApiService.getCvs();
      setState(() {
        _cvs = cvs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickAndUpload() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (files.isEmpty) return;

      setState(() => _uploading = true);

      int uploaded = 0;
      List<String> errors = [];

      for (final f in files) {
        if (f.path != null) {
          try {
            final res = await ApiService.uploadCv(f.path!, f.name);
            final errs = (res['errors'] as List<dynamic>?) ?? [];
            if (errs.isNotEmpty) {
              errors.addAll(errs.map((e) => e.toString()));
            } else {
              uploaded++;
            }
          } catch (e) {
            errors.add('${f.name}: $e');
          }
        }
      }

      setState(() => _uploading = false);

      if (mounted) {
        if (errors.isNotEmpty) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Upload Warning'),
              content: Text(errors.join('\n')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully uploaded $uploaded CV(s)')),
          );
        }
        _load();
      }
    } catch (e) {
      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Picker error: $e')));
      }
    }
  }

  Future<void> _delete(CvItem cv) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete CV?'),
        content: Text('Are you sure you want to remove "${cv.label}" from the vault?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteCv(cv.id);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CV Vault'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _pickAndUpload,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : const Icon(Icons.upload_file_rounded),
        label: Text(_uploading ? 'Profiling CV...' : 'Upload CV (PDF)'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.textMuted)))
              : _cvs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.folder_open_rounded, size: 64, color: AppTheme.textMuted),
                            const SizedBox(height: 16),
                            const Text(
                              'Your CV Vault is Empty',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Upload your specialized CVs (e.g. Heavy Transport EN/FR, CNC/CAD EN/FR). '
                              'The AI will strictly ground every application in your actual CV text.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _pickAndUpload,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Upload Your First CV (PDF)'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: _cvs.length,
                        itemBuilder: (ctx, i) => _buildCvCard(_cvs[i]),
                      ),
                    ),
    );
  }

  Widget _buildCvCard(CvItem cv) {
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
                    cv.label.isNotEmpty ? cv.label : cv.originalName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.accent),
                  ),
                  child: Text(
                    cv.language.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${cv.originalName} • ${(cv.chars / 1000).toStringAsFixed(1)}k text chars extracted',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            if (cv.candidateName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Candidate: ${cv.candidateName}',
                style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 10),

            // Target Titles
            if (cv.targetTitles.isNotEmpty) ...[
              const Text('Target Job Titles:', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: cv.targetTitles.map((t) => _buildChip(t)).toList(),
              ),
              const SizedBox(height: 10),
            ],

            // Skills
            if (cv.skills.isNotEmpty) ...[
              const Text('Extracted Verified Skills:', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: cv.skills.take(8).map((s) => _buildChip(s)).toList(),
              ),
              const SizedBox(height: 10),
            ],

            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 14, color: AppTheme.secondary),
                    const SizedBox(width: 4),
                    const Text('Strict Grounding Active', style: TextStyle(fontSize: 11, color: AppTheme.secondary)),
                  ],
                ),
                IconButton(
                  onPressed: () => _delete(cv),
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 20),
                  tooltip: 'Delete CV',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
    );
  }
}
