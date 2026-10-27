import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);
  Map<String, dynamic>? _data;
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
      final res = await ApiService.getInsights();
      setState(() {
        _data = res;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // l10n getter used
    if (_loading && _data == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_error != null && _data == null) {
      return Scaffold(
        body: Center(child: Text(_error!, style: const TextStyle(color: AppTheme.textMuted))),
      );
    }

    final countries = (_data?['countries'] as List<dynamic>?) ?? [];
    final gaps = (_data?['skill_gaps'] as List<dynamic>?) ?? [];
    final sources = (_data?['sources'] as List<dynamic>?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('ins_title')),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Country Heatmap Table
            Text(l10n.t('ins_countries'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.1),
            ),
            const SizedBox(height: 8),
            _buildCountryTable(countries),
            const SizedBox(height: 24),

            // Skill Gap Analyzer
            Text(l10n.t('ins_skill_gaps'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.1),
            ),
            const SizedBox(height: 4),
            Text(l10n.t('ins_skill_gaps'),
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 8),
            _buildSkillGaps(gaps),
            const SizedBox(height: 24),

            // Source performance
            Text(l10n.t('ins_sources'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.1),
            ),
            const SizedBox(height: 8),
            _buildSourcesList(sources),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryTable(List<dynamic> list) {
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: Text(l10n.t('mem_empty'), style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: list.map((c) {
          final country = c['country'] ?? '';
          final found = c['found'] ?? 0;
          final eligible = c['eligible'] ?? 0;
          final applied = c['applied'] ?? 0;
          final conversion = c['conversion'] ?? 0.0;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        country,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$found jobs scanned', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('$eligible eligible • $applied applied', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$conversion%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: conversion > 0 ? AppTheme.secondary : AppTheme.textMuted,
                      ),
                    ),
                    const Text('Conversion', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSkillGaps(List<dynamic> list) {
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Text('No skill gaps detected. Your CVs match the required criteria.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ),
      );
    }

    return Column(
      children: list.map((g) {
        final skill = g['skill'] ?? '';
        final count = g['count'] ?? 0;
        final countries = (g['countries'] as List<dynamic>?)?.join(', ') ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(skill, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('Common in: $countries', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Missing in $count offers',
                  style: const TextStyle(color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSourcesList(List<dynamic> list) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: list.map((s) {
          final src = s['source'] ?? '';
          final found = s['found'] ?? 0;
          final matched = s['matched'] ?? 0;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(src, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('$matched eligible / $found scraped', style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
