import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static const String _keyServerUrl = 'server_url';
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyCurrentUser = 'current_user';
  static const String _keyRememberMe = 'remember_me';

  static const String defaultCloudUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://akremjobhunter.onrender.com');
  static String serverUrl = defaultCloudUrl;
  static String accessToken = '';
  static String refreshToken = '';
  static Map<String, dynamic>? currentUser;
  static bool rememberMe = true;

  static Future<void> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyServerUrl);
    if (saved != null && saved.isNotEmpty && !saved.contains('10.0.2.2') && !saved.contains('127.0.0.1') && !saved.contains('192.168.')) {
      serverUrl = saved;
    } else {
      serverUrl = defaultCloudUrl;
    }
    accessToken = prefs.getString(_keyAccessToken) ?? '';
    refreshToken = prefs.getString(_keyRefreshToken) ?? '';
    rememberMe = prefs.getBool(_keyRememberMe) ?? true;
    final userRaw = prefs.getString(_keyCurrentUser);
    if (userRaw != null && userRaw.isNotEmpty) {
      try {
        currentUser = jsonDecode(userRaw);
      } catch (_) {
        currentUser = null;
      }
    }
  }

  static Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    serverUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    await prefs.setString(_keyServerUrl, serverUrl);
  }

  static Future<void> saveAuthSession({
    required String access,
    required String refresh,
    required Map<String, dynamic> user,
    required bool remember,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = access;
    refreshToken = refresh;
    currentUser = user;
    rememberMe = remember;

    if (remember) {
      await prefs.setString(_keyAccessToken, access);
      await prefs.setString(_keyRefreshToken, refresh);
      await prefs.setString(_keyCurrentUser, jsonEncode(user));
      await prefs.setBool(_keyRememberMe, true);
    } else {
      // In-memory only for this session
      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove(_keyCurrentUser);
      await prefs.setBool(_keyRememberMe, false);
    }
  }

  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = '';
    refreshToken = '';
    currentUser = null;
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyCurrentUser);
  }

  static bool get isAuthenticated => accessToken.isNotEmpty && currentUser != null;

  static Map<String, String> get _headers => {
        if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

  static Future<bool> testConnection([String? url]) async {
    final targetUrl = (url ?? serverUrl).trim().replaceAll(RegExp(r'/+$'), '');
    try {
      final res = await http
          .get(Uri.parse('$targetUrl/health'))
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------ Authentication
  static Future<Map<String, dynamic>> getPasswordPolicy() async {
    final res = await http.get(
      Uri.parse('$serverUrl/api/v1/auth/policy'),
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return {
      'min_length': 8,
      'require_uppercase': true,
      'require_lowercase': true,
      'require_numbers': true,
      'require_special': false,
    };
  }

  static Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
    bool remember = true,
  }) async {
    final res = await http.post(
      Uri.parse('$serverUrl/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username_or_email': usernameOrEmail.trim(),
        'password': password,
        'remember_me': remember,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final tokens = data['tokens'];
      final user = data['user'];
      await saveAuthSession(
        access: tokens['access_token'],
        refresh: tokens['refresh_token'],
        user: user,
        remember: remember,
      );
      return data;
    }

    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? 'Login failed');
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
    String? countryCode,
    String? phone,
  }) async {
    final res = await http.post(
      Uri.parse('$serverUrl/api/v1/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName.trim(),
        if (countryCode != null && countryCode.isNotEmpty) 'country_code': countryCode.trim(),
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
      }),
    );

    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      final tokens = data['tokens'];
      final user = data['user'];
      await saveAuthSession(
        access: tokens['access_token'],
        refresh: tokens['refresh_token'],
        user: user,
        remember: true,
      );
      return data;
    }

    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? 'Registration failed');
  }

  static Future<void> logout() async {
    try {
      if (refreshToken.isNotEmpty) {
        await http.post(
          Uri.parse('$serverUrl/api/v1/auth/logout'),
          headers: _headers,
          body: jsonEncode({'refresh_token': refreshToken}),
        );
      }
    } catch (_) {}
    await clearAuth();
  }

  static Future<bool> tryRefreshAccessToken() async {
    if (refreshToken.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse('$serverUrl/api/v1/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        accessToken = data['access_token'];
        final prefs = await SharedPreferences.getInstance();
        if (rememberMe) {
          await prefs.setString(_keyAccessToken, accessToken);
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> verifyEmail(String code) async {
    final res = await http.post(
      Uri.parse('$serverUrl/api/v1/auth/verify-email'),
      headers: _headers,
      body: jsonEncode({'code': code.trim()}),
    );
    if (res.statusCode == 200) {
      if (currentUser != null) {
        currentUser!['is_verified'] = true;
        final prefs = await SharedPreferences.getInstance();
        if (rememberMe) {
          await prefs.setString(_keyCurrentUser, jsonEncode(currentUser));
        }
      }
      return;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? 'Verification failed');
  }

  static Future<void> resendVerification() async {
    final res = await http.post(
      Uri.parse('$serverUrl/api/v1/auth/resend-verification'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to resend code');
    }
  }

  static Future<void> forgotPassword(String email) async {
    final res = await http.post(
      Uri.parse('$serverUrl/api/v1/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim()}),
    );
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Request failed');
    }
  }

  static Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final res = await http.post(
      Uri.parse('$serverUrl/api/v1/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'token': token.trim(),
        'new_password': newPassword,
      }),
    );
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Password reset failed');
    }
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await http.post(
      Uri.parse('$serverUrl/api/v1/auth/change-password'),
      headers: _headers,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to change password');
    }
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(
      Uri.parse('$serverUrl/api/v1/auth/me'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      currentUser = jsonDecode(res.body);
      return currentUser!;
    }
    throw Exception('Failed to fetch user profile');
  }

  // ------------------------------------------------ Dashboard & Apps
  static Future<DashboardData> getDashboard() async {
    var res = await http.get(
      Uri.parse('$serverUrl/api/v1/dashboard'),
      headers: _headers,
    );
    if (res.statusCode == 401 && await tryRefreshAccessToken()) {
      res = await http.get(
        Uri.parse('$serverUrl/api/v1/dashboard'),
        headers: _headers,
      );
    }
    if (res.statusCode == 200) {
      return DashboardData.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load dashboard: ${res.statusCode}');
  }

  static Future<List<ApplicationItem>> getReviewQueue() async {
    final res = await http.get(
      Uri.parse('$serverUrl/api/v1/applications?bucket=review'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body)['items'] as List<dynamic>;
      return data.map((e) => ApplicationItem.fromJson(e)).toList();
    }
    throw Exception('Failed to load review queue: ${res.statusCode}');
  }

  static Future<List<ApplicationItem>> getApplications(String bucket) async {
    final res = await http.get(
      Uri.parse('$serverUrl/api/v1/applications?bucket=$bucket'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body)['items'] as List<dynamic>;
      return data.map((e) => ApplicationItem.fromJson(e)).toList();
    }
    throw Exception('Failed to load applications');
  }

  static Future<ApplicationItem> getApplicationDetail(int id) async {
    final res = await http.get(
      Uri.parse('$serverUrl/api/v1/applications/$id'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return ApplicationItem.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load application detail');
  }

  static Future<String> postApplicationAction(int id, String action) async {
    final res = await http.post(
      Uri.parse('$serverUrl/api/v1/applications/$id/action'),
      headers: _headers,
      body: jsonEncode({'action': action}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['result'] ?? 'Success';
    }
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Action failed');
  }

  static Future<void> updateCoverLetter(int id, String subject, String body) async {
    final res = await http.put(
      Uri.parse('$serverUrl/api/v1/applications/$id/letter'),
      headers: _headers,
      body: jsonEncode({'subject': subject, 'body': body}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update cover letter');
    }
  }

  static Future<String> postEventReply(int id, String action, [String? body]) async {
    final res = await http.post(
      Uri.parse('$serverUrl/api/v1/events/$id/reply'),
      headers: _headers,
      body: jsonEncode({
        'action': action,
        if (body != null) ...{'body': body},
      }),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['result'] ?? 'Done';
    }
    throw Exception('Reply action failed');
  }

  static Future<List<CvItem>> getCvs() async {
    final res = await http.get(
      Uri.parse('$serverUrl/api/v1/cvs'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body)['items'] as List<dynamic>;
      return data.map((e) => CvItem.fromJson(e)).toList();
    }
    throw Exception('Failed to load CVs');
  }

  static Future<Map<String, dynamic>> uploadCv(String filePath, String fileName) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$serverUrl/api/v1/cvs'),
    );
    if (accessToken.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $accessToken';
    }
    req.files.add(await http.MultipartFile.fromPath('files', filePath, filename: fileName));

    final streamedRes = await req.send();
    final res = await http.Response.fromStream(streamedRes);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to upload CV: ${res.body}');
  }

  static Future<void> deleteCv(int id) async {
    final res = await http.delete(
      Uri.parse('$serverUrl/api/v1/cvs/$id'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to delete CV');
    }
  }

  static Future<Map<String, dynamic>> getInsights() async {
    final res = await http.get(
      Uri.parse('$serverUrl/api/v1/insights'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load insights');
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final res = await http.get(
      Uri.parse('$serverUrl/api/v1/settings'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load settings');
  }

  static Future<void> saveSettings(Map<String, dynamic> values) async {
    final res = await http.put(
      Uri.parse('$serverUrl/api/v1/settings'),
      headers: _headers,
      body: jsonEncode(values),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to save settings: ${res.body}');
    }
  }

  static Future<Map<String, dynamic>> testIntegration(String target) async {
    final res = await http.post(
      Uri.parse('$serverUrl/api/v1/settings/test/$target'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return {'ok': false, 'message': 'HTTP ${res.statusCode}'};
  }

  static Future<List<String>> getAiModels() async {
    final res = await http.get(
      Uri.parse('$serverUrl/api/v1/ai/models'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body)['items'] as List<dynamic>?;
      return list?.map((e) => e.toString()).toList() ?? [];
    }
    return [];
  }

  static Future<String> triggerEngine(String action) async {
    final res = await http.post(
      Uri.parse('$serverUrl/api/v1/engine/$action'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['result'] ?? 'Started';
    }
    throw Exception('Engine command failed');
  }

  // ------------------------------------------------ Admin & Developer Panel
  static Future<Map<String, dynamic>> getAdminOverview() async {
    final res = await http.get(
      Uri.parse('$serverUrl/api/v1/admin/overview'),
      headers: {
        ..._headers,
        'X-Admin-Key': 'akrem_admin_secret_2026',
      },
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load admin overview: ${res.body}');
  }

  static Future<Map<String, dynamic>> getAdminUsers({int limit = 100, int offset = 0}) async {
    final res = await http.get(
      Uri.parse('$serverUrl/api/v1/admin/users?limit=$limit&offset=$offset'),
      headers: {
        ..._headers,
        'X-Admin-Key': 'akrem_admin_secret_2026',
      },
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load admin users: ${res.body}');
  }

  static Future<Map<String, dynamic>> getAdminUserDetail(int userId) async {
    final res = await http.get(
      Uri.parse('$serverUrl/api/v1/admin/users/$userId/detail'),
      headers: {
        ..._headers,
        'X-Admin-Key': 'akrem_admin_secret_2026',
      },
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load candidate details: ${res.body}');
  }

  static Future<String> triggerAdminCollector() async {
    final res = await http.post(
      Uri.parse('$serverUrl/api/v1/admin/trigger-collector'),
      headers: {
        ..._headers,
        'X-Admin-Key': 'akrem_admin_secret_2026',
      },
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['message'] ?? 'Discovery initiated';
    }
    throw Exception('Failed to trigger collector');
  }

  static Future<String> triggerAdminEvaluator() async {
    final res = await http.post(
      Uri.parse('$serverUrl/api/v1/admin/trigger-evaluator'),
      headers: {
        ..._headers,
        'X-Admin-Key': 'akrem_admin_secret_2026',
      },
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['message'] ?? 'Evaluator initiated';
    }
    throw Exception('Failed to trigger evaluator');
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? countryCode,
    String? phone,
  }) async {
    final Map<String, dynamic> bodyMap = {};
    if (fullName != null) bodyMap['full_name'] = fullName;
    if (countryCode != null) bodyMap['country_code'] = countryCode;
    if (phone != null) bodyMap['phone'] = phone;

    final res = await http.put(
      Uri.parse('$serverUrl/api/v1/auth/profile'),
      headers: _headers,
      body: jsonEncode(bodyMap),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['user'] != null) {
        currentUser = data['user'];
        final prefs = await SharedPreferences.getInstance();
        if (rememberMe) {
          await prefs.setString(_keyCurrentUser, jsonEncode(currentUser));
        }
      }
      return data;
    }
    throw Exception('Failed to update profile');
  }

  // ================================================================= V3.2 Real Job Discovery & Sources
  static Future<Map<String, dynamic>> scanLiveJobs({List<String>? keywords, List<String>? countries}) async {
    final res = await http.post(
      Uri.parse('$serverUrl/api/v1/jobs/scan-live'),
      headers: _headers,
      body: jsonEncode({
        'keywords': keywords ?? ['Software Engineer', 'Technician', 'Mechanic'],
        'countries': countries ?? ['CA', 'DE', 'FR', 'GB'],
      }),
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw Exception('Live job scan failed');
  }

  static Future<List<dynamic>> getSourcesStatus() async {
    final res = await http.get(Uri.parse('$serverUrl/api/v1/sources/status'), headers: _headers);
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data['sources'] ?? [];
    }
    return [];
  }

  static Future<Map<String, dynamic>> getAgentsActivity() async {
    final res = await http.get(Uri.parse('$serverUrl/api/v1/agents/activity'), headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {};
  }

  // ================================================================= V3.2 Real AI Assistant & Document Analysis
  static Future<String> sendChatMessage(String prompt, {String? docType, String? docText}) async {
    final res = await http.post(
      Uri.parse('$serverUrl/api/v1/ai/chat'),
      headers: _headers,
      body: jsonEncode({
        'prompt': prompt,
        'doc_type': docType,
        'document_text': docText,
      }),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data['reply'] ?? 'Response received.';
    }
    throw Exception('AI Chat failed: HTTP ${res.statusCode}');
  }

  static Future<List<dynamic>> getChatMessages() async {
    final res = await http.get(Uri.parse('$serverUrl/api/v1/ai/messages'), headers: _headers);
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data['messages'] ?? [];
    }
    return [];
  }

  static Future<Map<String, dynamic>> analyzeDocument(String filePath, String fileName, String docType) async {
    final req = http.MultipartRequest('POST', Uri.parse('$serverUrl/api/v1/ai/analyze-document'));
    req.headers.addAll(_headers);
    req.fields['doc_type'] = docType;
    req.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw Exception('Document analysis failed: ${res.body}');
  }

  // ================================================================= V3.2 Telegram & WhatsApp
  static Future<Map<String, dynamic>> getTelegramConnectUrl() async {
    final res = await http.get(Uri.parse('$serverUrl/api/v1/telegram/connect-url'), headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'ok': false, 'error': 'Could not get Telegram URL'};
  }

  static Future<Map<String, dynamic>> getTelegramDiagnostics() async {
    final res = await http.get(Uri.parse('$serverUrl/api/v1/telegram/diagnostics'), headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'configured': false, 'status': 'OFFLINE'};
  }

  static Future<Map<String, dynamic>> testWhatsApp() async {
    final res = await http.post(Uri.parse('$serverUrl/api/v1/whatsapp/test'), headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'ok': false, 'message': 'WhatsApp request failed'};
  }

  // ================================================================= V3.2 Notifications
  static Future<List<dynamic>> getNotifications() async {
    final res = await http.get(Uri.parse('$serverUrl/api/v1/notifications'), headers: _headers);
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data['notifications'] ?? [];
    }
    return [];
  }

  static Future<void> markNotificationRead(int id) async {
    await http.post(Uri.parse('$serverUrl/api/v1/notifications/$id/read'), headers: _headers);
  }
}
