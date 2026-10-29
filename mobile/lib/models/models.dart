class DashboardData {
  final bool paused;
  final Map<String, dynamic> lastRuns;
  final Map<String, bool> config;
  final int usedToday;
  final int dailyLimit;
  final Map<String, dynamic> counts;
  final List<dynamic> recent;

  DashboardData({
    required this.paused,
    required this.lastRuns,
    required this.config,
    required this.usedToday,
    required this.dailyLimit,
    required this.counts,
    required this.recent,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final engine = json['engine'] as Map<String, dynamic>? ?? {};
    final quota = json['quota'] as Map<String, dynamic>? ?? {};
    final cfg = json['config'] as Map<String, dynamic>? ?? {};
    return DashboardData(
      paused: engine['paused'] ?? false,
      lastRuns: (engine['last_runs'] as Map<String, dynamic>?) ?? {},
      config: cfg.map((k, v) => MapEntry(k, v == true)),
      usedToday: quota['used'] ?? 0,
      dailyLimit: quota['limit'] ?? 20,
      counts: (json['counts'] as Map<String, dynamic>?) ?? {},
      recent: (json['recent'] as List<dynamic>?) ?? [],
    );
  }
}

class CvItem {
  final int id;
  final String label;
  final String originalName;
  final String language;
  final String sector;
  final List<String> targetTitles;
  final List<String> skills;
  final String candidateName;
  final bool active;
  final String? uploadedAt;
  final int chars;

  CvItem({
    required this.id,
    required this.label,
    required this.originalName,
    required this.language,
    required this.sector,
    required this.targetTitles,
    required this.skills,
    required this.candidateName,
    required this.active,
    this.uploadedAt,
    required this.chars,
  });

  factory CvItem.fromJson(Map<String, dynamic> json) {
    return CvItem(
      id: json['id'] ?? 0,
      label: json['label'] ?? '',
      originalName: json['original_name'] ?? '',
      language: json['language'] ?? 'en',
      sector: json['sector'] ?? '',
      targetTitles: (json['target_titles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      skills: (json['skills'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      candidateName: json['candidate_name'] ?? '',
      active: json['active'] ?? true,
      uploadedAt: json['uploaded_at'],
      chars: json['chars'] ?? 0,
    );
  }
}

class ApplicationItem {
  final int id;
  final String status;
  final String method;
  final String title;
  final String company;
  final String country;
  final String location;
  final int? score;
  final String? eligibility;
  final String? cvLabel;
  final String? createdAt;
  final String? sentAt;
  final String? url;
  final String? source;
  final String? lastResponseAt;
  final String? responseSummary;
  final String? toEmail;
  final String? coverSubject;
  final String? coverLetter;
  final String? eligibilityEvidence;
  final List<dynamic>? missingSkills;
  final List<dynamic>? events;
  final Map<String, dynamic>? probability;
  final int? atsScore;
  final Map<String, dynamic>? scamDefense;
  final Map<String, dynamic>? employerIntel;

  ApplicationItem({
    required this.id,
    required this.status,
    required this.method,
    required this.title,
    required this.company,
    required this.country,
    required this.location,
    this.score,
    this.eligibility,
    this.cvLabel,
    this.createdAt,
    this.sentAt,
    this.url,
    this.source,
    this.lastResponseAt,
    this.responseSummary,
    this.toEmail,
    this.coverSubject,
    this.coverLetter,
    this.eligibilityEvidence,
    this.missingSkills,
    this.events,
    this.probability,
    this.atsScore,
    this.scamDefense,
    this.employerIntel,
  });

  String get scamRiskLevel => (scamDefense?['risk_level'] as String?)?.toUpperCase() ?? 'LOW';
  int get employerScore => (employerIntel?['employer_score'] as num?)?.toInt() ?? 82;
  String get employerCategory => employerIntel?['category'] as String? ?? 'Good';
  String get sponsorshipFriendliness => employerIntel?['sponsorship_friendliness'] as String? ?? 'High';

  factory ApplicationItem.fromJson(Map<String, dynamic> json) {
    final job = json['job'] as Map<String, dynamic>? ?? {};
    return ApplicationItem(
      id: json['id'] ?? 0,
      status: json['status'] ?? '',
      method: json['method'] ?? 'EMAIL',
      title: json['title'] ?? '',
      company: json['company'] ?? '',
      country: json['country'] ?? '',
      location: json['location'] ?? '',
      score: json['score'],
      eligibility: json['eligibility'],
      cvLabel: json['cv_label'],
      createdAt: json['created_at'],
      sentAt: json['sent_at'],
      url: json['url'],
      source: json['source'],
      lastResponseAt: json['last_response_at'],
      responseSummary: json['response_summary'],
      toEmail: json['to_email'],
      coverSubject: json['cover_subject'],
      coverLetter: json['cover_letter'],
      eligibilityEvidence: job['eligibility_evidence'],
      missingSkills: job['missing_skills'],
      events: json['events'],
      probability: json['probability'] as Map<String, dynamic>?,
      atsScore: (json['ats_score'] as num?)?.toInt(),
      scamDefense: json['scam_defense'] as Map<String, dynamic>?,
      employerIntel: json['employer_intel'] as Map<String, dynamic>?,
    );
  }
}
