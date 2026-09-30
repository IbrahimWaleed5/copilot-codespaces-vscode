import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/app_language.dart';

/// نقطة اتصال واحدة بكل الـ API. عدّل [baseUrl] لعنوان السيرفر الحقيقي
/// (مثلاً: https://your-domain.com/api). أثناء التطوير المحلي على محاكي
/// أندرويد استخدم http://10.0.2.2:8000/api بدل localhost.
class ApiService {
  static const String siteBaseUrl = 'https://alwaleedoffice.com';
  static const String baseUrl = '$siteBaseUrl/api';
  static const String _activeOfficeKey = 'active_office_id_v1';

  static Future<int?> getActiveOfficeId() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_activeOfficeKey);
    return value != null && value > 0 ? value : null;
  }

  static Future<void> _saveActiveOfficeId(int officeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activeOfficeKey, officeId);
  }

  static Future<void> clearActiveOffice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeOfficeKey);
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Used by authenticated realtime channel authorization.
  static Future<String?> getAuthToken() => _getToken();

  static Future<bool> hasAuthToken() async {
    final token = await _getToken();
    return token != null && token.trim().isNotEmpty;
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.remove(_activeOfficeKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove(_activeOfficeKey);
  }

  static Future<Map<String, String>> _headers({
    bool auth = false,
    bool includeOffice = true,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...AppLanguage.instance.headers,
    };

    if (auth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      if (includeOffice) {
        final officeId = await getActiveOfficeId();
        if (officeId != null) {
          headers['X-Office-Id'] = '$officeId';
        }
      }
    }

    return headers;
  }

  static Future<Map<String, String>> _multipartHeaders({
    bool auth = false,
  }) async {
    final headers = await _headers(auth: auth);
    headers.remove('Content-Type');
    return headers;
  }

  static Future<Map<String, String>> authenticatedMediaHeaders() async {
    final headers = await _headers(auth: true);
    headers.remove('Content-Type');
    return headers;
  }

  /// Multipart endpoints may occasionally receive an HTML/proxy error instead
  /// of JSON. Do not let jsonDecode throw into the Flutter widget tree.
  static Map<String, dynamic> _safeResponseMap(http.Response response) {
    if (response.bodyBytes.isEmpty) return <String, dynamic>{};
    final raw = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Continue with a controlled error message below.
    }

    final looksLikeHtml =
        raw.startsWith('<!DOCTYPE') ||
        raw.startsWith('<html') ||
        raw.contains('<body') ||
        raw.contains('<head');
    if (!looksLikeHtml && raw.isNotEmpty && raw.length <= 280) {
      return <String, dynamic>{'message': raw};
    }
    return <String, dynamic>{
      'message': response.statusCode >= 500
          ? 'حدث خطأ في الخادم أثناء تنفيذ الطلب (${response.statusCode}). حاول مرة أخرى.'
          : 'تعذر قراءة استجابة الخادم (${response.statusCode}). حاول مرة أخرى.',
    };
  }

  static Future<Map<String, dynamic>> fetchOfficeContext() async {
    Future<http.Response> request({required bool includeOffice}) async =>
        http.get(
          Uri.parse('$baseUrl/office/context'),
          headers: await _headers(auth: true, includeOffice: includeOffice),
        );

    var response = await request(includeOffice: true);
    if (response.statusCode == 403 && await getActiveOfficeId() != null) {
      await clearActiveOffice();
      response = await request(includeOffice: false);
    }

    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final current = body['current_office'];
      if (current is Map) {
        final id = int.tryParse(current['id']?.toString() ?? '');
        if (id != null && id > 0) await _saveActiveOfficeId(id);
      }
      return body;
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> selectOfficeContext(int officeId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/office/context'),
      headers: await _headers(auth: true, includeOffice: false),
      body: jsonEncode({'office_id': officeId}),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _saveActiveOfficeId(officeId);
      return body;
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchCurrentSaasPlan() async {
    final response = await http.get(
      Uri.parse('$baseUrl/office/saas-plan'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<List<dynamic>> fetchSaasPlans() async {
    final response = await http.get(
      Uri.parse('$baseUrl/saas/plans'),
      headers: await _headers(),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return List<dynamic>.from(body['plans'] as List? ?? const []);
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Uri socialAuthStartUri(String provider, {String? intent}) {
    final query = <String, String>{'platform': 'mobile'};
    if (intent != null && intent.trim().isNotEmpty) {
      query['intent'] = intent.trim();
    }

    return Uri.parse(
      '$siteBaseUrl/auth/social/$provider/redirect',
    ).replace(queryParameters: query);
  }

  static Future<Map<String, dynamic>> exchangeSocialLogin(String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/social/exchange'),
      headers: await _headers(),
      body: jsonEncode({'code': code}),
    );

    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );

    if (response.statusCode == 200) {
      await _saveToken(body['token'] as String);
      return body;
    }

    if (response.statusCode == 202 &&
        (body['two_factor_required'] == true ||
            body['password_change_required'] == true)) {
      return body;
    }

    throw ApiException(_extractErrorMessage(body));
  }

  /// تسجيل الدخول — يرجع بيانات المستخدم أو يرمي استثناء برسالة الخطأ.
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: await _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );

    if (response.statusCode == 200) {
      await _saveToken(body['token'] as String);
      return body;
    }

    if (response.statusCode == 202 &&
        (body['two_factor_required'] == true ||
            body['password_change_required'] == true)) {
      return body;
    }

    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> completeTemporaryPasswordChange({
    required String passwordChangeToken,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/temporary-password/change'),
      headers: await _headers(),
      body: jsonEncode({
        'password_change_token': passwordChangeToken,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _saveToken(body['token'].toString());
      return body;
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> requestPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forgot-password'),
      headers: await _headers(),
      body: jsonEncode({'email': email.trim()}),
    );

    final decoded = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(
            jsonDecode(utf8.decode(response.bodyBytes)) as Map,
          );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded['message']?.toString() ??
          'تم إرسال رابط استعادة كلمة المرور إلى بريدك.';
    }

    throw ApiException(_extractErrorMessage(decoded));
  }

  static Future<String> resetPassword({
    required String email,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reset-password'),
      headers: await _headers(),
      body: jsonEncode({
        'email': email.trim(),
        'token': token.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );

    final decoded = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(
            jsonDecode(utf8.decode(response.bodyBytes)) as Map,
          );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded['message']?.toString() ?? 'تم تغيير كلمة المرور بنجاح.';
    }

    throw ApiException(_extractErrorMessage(decoded));
  }

  static Future<Map<String, dynamic>> completeLoginTwoFactor({
    required String challengeToken,
    required String code,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/email-two-factor'),
      headers: await _headers(),
      body: jsonEncode({'challenge_token': challengeToken, 'code': code}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      await _saveToken(body['token'] as String);
      return body;
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> resendLoginTwoFactorDetails(
    String challengeToken,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/email-two-factor/resend'),
      headers: await _headers(),
      body: jsonEncode({'challenge_token': challengeToken}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> resendLoginTwoFactor(String challengeToken) async {
    final body = await resendLoginTwoFactorDetails(challengeToken);
    return twoFactorDeliveryMessage(body, 'تم إرسال رمز جديد.');
  }

  /// تسجيل مستخدم جديد. لازم multipart لأن صورة البروفايل إلزامية
  /// (نفس شرط الموقع الأصلي).
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String countryCode, // مثال: "SA" (حرفين)
    required String dialCode, // مثال: "+966"
    required String phone,
    required File profilePhoto,
    required bool privacyAccepted,
    required bool termsAccepted,
  }) async {
    final uri = Uri.parse('$baseUrl/register');
    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll({'Accept': 'application/json'});

    request.fields.addAll({
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'country_code': countryCode,
      'dial_code': dialCode,
      'phone': phone,
      'privacy_accepted': privacyAccepted ? '1' : '0',
      'terms_accepted': termsAccepted ? '1' : '0',
    });

    request.files.add(
      await http.MultipartFile.fromPath('profile_photo', profilePhoto.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 201 || response.statusCode == 200) {
      await _saveToken(body['token'] as String);
      return body;
    }

    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>?> fetchMe() async {
    final token = await _getToken();
    if (token == null || token.trim().isEmpty) return null;

    final response = await http.get(
      Uri.parse('$baseUrl/me'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map,
      );
    }

    // نمسح الجلسة فقط عندما يؤكد الخادم أن الاعتماد غير صالح.
    // انقطاع الإنترنت أو أخطاء 5xx لا يجب أن تسجل خروج المستخدم.
    if (response.statusCode == 401 || response.statusCode == 403) {
      await clearToken();
      return null;
    }

    throw ApiException(
      'تعذر تحديث جلسة الحساب مؤقتًا. سيتم الاحتفاظ بالدخول المحلي حتى عودة الاتصال.',
    );
  }

  /// حالة تفعيل البريد للمستخدم الحالي.
  static Future<Map<String, dynamic>> emailVerificationStatus() async {
    final response = await http.get(
      Uri.parse('$baseUrl/email/verification-status'),
      headers: await _headers(auth: true),
    );

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      return body as Map<String, dynamic>;
    }

    throw ApiException(_extractErrorMessage(body));
  }

  /// إعادة إرسال رابط تأكيد البريد من نفس نظام الموقع.
  static Future<Map<String, dynamic>> resendEmailVerification() async {
    final response = await http.post(
      Uri.parse('$baseUrl/email/verification-notification'),
      headers: await _headers(auth: true),
    );

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      return body as Map<String, dynamic>;
    }

    throw ApiException(_extractErrorMessage(body));
  }

  static Future<void> logout() async {
    await http.post(
      Uri.parse('$baseUrl/logout'),
      headers: await _headers(auth: true),
    );
    await clearToken();
  }

  static Future<Map<String, dynamic>> fetchHome() async {
    final response = await http.get(
      Uri.parse('$baseUrl/home'),
      headers: await _headers(),
    );

    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchDashboard() async {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard'),
      headers: await _headers(auth: true),
    );

    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  /// مكتبة أعمال المهندسين — pagination + بحث اختياري.
  static Future<Map<String, dynamic>> fetchEngineerLibrary({
    int page = 1,
    String? query,
    int? specialtyId,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (specialtyId != null) 'specialty_id': specialtyId.toString(),
    };
    final uri = Uri.parse(
      '$baseUrl/engineer-library',
    ).replace(queryParameters: params);
    final response = await http.get(uri, headers: await _headers(auth: true));

    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchWorkLibrary({
    int page = 1,
    String provider = 'engineers',
    String? query,
    int? specialtyId,
    bool verified = false,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'provider': provider,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (specialtyId != null) 'specialty_id': specialtyId.toString(),
      if (verified) 'verified': '1',
    };
    final uri = Uri.parse(
      '$baseUrl/work-library',
    ).replace(queryParameters: params);
    final response = await http.get(uri, headers: await _headers(auth: false));
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchEngineers({
    int page = 1,
    String? query,
    int? specialtyId,
    bool verified = false,
    String sort = 'rating',
  }) async {
    final uri = Uri.parse('$baseUrl/engineers').replace(
      queryParameters: {
        'page': page.toString(),
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (specialtyId != null) 'specialty_id': specialtyId.toString(),
        if (verified) 'verified': '1',
        'sort': sort,
      },
    );
    final response = await http.get(uri, headers: await _headers(auth: false));
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchEngineerWork(int workId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/engineer-library/$workId'),
      headers: await _headers(auth: true),
    );

    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchEngineerProfile(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/engineers/$userId'),
      headers: await _headers(auth: true),
    );

    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<List<dynamic>> fetchConsultationTypes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/consultation-types'),
      headers: await _headers(),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body as List<dynamic>;
    throw ApiException('تعذر تحميل أنواع الاستشارات');
  }

  static Future<List<dynamic>> fetchManagedConsultationTypes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/financial-manager/consultation-types'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 && body is Map) {
      return (body['data'] as List? ?? const <dynamic>[]);
    }
    if (body is Map<String, dynamic>) {
      throw ApiException(_extractErrorMessage(body));
    }
    throw ApiException('تعذر تحميل أنواع الاستشارات.');
  }

  static Future<Map<String, dynamic>> createManagedConsultationType({
    required String name,
    required double price,
    String? description,
    int? estimatedDays,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/financial-manager/consultation-types'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'name': name.trim(),
        'price': price,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (estimatedDays != null) 'estimated_days': estimatedDays,
      }),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 201 && body is Map) {
      return Map<String, dynamic>.from(body);
    }
    if (body is Map<String, dynamic>) {
      throw ApiException(_extractErrorMessage(body));
    }
    throw ApiException('تعذر إضافة نوع الاستشارة.');
  }

  static Future<Map<String, dynamic>> updateManagedConsultationType({
    required int id,
    required String name,
    required double price,
    String? description,
    int? estimatedDays,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/financial-manager/consultation-types/$id'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'name': name.trim(),
        'price': price,
        'description': description?.trim() ?? '',
        'estimated_days': estimatedDays,
      }),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 && body is Map) {
      return Map<String, dynamic>.from(body);
    }
    if (body is Map<String, dynamic>) {
      throw ApiException(_extractErrorMessage(body));
    }
    throw ApiException('تعذر تحديث نوع الاستشارة.');
  }

  static Future<List<dynamic>> fetchMyConsultations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/consultations'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body as List<dynamic>;
    throw ApiException(
      _extractErrorMessage({'message': 'تعذر تحميل الاستشارات'}),
    );
  }

  static Future<Map<String, dynamic>> fetchConsultation(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/consultations/$id'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> createConsultation({
    required int consultationTypeId,
    int? engineerId,
    int? officeId,
    required String title,
    required String description,
    File? customerFile,
  }) async {
    // نستخدم multipart دائمًا حتى تكون نفس الدالة جاهزة لإرفاق ملف العميل
    // (PDF / صورة / DWG) بدون مسار API منفصل.
    final uri = Uri.parse('$baseUrl/consultations');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _multipartHeaders(auth: true));

    request.fields.addAll({
      'consultation_type_id': consultationTypeId.toString(),
      if (engineerId != null) 'engineer_id': engineerId.toString(),
      if (officeId != null) 'office_id': officeId.toString(),
      'title': title,
      'description': description,
    });

    if (customerFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('customer_file', customerFile.path),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<List<dynamic>> fetchConsultationMessages(
    int consultationId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/consultations/$consultationId/messages'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body as List<dynamic>;
    throw ApiException(_extractErrorMessage({'message': 'تعذر تحميل الرسائل'}));
  }

  static Future<Map<String, dynamic>> sendConsultationMessage({
    required int consultationId,
    String? message,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/consultations/$consultationId/messages'),
      headers: await _headers(auth: true),
      body: jsonEncode({'message': message}),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  /// إرسال رسالة بمرفق (ملف أو صورة). لو محتاج نص كمان ابعته في [message].
  static Future<Map<String, dynamic>> sendConsultationMessageWithAttachment({
    required int consultationId,
    String? message,
    required File attachment,
  }) async {
    final uri = Uri.parse('$baseUrl/consultations/$consultationId/messages');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _multipartHeaders(auth: true));

    if (message != null && message.isNotEmpty) {
      request.fields['message'] = message;
    }
    request.files.add(
      await http.MultipartFile.fromPath('attachment', attachment.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchPublicPaymentInformation() async {
    final uri = Uri.parse('$baseUrl/payment-information').replace(
      queryParameters: {
        '_ts': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    final response = await http.get(uri, headers: await _headers(auth: false));
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 && body is Map<String, dynamic>) return body;
    if (body is Map<String, dynamic>)
      throw ApiException(_extractErrorMessage(body));
    throw ApiException('تعذر تحميل بيانات الدفع.');
  }

  static Future<Map<String, dynamic>> fetchPaymentInfo(
    int consultationId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/consultations/$consultationId/payment'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchPlatformPaymentMethods({
    String? country,
  }) async {
    final query = <String, String>{
      '_ts': DateTime.now().millisecondsSinceEpoch.toString(),
      if (country != null) 'country': country,
    };
    final uri = Uri.parse(
      '$baseUrl/payment-methods',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: await _headers(auth: false));
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  /// دفع يدوي موحد: الدولة + طريقة الدفع + الإيصال للمراجعة.
  static Future<Map<String, dynamic>> submitPayment({
    required int consultationId,
    required String countryCode,
    required int platformPaymentMethodId,
    File? receipt,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/consultations/$consultationId/payment'),
    );
    request.headers.addAll(
      await _headers(auth: true)
        ..remove('Content-Type'),
    );
    request.fields['payment_country_code'] = countryCode;
    request.fields['platform_payment_method_id'] = platformPaymentMethodId
        .toString();
    if (receipt != null)
      request.files.add(
        await http.MultipartFile.fromPath('receipt', receipt.path),
      );
    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchNotifications() async {
    Future<http.Response> request() async => http
        .get(
          Uri.parse('$baseUrl/notifications'),
          headers: await _headers(auth: true, includeOffice: false),
        )
        .timeout(const Duration(seconds: 20));

    var response = await request();

    // Retry once for a transient gateway/server failure. Do not loop forever.
    if (response.statusCode >= 500) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      response = await request();
    }

    final body = _safeResponseMap(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final rawData = body['data'];
      if (rawData is List) {
        return <String, dynamic>{...body, 'data': rawData};
      }

      final legacyRows = body['notifications'];
      if (legacyRows is List) {
        return <String, dynamic>{...body, 'data': legacyRows};
      }

      return <String, dynamic>{...body, 'data': const <dynamic>[]};
    }

    if (response.statusCode == 401) {
      throw ApiException(
        'انتهت جلسة تسجيل الدخول. سجّل الدخول من جديد لعرض الإشعارات.',
        statusCode: 401,
        data: body,
      );
    }

    if (response.statusCode == 429) {
      final retryAfter = response.headers['retry-after'];
      throw ApiException(
        retryAfter == null
            ? 'تم طلب الإشعارات عدة مرات بسرعة. انتظر قليلًا ثم أعد المحاولة.'
            : 'تم الوصول إلى حد الطلبات الآمن. أعد المحاولة بعد $retryAfter ثانية.',
        statusCode: 429,
        data: body,
      );
    }

    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<int> fetchUnreadNotificationsCount() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/notifications/unread-count'),
            headers: await _headers(auth: true, includeOffice: false),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return 0;

      final body = _safeResponseMap(response);
      return int.tryParse(body['count']?.toString() ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<String?> markNotificationAsRead(String notificationId) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/notifications/$notificationId/read'),
          headers: await _headers(auth: true, includeOffice: false),
        )
        .timeout(const Duration(seconds: 15));

    final body = _safeResponseMap(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body['url']?.toString();
    }

    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<void> markAllNotificationsAsRead() async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/notifications/read-all'),
          headers: await _headers(auth: true, includeOffice: false),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final body = _safeResponseMap(response);
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<void> deleteNotification(String notificationId) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/notifications/$notificationId'),
          headers: await _headers(auth: true, includeOffice: false),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final body = _safeResponseMap(response);
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<void> registerDeviceToken({
    required String token,
    required String platform,
    String? deviceName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/device-tokens'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'token': token,
        'platform': platform,
        if (deviceName != null && deviceName.trim().isNotEmpty)
          'device_name': deviceName.trim(),
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = response.body.isNotEmpty
          ? Map<String, dynamic>.from(
              jsonDecode(utf8.decode(response.bodyBytes)) as Map,
            )
          : <String, dynamic>{};
      throw ApiException(_extractErrorMessage(body));
    }
  }

  static Future<Map<String, dynamic>> fetchAdminActionCenter() =>
      _phase14Json('GET', 'admin/action-center');

  static Future<Map<String, dynamic>> fetchNotificationPushStatus() =>
      _phase14Json('GET', 'notifications/push-status');

  static Future<Map<String, dynamic>> sendTestPushNotification() =>
      _phase14Json('POST', 'notifications/test-push');

  static Future<Map<String, dynamic>> sendAdminBroadcastNotification({
    String? title,
    required String message,
  }) => _phase14Json(
    'POST',
    'notifications/broadcast',
    body: {
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      'message': message.trim(),
    },
  );

  static Future<void> deleteDeviceToken(String token) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/device-tokens'),
      headers: await _headers(auth: true),
      body: jsonEncode({'token': token}),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final body = response.body.isNotEmpty
          ? jsonDecode(utf8.decode(response.bodyBytes))
          : <String, dynamic>{};
      throw ApiException(_extractErrorMessage(body));
    }
  }

  static Future<List<dynamic>> fetchProjects() async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body as List<dynamic>;
    throw ApiException(
      _extractErrorMessage({'message': 'تعذر تحميل المشاريع'}),
    );
  }

  static Future<Map<String, dynamic>> fetchProjectDetail(int projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<List<dynamic>> fetchProjectFiles(int projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/files'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body as List<dynamic>;
    throw ApiException(
      _extractErrorMessage({'message': 'تعذر تحميل ملفات المشروع'}),
    );
  }

  static Future<Map<String, dynamic>> uploadProjectFile({
    required int projectId,
    required String title,
    String? description,
    required File file,
  }) async {
    final uri = Uri.parse('$baseUrl/projects/$projectId/files');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _multipartHeaders(auth: true));

    request.fields.addAll({
      'title': title,
      if (description != null) 'description': description,
    });
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<File> downloadProjectFile({
    required int projectId,
    required int fileId,
    required String fileName,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/files/$fileId/download'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode != 200) {
      throw ApiException('تعذر تنزيل الملف.');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<Map<String, dynamic>> fetchProjectContract(
    int projectId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/contract'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<File> downloadProjectContract(
    int projectId,
    String contractNumber,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/contract/download'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode != 200) {
      throw ApiException('تعذر تنزيل العقد.');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$contractNumber.pdf');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<Map<String, dynamic>> signProjectContract({
    required int projectId,
    required String typedName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/contract/sign'),
      headers: await _headers(auth: true),
      body: jsonEncode({'accept_terms': true, 'typed_name': typedName}),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> declineProjectContract({
    required int projectId,
    required String reason,
  }) => _phase14Json(
    'PATCH',
    'projects/$projectId/contract/decline',
    body: {'decline_reason': reason.trim()},
  );

  static Future<Map<String, dynamic>> fetchProjectMilestones(
    int projectId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/milestones'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 && body is Map) {
      return Map<String, dynamic>.from(body);
    }
    throw ApiException(
      _extractErrorMessage(
        body is Map
            ? Map<String, dynamic>.from(body)
            : {'message': 'تعذر تحميل خطة العمل'},
      ),
    );
  }

  static Future<Map<String, dynamic>> fetchProjectMilestoneMeta(
    int projectId,
  ) => _phase14Json('GET', 'projects/$projectId/milestones/meta');

  static Future<String> createProjectMilestone({
    required int projectId,
    required String title,
    String? description,
    String? startDate,
    String? endDate,
    required String status,
    required int progress,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      if (description != null) 'description': description,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      'status': status,
      'progress': progress,
    };
    final data = await _phase14Json(
      'POST',
      'projects/$projectId/milestones',
      body: payload,
    );
    return data['message']?.toString() ?? 'تمت إضافة المرحلة.';
  }

  static Future<String> updateProjectMilestone({
    required int projectId,
    required int milestoneId,
    required String title,
    String? description,
    String? startDate,
    String? endDate,
    required String status,
    required int progress,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      if (description != null) 'description': description,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      'status': status,
      'progress': progress,
    };
    final data = await _phase14Json(
      'PATCH',
      'projects/$projectId/milestones/$milestoneId',
      body: payload,
    );
    return data['message']?.toString() ?? 'تم تحديث المرحلة.';
  }

  static Future<String> deleteProjectMilestone({
    required int projectId,
    required int milestoneId,
  }) async {
    final data = await _phase14Json(
      'DELETE',
      'projects/$projectId/milestones/$milestoneId',
    );
    return data['message']?.toString() ?? 'تم حذف المرحلة.';
  }

  static Future<String> createProjectTask({
    required int projectId,
    required int milestoneId,
    required String title,
    String? description,
    int? assignedTo,
    String? startDate,
    String? dueDate,
    required String priority,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      if (description != null) 'description': description,
      if (assignedTo != null) 'assigned_to': assignedTo,
      if (startDate != null) 'start_date': startDate,
      if (dueDate != null) 'due_date': dueDate,
      'priority': priority,
    };
    final data = await _phase14Json(
      'POST',
      'projects/$projectId/milestones/$milestoneId/tasks',
      body: payload,
    );
    return data['message']?.toString() ?? 'تمت إضافة المهمة.';
  }

  static Future<String> updateProjectTask({
    required int projectId,
    required int taskId,
    required String title,
    String? description,
    int? assignedTo,
    String? startDate,
    String? dueDate,
    required String priority,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      if (description != null) 'description': description,
      if (assignedTo != null) 'assigned_to': assignedTo,
      if (startDate != null) 'start_date': startDate,
      if (dueDate != null) 'due_date': dueDate,
      'priority': priority,
    };
    final data = await _phase14Json(
      'PATCH',
      'projects/$projectId/tasks/$taskId',
      body: payload,
    );
    return data['message']?.toString() ?? 'تم تحديث المهمة.';
  }

  static Future<String> deleteProjectTask({
    required int projectId,
    required int taskId,
  }) async {
    final data = await _phase14Json(
      'DELETE',
      'projects/$projectId/tasks/$taskId',
    );
    return data['message']?.toString() ?? 'تم حذف المهمة.';
  }

  static Future<Map<String, dynamic>> updateTaskStatus({
    required int projectId,
    required int taskId,
    required String status,
    required int progress,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/projects/$projectId/tasks/$taskId/status'),
      headers: await _headers(auth: true),
      body: jsonEncode({'status': status, 'progress': progress}),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<List<dynamic>> fetchProjectBoqs(int projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/boqs'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body as List<dynamic>;
    throw ApiException(
      _extractErrorMessage({'message': 'تعذر تحميل جداول الكميات'}),
    );
  }

  static Future<Map<String, dynamic>> fetchProjectBoqDetail(
    int projectId,
    int boqId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/boqs/$boqId'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<List<dynamic>> fetchProjectGantt(int projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/gantt'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body as List<dynamic>;
    throw ApiException(
      _extractErrorMessage({'message': 'تعذر تحميل الجدول الزمني'}),
    );
  }

  static Future<List<dynamic>> fetchMyEngineerWorks() async {
    final response = await http.get(
      Uri.parse('$baseUrl/my-engineer-works'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body as List<dynamic>;
    throw ApiException(_extractErrorMessage({'message': 'تعذر تحميل أعمالك'}));
  }

  /// إضافة عمل احترافي كامل لمكتبة المهندس.
  static Future<Map<String, dynamic>> createEngineerWork({
    required String title,
    String? description,
    String? location,
    int? completionYear,
    String? projectType,
    double? area,
    String? areaUnit,
    String? projectRole,
    List<String> softwareUsed = const [],
    required List<File> images,
    List<File> beforeImages = const [],
    List<File> afterImages = const [],
    File? pdfFile,
    File? dwgFile,
    File? videoFile,
    String? videoUrl,
    File? model3dFile,
  }) async {
    final uri = Uri.parse('$baseUrl/engineer-works');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _multipartHeaders(auth: true));

    request.fields.addAll({
      'title': title,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
      if (completionYear != null) 'completion_year': completionYear.toString(),
      if (projectType != null && projectType.trim().isNotEmpty)
        'project_type': projectType.trim(),
      if (area != null) 'area': area.toString(),
      if (areaUnit != null) 'area_unit': areaUnit,
      if (projectRole != null && projectRole.trim().isNotEmpty)
        'project_role': projectRole.trim(),
      if (videoUrl != null && videoUrl.trim().isNotEmpty)
        'video_url': videoUrl.trim(),
    });

    for (var i = 0; i < softwareUsed.length; i++) {
      final value = softwareUsed[i].trim();
      if (value.isNotEmpty) request.fields['software_used[$i]'] = value;
    }

    for (final image in images) {
      request.files.add(
        await http.MultipartFile.fromPath('images[]', image.path),
      );
    }
    for (final image in beforeImages) {
      request.files.add(
        await http.MultipartFile.fromPath('before_images[]', image.path),
      );
    }
    for (final image in afterImages) {
      request.files.add(
        await http.MultipartFile.fromPath('after_images[]', image.path),
      );
    }

    if (pdfFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('pdf_file', pdfFile.path),
      );
    }
    if (dwgFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('dwg_file', dwgFile.path),
      );
    }
    if (videoFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('video_file', videoFile.path),
      );
    }
    if (model3dFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('model_3d_file', model3dFile.path),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<void> deleteEngineerWork(int workId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/engineer-works/$workId'),
      headers: await _headers(auth: true),
    );
    if (response.statusCode == 200 || response.statusCode == 204) return;
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchEngineerApplicationInfo({int? planId}) async {
    final uri = Uri.parse('$baseUrl/engineer-application/create').replace(
      queryParameters: planId == null ? null : {'plan_id': planId.toString()},
    );
    final response = await http.get(
      uri,
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<List<dynamic>> fetchMyEngineerApplications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/engineer-application/mine'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body as List<dynamic>;
    throw ApiException(_extractErrorMessage({'message': 'تعذر تحميل طلباتك'}));
  }

  /// إرسال طلب الانضمام كمهندس (أو تجديد الاشتراك).
  static Future<Map<String, dynamic>> submitEngineerApplication({
    int? specialtyId,
    File? certificateFile,
    File? cvFile,
    required File paymentReceipt,
    int? planId,
    String? couponCode,
  }) async {
    final uri = Uri.parse('$baseUrl/engineer-application');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _multipartHeaders(auth: true));

    if (specialtyId != null) {
      request.fields['specialty_id'] = specialtyId.toString();
    }
    if (planId != null) request.fields['plan_id'] = planId.toString();
    if (couponCode != null && couponCode.trim().isNotEmpty) {
      request.fields['coupon_code'] = couponCode.trim();
    }

    if (certificateFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'certificate_file',
          certificateFile.path,
        ),
      );
    }
    if (cvFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('cv_file', cvFile.path),
      );
    }
    request.files.add(
      await http.MultipartFile.fromPath('payment_receipt', paymentReceipt.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>?> fetchReviewEligibility(
    int consultationId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/consultations/$consultationId/review'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body;
    // 409 = اتقيّمت قبل كده، أو 403 = مش مستوفية الشروط بعد.
    return null;
  }

  static Future<Map<String, dynamic>> submitEngineerReview({
    required int consultationId,
    required int rating,
    String? comment,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/consultations/$consultationId/review'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'rating': rating,
        if (comment != null) 'comment': comment,
      }),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  /// تنزيل ملف عام من storage (PDF/DWG/فيديو/3D) وحفظه مؤقتًا.
  static Future<File> downloadPublicUrl({
    required String url,
    required String fileName,
  }) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw ApiException('تعذر تنزيل الملف.');
    }
    final dir = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  /// تنزيل مرفق (ملف عميل/مهندس أو مرفق رسالة شات) محفوظ محليًا مؤقتًا.
  /// بيرجع مسار الملف بعد الحفظ عشان تفتحه بـ open_filex.
  static Future<File> downloadAttachment({
    required String urlPath, // مثال: 'consultations/12/messages/33/attachment'
    required String fileName,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$urlPath'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode != 200) {
      throw ApiException('تعذر تنزيل الملف.');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  /// تنزيل رابط مرفق محمي كامل (مثل مخرجات AI داخل المحادثة).
  /// يدعم URL مطلق أو مسار /api/... ويرسل Bearer token تلقائيًا.
  static Future<File> downloadAuthenticatedUrl({
    required String url,
    required String fileName,
  }) async {
    final raw = url.trim();
    if (raw.isEmpty) {
      throw ApiException('رابط الملف غير صالح.');
    }

    final uri = raw.startsWith('http://') || raw.startsWith('https://')
        ? Uri.parse(raw)
        : raw.startsWith('/')
            ? Uri.parse('$siteBaseUrl$raw')
            : Uri.parse('$siteBaseUrl/$raw');

    final response = await http.get(
      uri,
      headers: await _headers(auth: true),
    );

    if (response.statusCode != 200) {
      throw ApiException('تعذر تنزيل الملف.');
    }

    final dir = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final resolvedName = safeName.trim().isEmpty ? 'ai_attachment' : safeName;
    final file = File('${dir.path}/$resolvedName');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  /// تحديث البيانات الشخصية. multipart لأن صورة البروفايل اختيارية.
  /// ملاحظة: بنستخدم POST + _method=PUT (method spoofing) لأن PHP
  /// مبيقرأش أجسام multipart لطلبات PUT مباشرة — نفس أسلوب Laravel القياسي.
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    required String phone,
    String? countryCode,
    String? dialCode,
    File? profilePhoto,
  }) async {
    final uri = Uri.parse('$baseUrl/profile');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _multipartHeaders(auth: true));

    request.fields.addAll({
      '_method': 'PUT',
      'name': name,
      'email': email,
      'phone': phone,
      if (countryCode != null) 'country_code': countryCode,
      if (dialCode != null) 'dial_code': dialCode,
    });

    if (profilePhoto != null) {
      request.files.add(
        await http.MultipartFile.fromPath('profile_photo', profilePhoto.path),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/profile/password'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': newPasswordConfirmation,
      }),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw ApiException(_extractErrorMessage(body));
    }
  }

  /// رفع الملف النهائي (تسليم المهندس) — ينتظر اعتماد العميل قبل تحرير المستحق.
  static Future<Map<String, dynamic>> uploadEngineerFile({
    required int consultationId,
    required File file,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/consultations/$consultationId/engineer-file',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.files.add(
      await http.MultipartFile.fromPath('engineer_file', file.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  /// اعتماد العميل اكتمال الاستشارة وتحرير حصة المهندس/المكتب من الرصيد المحجوز.
  static Future<Map<String, dynamic>> confirmConsultationCompletion(
    int consultationId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/consultations/$consultationId/confirm-completion'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(body as Map);
    }
    throw ApiException(_extractErrorMessage(body));
  }

  // ---------------------------------------------------------------------
  // أدمن / مدير مالي — مراجعة الدفعات
  // ---------------------------------------------------------------------

  static Future<List<dynamic>> fetchAdminPayments() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/payments'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body as List<dynamic>;
    throw ApiException(_extractErrorMessage({'message': 'تعذر تحميل الدفعات'}));
  }

  static Future<File> downloadPaymentReceipt(int paymentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/payments/$paymentId/receipt'),
      headers: await _headers(auth: true),
    );
    if (response.statusCode != 200) {
      throw ApiException('تعذر تنزيل إيصال الدفع.');
    }
    final contentType = response.headers['content-type'] ?? '';
    final extension = contentType.contains('pdf')
        ? 'pdf'
        : contentType.contains('png')
        ? 'png'
        : contentType.contains('jpeg') || contentType.contains('jpg')
        ? 'jpg'
        : 'bin';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/payment-receipt-$paymentId.$extension');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<Map<String, dynamic>> confirmAdminPayment(int paymentId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/payments/$paymentId/confirm'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<void> rejectAdminPayment(int paymentId, String reason) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/payments/$paymentId/reject'),
      headers: await _headers(auth: true),
      body: jsonEncode({'rejection_reason': reason}),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw ApiException(_extractErrorMessage(body));
    }
  }

  // ---------------------------------------------------------------------
  // الفواتير
  // ---------------------------------------------------------------------

  static Future<List<dynamic>> fetchInvoices() async {
    final response = await http.get(
      Uri.parse('$baseUrl/invoices'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return body as List<dynamic>;
    throw ApiException(
      _extractErrorMessage({'message': 'تعذر تحميل الفواتير'}),
    );
  }

  /// تنزيل الفاتورة كملف PDF محفوظ محليًا مؤقتًا، جاهز للفتح بـ open_filex.
  static Future<File> downloadInvoice(
    int invoiceId,
    String invoiceNumber,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/invoices/$invoiceId/download'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode != 200) {
      throw ApiException('تعذر تنزيل الفاتورة.');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$invoiceNumber.pdf');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  // ---------------------------------------------------------------------
  // المرحلة 10 — الحساب والأمان
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> createMobilePasskeyBridge() async {
    final response = await http.post(
      Uri.parse('$baseUrl/profile/security/passkeys/mobile-bridge'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchSecurityStatus() async {
    final response = await http.get(
      Uri.parse('$baseUrl/profile/security'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> enableEmailTwoFactorDetails(
    String currentPassword,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/profile/security/email-two-factor/enable'),
      headers: await _headers(auth: true),
      body: jsonEncode({'current_password': currentPassword}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> enableEmailTwoFactor(String currentPassword) async {
    final body = await enableEmailTwoFactorDetails(currentPassword);
    return twoFactorDeliveryMessage(body, 'تم إرسال رمز التحقق.');
  }

  static String? twoFactorDebugCode(Map<String, dynamic> body) {
    final raw = body['verification_code'] ?? body['code'];
    final code = raw?.toString().trim();
    if (code == null || code.isEmpty) return null;
    return code;
  }

  static String twoFactorDeliveryMessage(
    Map<String, dynamic> body,
    String fallback,
  ) {
    final message = body['message']?.toString() ?? fallback;
    final code = twoFactorDebugCode(body);
    if (code == null) return message;
    return '$message\nرمز التحقق الظاهر للتجربة: $code';
  }

  static Future<String> confirmEmailTwoFactor(String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/profile/security/email-two-factor/confirm'),
      headers: await _headers(auth: true),
      body: jsonEncode({'code': code}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم تفعيل التحقق بخطوتين.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> resendEmailTwoFactorSetupDetails() async {
    final response = await http.post(
      Uri.parse('$baseUrl/profile/security/email-two-factor/resend'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> resendEmailTwoFactorSetup() async {
    final body = await resendEmailTwoFactorSetupDetails();
    return twoFactorDeliveryMessage(body, 'تم إرسال رمز جديد.');
  }

  static Future<String> disableEmailTwoFactor(String currentPassword) async {
    final request = http.Request(
      'DELETE',
      Uri.parse('$baseUrl/profile/security/email-two-factor'),
    );
    request.headers.addAll(await _headers(auth: true));
    request.body = jsonEncode({'current_password': currentPassword});
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم تعطيل التحقق بخطوتين.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchAccountStatus() async {
    final response = await http.get(
      Uri.parse('$baseUrl/profile/account-status'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> requestAccountDeleteOtp(String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/profile/account/delete-otp'),
      headers: await _headers(auth: true),
      body: jsonEncode({'password': password}),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم إرسال رمز OTP.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> deleteAccount(String password, String otpCode) async {
    final request = http.Request(
      'DELETE',
      Uri.parse('$baseUrl/profile/account'),
    );
    request.headers.addAll(await _headers(auth: true));
    request.body = jsonEncode({'password': password, 'otp_code': otpCode});
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      await clearToken();
      return body['message']?.toString() ?? 'تم حذف الحساب.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> requestArchivedAccountRestoreOtp(String email, String password) async {
    final response = await http.post(Uri.parse('$baseUrl/account-archive/restore-otp'),
      headers: await _headers(auth: false),
      body: jsonEncode({'email': email.trim(), 'password': password}));
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body['message']?.toString() ?? 'راجع بريدك الإلكتروني.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> restoreArchivedAccount(String email, String password, String otpCode) async {
    final response = await http.post(Uri.parse('$baseUrl/account-archive/restore'),
      headers: await _headers(auth: false),
      body: jsonEncode({'email': email.trim(), 'password': password, 'otp_code': otpCode.trim()}));
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body['message']?.toString() ?? 'تمت الاستعادة.';
    throw ApiException(_extractErrorMessage(body));
  }

  // ---------------------------------------------------------------------
  // إدارة الموظفين
  // ---------------------------------------------------------------------

  static Future<List<dynamic>> fetchEmployees() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/employees'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return List<dynamic>.from(body as List);
    throw ApiException(
      _extractErrorMessage(Map<String, dynamic>.from(body as Map)),
    );
  }

  static Future<Map<String, dynamic>> createEmployee({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/employees'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  // ---------------------------------------------------------------------
  // تخصص المهندس
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchEngineerSpecialty() async {
    final response = await http.get(
      Uri.parse('$baseUrl/engineer/specialty'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> updateEngineerSpecialty({
    required int specialtyId,
    String? bio,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/engineer/specialty'),
      headers: await _headers(auth: true),
      body: jsonEncode({'specialty_id': specialtyId, 'bio': bio}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم حفظ التخصص.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  // ---------------------------------------------------------------------
  // مستحقات المهندسين
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchEngineerEarnings({
    String? search,
    String? status,
    int page = 1,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final response = await http.get(
      Uri.parse('$baseUrl/engineer-earnings').replace(queryParameters: params),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> updateEngineerEarningPercentage(
    int earningId,
    double percentage,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/engineer-earnings/$earningId/percentage'),
      headers: await _headers(auth: true),
      body: jsonEncode({'engineer_percentage': percentage}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم تحديث النسبة.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> markEngineerEarningPaid(int earningId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/engineer-earnings/$earningId/mark-paid'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم تسجيل الدفع.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  // ---------------------------------------------------------------------
  // المحادثات المباشرة
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchConversations({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/conversations?page=$page'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchConversation(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/conversations/$id'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<int> startDirectConversation(int userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/conversations/direct/$userId'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return int.parse(body['conversation_id'].toString());
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> sendConversationMessage({
    required int conversationId,
    String? message,
    File? attachment,
    File? voiceMessage,
    int? audioDuration,
    int? replyToMessageId,
  }) async {
    final uri = Uri.parse('$baseUrl/conversations/$conversationId/messages');

    final request = http.MultipartRequest('POST', uri);

    final headers = await _headers(auth: true);

    headers.remove('Content-Type');

    request.headers.addAll(headers);

    if (message != null && message.trim().isNotEmpty) {
      request.fields['message'] = message.trim();
    }

    if (replyToMessageId != null && replyToMessageId > 0) {
      request.fields['reply_to_message_id'] = replyToMessageId.toString();
    }

    if (attachment != null) {
      request.files.add(
        await http.MultipartFile.fromPath('attachment', attachment.path),
      );
    }

    if (voiceMessage != null) {
      request.files.add(
        await http.MultipartFile.fromPath('voice_message', voiceMessage.path),
      );

      request.fields['audio_duration'] =
          (audioDuration == null || audioDuration < 1 ? 1 : audioDuration)
              .toString();
    }

    final streamed = await request.send();

    final response = await http.Response.fromStream(streamed);

    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return body;
    }

    throw ApiException(_extractErrorMessage(body));
  }

  static Future<void> markConversationRead(int conversationId) async {
    await http.post(
      Uri.parse('$baseUrl/conversations/$conversationId/read'),
      headers: await _headers(auth: true),
    );
  }

  static Future<String> deleteConversationMessage({
    required int conversationId,
    required int messageId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/conversations/$conversationId/messages/$messageId'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم حذف الرسالة.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  // ---------------------------------------------------------------------
  // الدعم الفني
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchSupportTickets() async {
    final response = await http.get(
      Uri.parse('$baseUrl/support'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchSupportSettings() =>
      _phase14Json('GET', 'support-settings');

  static Future<String> updateSupportEmployee(int userId) async {
    final data = await _phase14Json(
      'PATCH',
      'support-settings',
      body: {'support_employee_id': userId},
    );
    return data['message']?.toString() ?? 'تم تحديث موظف الدعم الفني.';
  }

  static Future<Map<String, dynamic>> fetchSupportTicket(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/support/$id'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<int> createSupportTicket({
    required String subject,
    required String priority,
    String? message,
    File? attachment,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/support'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['subject'] = subject;
    request.fields['priority'] = priority;
    if (message != null && message.trim().isNotEmpty) {
      request.fields['message'] = message.trim();
    }
    if (attachment != null) {
      request.files.add(
        await http.MultipartFile.fromPath('attachment', attachment.path),
      );
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 201) {
      return int.parse(body['ticket_id'].toString());
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> sendSupportMessage({
    required int ticketId,
    String? message,
    File? attachment,
    bool isInternal = false,
    String? emailSubject,
    int? templateId,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/support/$ticketId/messages'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    if (message != null && message.trim().isNotEmpty) {
      request.fields['message'] = message.trim();
    }
    if (isInternal) request.fields['is_internal'] = '1';
    if ((emailSubject ?? '').trim().isNotEmpty)
      request.fields['email_subject'] = emailSubject!.trim();
    if (templateId != null)
      request.fields['template_id'] = templateId.toString();
    if (attachment != null) {
      request.files.add(
        await http.MultipartFile.fromPath('attachment', attachment.path),
      );
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 201) {
      return body['message']?.toString() ?? 'تم إرسال الرسالة.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> updateSupportStatus(int ticketId, String status) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/support/$ticketId/status'),
      headers: await _headers(auth: true),
      body: jsonEncode({'status': status}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم تحديث الحالة.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> escalateSupportTicket(
    int ticketId,
    String reason,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/support/$ticketId/escalate'),
      headers: await _headers(auth: true),
      body: jsonEncode({'escalation_reason': reason}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم تحويل التذكرة.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  // ---------------------------------------------------------------------
  // المساعد الذكي
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> startSupportBot({
    bool forceNewAiSession = false,
    int? ticketId,
    int? projectId,
    int? libraryId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/support-bot/start'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        if (forceNewAiSession) 'force_new_ai_session': true,
        if (ticketId != null) 'ticket_id': ticketId,
        if (projectId != null) 'project_id': projectId,
        if (libraryId != null) 'library_id': libraryId,
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchSupportBotConversations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/support-bot/conversations'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }



  static Future<Map<String, dynamic>> fetchAiWorkspace() async {
    final response = await http.get(
      Uri.parse('$baseUrl/support-bot/workspace'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body), statusCode: response.statusCode, data: body);
  }

  static Future<Map<String, dynamic>> createAiLibrary({
    required String name,
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/support-bot/workspace/libraries'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'name': name.trim(),
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      }),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(_extractErrorMessage(body), statusCode: response.statusCode, data: body);
  }

  static Future<Map<String, dynamic>> fetchAiWorkspaceConversations({
    int? projectId,
    int? libraryId,
  }) async {
    final query = <String, String>{
      if (projectId != null) 'project_id': '$projectId',
      if (libraryId != null) 'library_id': '$libraryId',
    };
    final uri = Uri.parse('$baseUrl/support-bot/workspace/conversations').replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: await _headers(auth: true));
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body), statusCode: response.statusCode, data: body);
  }

  static Future<Map<String, dynamic>> sendGuestAssistantMessage({
    required String message,
    Map<String, dynamic>? pageContext,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/smart-assistant/guest/ask'),
      headers: await _headers(auth: false),
      body: jsonEncode({
        'message': message,
        'page_context':
            pageContext ??
            const {
              'route': 'flutter_guest_smart_assistant',
              'title': 'المساعد الذكي للزائر',
            },
      }),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> renameSupportBotConversation(
    int ticketId,
    String title,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/support-bot/conversations/$ticketId'),
      headers: await _headers(auth: true),
      body: jsonEncode({'title': title.trim()}),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<String> archiveSupportBotConversation(int ticketId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/support-bot/conversations/$ticketId'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تمت أرشفة المحادثة.';
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> sendSupportBotMessage({
    required int ticketId,
    required String message,
    Map<String, dynamic>? pageContext,
    String assistantMode = 'chat',
    String assistantProfile = 'fast',
    String inputSource = 'text',
    bool regenerate = false,
    String? generationMode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/support-bot/send'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'ticket_id': ticketId,
        'message': message,
        'assistant_mode': assistantMode,
        'assistant_profile': assistantProfile,
        'input_source': inputSource,
        'regenerate': regenerate,
        // AI design service picked in the UI: image | edit_image | video.
        if (generationMode != null) 'generation_mode': generationMode,
        'page_context':
            pageContext ??
            {
              'route': 'flutter_support_bot',
              'title': 'تطبيق منصة الوليد الهندسية',
            },
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> runSupportBotAgentAction({
    required int ticketId,
    required String actionId,
    required String command,
    required String previewHash,
    String? instruction,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/support-bot/send'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'ticket_id': ticketId,
        'agent_action_id': actionId,
        'agent_action_command': command,
        'agent_action_hash': previewHash,
        if (instruction != null && instruction.trim().isNotEmpty)
          'agent_action_instruction': instruction.trim(),
      }),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> analyzeSupportBotFile({
    required int ticketId,
    required String message,
    required File file,
    Map<String, dynamic>? pageContext,
    String assistantProfile = 'programming',
    String? generationMode,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/support-bot/analyze-file'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['ticket_id'] = ticketId.toString();
    request.fields['message'] = message.trim();
    request.fields['assistant_profile'] = assistantProfile;
    if (generationMode != null) request.fields['generation_mode'] = generationMode;

    final context =
        pageContext ??
        const <String, dynamic>{
          'route': 'flutter_smart_assistant',
          'title': 'المساعد الذكي في التطبيق',
        };
    for (final entry in context.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (entry.key == 'parameters' && value is Map) {
        for (final param in value.entries) {
          request.fields['page_context[parameters][${param.key}]'] =
              param.value?.toString() ?? '';
        }
      } else {
        request.fields['page_context[${entry.key}]'] = value.toString();
      }
    }

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await http.Response.fromStream(await request.send());
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  // ---------------------------------------------------------------------
  // Phase 9.5 — Assistant Settings / Personalization
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchAssistantSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/assistant-settings'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> updateAssistantSettings(
    Map<String, dynamic> values,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/assistant-settings'),
      headers: await _headers(auth: true),
      body: jsonEncode(values),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> fetchAdminPermissions({
    String? query,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/permissions').replace(
      queryParameters: (query ?? '').trim().isEmpty
          ? null
          : {'q': query!.trim()},
    );
    final response = await http.get(uri, headers: await _headers(auth: true));
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> updateAdminPermissions(
    int userId,
    Map<String, dynamic> values,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/permissions/users/$userId'),
      headers: await _headers(auth: true),
      body: jsonEncode(values),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> updateAdminJobTitlePermissions({
    required String role,
    required String jobTitle,
    required List<String> permissions,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/permissions/job-titles'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'role': role,
        'job_title': jobTitle,
        'permissions': permissions,
      }),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> updateAdminUserPermissionExtras(
    int userId,
    List<String> extraPermissions,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/permissions/users/$userId/extras'),
      headers: await _headers(auth: true),
      body: jsonEncode({'extra_permissions': extraPermissions}),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  // ---------------------------------------------------------------------
  // SaaS Phase 8 — AI Premium, Credits & Billing
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchAiPremium({
    String country = 'PS',
  }) async {
    final uri = Uri.parse(
      '$baseUrl/ai-premium',
    ).replace(queryParameters: {'country': country});
    final response = await http.get(uri, headers: await _headers(auth: true));
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> purchaseAiPlan({
    required int planId,
    required String countryCode,
    required int platformPaymentMethodId,
    File? receipt,
    String? couponCode,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/ai-premium/plans/purchase'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['ai_plan_id'] = '$planId';
    request.fields['payment_country_code'] = countryCode;
    request.fields['platform_payment_method_id'] = '$platformPaymentMethodId';
    if ((couponCode ?? '').trim().isNotEmpty)
      request.fields['coupon_code'] = couponCode!.trim();
    if (receipt != null)
      request.files.add(
        await http.MultipartFile.fromPath('receipt', receipt.path),
      );
    final response = await http.Response.fromStream(await request.send());
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> purchaseAiCredits({
    required int packageId,
    required String targetScope,
    required String countryCode,
    required int platformPaymentMethodId,
    File? receipt,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/ai-premium/credits/purchase'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['ai_credit_package_id'] = '$packageId';
    request.fields['target_scope'] = targetScope;
    request.fields['payment_country_code'] = countryCode;
    request.fields['platform_payment_method_id'] = '$platformPaymentMethodId';
    if (receipt != null)
      request.files.add(
        await http.MultipartFile.fromPath('receipt', receipt.path),
      );
    final response = await http.Response.fromStream(await request.send());
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> analyzeAiFile({
    required File file,
    required String prompt,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/ai-premium/analyze'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['prompt'] = prompt;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await http.Response.fromStream(await request.send());
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<String> cancelAiOrder(int orderId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/ai-premium/orders/$orderId/cancel'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم إلغاء الطلب.';
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> fetchAdminAiPremium() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/ai-premium'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> approveAiOrder(
    int orderId,
    String providerReference,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/ai-premium/orders/$orderId/approve'),
      headers: await _headers(auth: true),
      body: jsonEncode({'provider_reference': providerReference}),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> rejectAiOrder(
    int orderId,
    String reason,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/ai-premium/orders/$orderId/reject'),
      headers: await _headers(auth: true),
      body: jsonEncode({'reason': reason}),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> adjustAiWallet(
    int walletId,
    int credits, {
    String? note,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/ai-premium/wallets/$walletId/adjust'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'credits': credits,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> updateAiRuntimeSettings(
    Map<String, dynamic> settings,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/ai-premium/settings'),
      headers: await _headers(auth: true),
      body: jsonEncode(settings),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> updateAiPlan(
    int planId,
    Map<String, dynamic> values,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/ai-premium/plans/$planId'),
      headers: await _headers(auth: true),
      body: jsonEncode(values),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> updateAiCreditPackage(
    int packageId,
    Map<String, dynamic> values,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/ai-premium/credit-packages/$packageId'),
      headers: await _headers(auth: true),
      body: jsonEncode(values),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  // ---------------------------------------------------------------------
  // إدارة طلبات المهندسين والأعمال والتقييمات
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchAdminEngineerApplications({
    int page = 1,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/engineer-applications').replace(
      queryParameters: {'page': page.toString()},
    );
    final response = await http.get(
      uri,
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> fetchAdminEngineerSubscriptions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/engineer-subscriptions'),
      headers: await _headers(auth: true),
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{'message': 'استجابة غير متوقعة من الخادم.'};
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> approveEngineerApplication({
    required int id,
    required int membershipDays,
    String? note,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/engineer-applications/$id/approve'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'membership_days': membershipDays,
        if (note != null) 'admin_note': note,
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تمت الموافقة.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> rejectEngineerApplication(int id, String note) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/engineer-applications/$id/reject'),
      headers: await _headers(auth: true),
      body: jsonEncode({'admin_note': note}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم الرفض.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<List<dynamic>> fetchAdminEngineerWorks() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/engineer-works'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return List<dynamic>.from(body as List);
    throw ApiException(
      _extractErrorMessage(Map<String, dynamic>.from(body as Map)),
    );
  }

  static Future<String> reviewEngineerWork({
    required int id,
    required bool approve,
    String? note,
  }) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/admin/engineer-works/$id/${approve ? 'approve' : 'reject'}',
      ),
      headers: await _headers(auth: true),
      body: jsonEncode(
        approve ? <String, dynamic>{} : <String, dynamic>{'admin_note': note},
      ),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تحديث العمل.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchAdminReviews() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/reviews'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> updateAdminReview(int id, String action) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/reviews/$id/$action'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تحديث التقييم.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> deleteAdminEngineerWork(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/engineer-works/$id'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم حذف العمل.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> deleteAdminReview(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/reviews/$id'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم حذف التقييم.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchSupportBotMessages(
    int ticketId, {
    int afterId = 0,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/support-bot/tickets/$ticketId/messages',
      ).replace(queryParameters: {'after_id': afterId.toString()}),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> resolveSupportBot(int ticketId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/support-bot/tickets/$ticketId/resolve'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم إغلاق المحادثة.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> transferSupportBot(int ticketId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/support-bot/tickets/$ticketId/transfer'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  // ---------------------------------------------------------------------
  // باقات المهندس — التخزين السحابي وحدود الفرق والأعضاء
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchEngineerCloudPlan() async {
    final response = await http.get(
      Uri.parse('$baseUrl/engineer/cloud-plan'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> requestEngineerCloudPlan({
    required int planId,
    String? paymentReference,
    File? receipt,
    String? couponCode,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/engineer/cloud-plan/request'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['plan_id'] = '$planId';
    if ((couponCode ?? '').trim().isNotEmpty)
      request.fields['coupon_code'] = couponCode!.trim();
    if ((paymentReference ?? '').trim().isNotEmpty) {
      request.fields['payment_reference'] = paymentReference!.trim();
    }
    if (receipt != null) {
      request.files.add(
        await http.MultipartFile.fromPath('payment_receipt', receipt.path),
      );
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = _safeResponseMap(response);
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>>
  fetchAdminEngineerCloudPlanOrders() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/engineer-cloud-plan-orders'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> reviewEngineerCloudPlanOrder(
    int orderId, {
    required bool approve,
    String? note,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/engineer-cloud-plan-orders/$orderId'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'decision': approve ? 'approve' : 'reject',
        if ((note ?? '').trim().isNotEmpty) 'admin_note': note!.trim(),
      }),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تحديث الطلب.';
    throw ApiException(_extractErrorMessage(body));
  }

  // ---------------------------------------------------------------------
  // المرحلة 11 — المكاتب الهندسية
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchOffices({
    String? query,
    String? status,
    int? specialtyId,
    bool verified = false,
    String sort = 'name',
  }) async {
    final uri = Uri.parse('$baseUrl/offices').replace(
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (specialtyId != null) 'specialty_id': specialtyId.toString(),
        if (verified) 'verified': '1',
        'sort': sort,
      },
    );
    final response = await http.get(uri, headers: await _headers(auth: true));
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchOffice(String slug) async {
    final response = await http.get(
      Uri.parse('$baseUrl/offices/$slug'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> submitOfficeReview({
    required String officeSlug,
    required int projectId,
    required int rating,
    String? comment,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/offices/$officeSlug/reviews'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'project_id': projectId,
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return body['message']?.toString() ?? 'تم نشر التقييم.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> createOfficePortfolioWork({
    required String title,
    String? description,
    String? location,
    String? completedAt,
    File? cover,
    List<File> media = const [],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/office/portfolio'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields.addAll({
      'title': title.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
      if (completedAt != null && completedAt.trim().isNotEmpty)
        'completed_at': completedAt.trim(),
    });

    if (cover != null) {
      request.files.add(await http.MultipartFile.fromPath('cover', cover.path));
    }

    for (final file in media) {
      request.files.add(
        await http.MultipartFile.fromPath('media[]', file.path),
      );
    }

    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return body['message']?.toString() ?? 'تم نشر العمل.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> updateOfficePortfolioWork({
    required int workId,
    required String title,
    String? description,
    String? location,
    String? completedAt,
    File? cover,
    List<File> media = const [],
    List<int> removeMediaIds = const [],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/office/portfolio/$workId'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields.addAll({
      'title': title.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
      if (completedAt != null && completedAt.trim().isNotEmpty)
        'completed_at': completedAt.trim(),
    });

    for (final mediaId in removeMediaIds) {
      request.fields['remove_media_ids[$mediaId]'] = mediaId.toString();
    }

    if (cover != null) {
      request.files.add(await http.MultipartFile.fromPath('cover', cover.path));
    }
    for (final file in media) {
      request.files.add(
        await http.MultipartFile.fromPath('media[]', file.path),
      );
    }

    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم تحديث العمل.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> deleteOfficePortfolioWork(int workId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/office/portfolio/$workId'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم حذف العمل.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchOfficeApplicationStatus() async {
    final response = await http.get(
      Uri.parse('$baseUrl/office-application/status'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> submitOfficeApplication({
    required String officeName,
    required String email,
    required String phone,
    required String commercialRegistration,
    required String licenseNumber,
    required String country,
    required String city,
    required String address,
    String? notes,
    required File commercialRegistrationFile,
    required File licenseDocument,
    int? planId,
    String? couponCode,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/office-application'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields.addAll({
      'office_name': officeName,
      'email': email,
      'phone': phone,
      'commercial_registration': commercialRegistration,
      'license_number': licenseNumber,
      'country': country,
      'city': city,
      'address': address,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'terms': '1',
      if (planId != null) 'plan_id': planId.toString(),
      if (couponCode != null && couponCode.trim().isNotEmpty) 'coupon_code': couponCode.trim(),
    });
    request.files.add(
      await http.MultipartFile.fromPath(
        'commercial_registration_file',
        commercialRegistrationFile.path,
      ),
    );
    request.files.add(
      await http.MultipartFile.fromPath(
        'license_document',
        licenseDocument.path,
      ),
    );
    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<List<dynamic>> fetchMyOfficeMembershipApplications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/office-membership-applications/mine'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return List<dynamic>.from(body as List);
    throw ApiException(
      _extractErrorMessage(Map<String, dynamic>.from(body as Map)),
    );
  }

  static Future<String> submitOfficeMembershipApplication({
    required String officeSlug,
    required int specialtyId,
    String? requestedPosition,
    int? yearsOfExperience,
    String? message,
    required File cv,
    required File certificate,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/offices/$officeSlug/membership-applications'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields.addAll({
      'specialty_id': specialtyId.toString(),
      if (requestedPosition != null) 'requested_position': requestedPosition,
      if (yearsOfExperience != null)
        'years_of_experience': yearsOfExperience.toString(),
      if (message != null) 'message': message,
    });
    request.files.add(await http.MultipartFile.fromPath('cv', cv.path));
    request.files.add(
      await http.MultipartFile.fromPath('certificate', certificate.path),
    );
    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return body['message']?.toString() ?? 'تم إرسال الطلب.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchOfficeDashboard() async {
    final response = await http.get(
      Uri.parse('$baseUrl/office/dashboard'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchOfficeFieldManagement() async {
    final response = await http.get(
      Uri.parse('$baseUrl/office/field-management'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchOfficeDrawingReviews() async {
    final response = await http.get(
      Uri.parse('$baseUrl/office/drawing-reviews'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchEngineerFieldManagement() async {
    final response = await http.get(
      Uri.parse('$baseUrl/engineer/field-management'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchEngineerDrawingReviews() async {
    final response = await http.get(
      Uri.parse('$baseUrl/engineer/drawing-reviews'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> updateOfficeProfile({
    required Map<String, String> fields,
    File? logo,
    File? cover,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/office/profile'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields.addAll(fields);
    if (logo != null)
      request.files.add(await http.MultipartFile.fromPath('logo', logo.path));
    if (cover != null)
      request.files.add(await http.MultipartFile.fromPath('cover', cover.path));
    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تحديث المكتب.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> updateOfficeMember({
    required int memberId,
    required String officeRole,
    required String status,
    String? position,
    int? specialtyId,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/office/members/$memberId'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'office_role': officeRole,
        'status': status,
        'position': position,
        'specialty_id': specialtyId,
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تحديث العضو.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> removeOfficeMember(int memberId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/office/members/$memberId'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تمت إزالة العضو.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> reviewOfficeMembershipApplication({
    required int applicationId,
    required String decision,
    String? position,
    String? rejectionReason,
  }) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/office/membership-applications/$applicationId/review',
      ),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'decision': decision,
        if (position != null) 'position': position,
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تمت مراجعة الطلب.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchOfficeSubscription() async {
    final response = await http.get(
      Uri.parse('$baseUrl/office/subscription'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> submitOfficeSubscription({
    required int planId,
    required String billingCycle,
    required String paymentMethod,
    required String countryCode,
    required int platformPaymentMethodId,
    String? paymentReference,
    String? notes,
    String? couponCode,
    File? receipt,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/office/subscription'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields.addAll({
      'saas_plan_id': planId.toString(),
      'billing_cycle': billingCycle,
      'payment_method': paymentMethod,
      'payment_country_code': countryCode,
      'platform_payment_method_id': platformPaymentMethodId.toString(),
      if (paymentReference != null && paymentReference.trim().isNotEmpty)
        'payment_reference': paymentReference.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (couponCode != null && couponCode.trim().isNotEmpty)
        'coupon_code': couponCode.trim(),
    });
    if (receipt != null)
      request.files.add(
        await http.MultipartFile.fromPath('receipt', receipt.path),
      );
    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> cancelOfficeSubscription() async {
    final response = await http.post(
      Uri.parse('$baseUrl/office/subscription/cancel'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تمت جدولة الإلغاء.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> resumeOfficeSubscription() async {
    final response = await http.post(
      Uri.parse('$baseUrl/office/subscription/resume'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم التراجع عن الإلغاء.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> assignOfficeConsultationEngineer(
    int consultationId,
    int engineerId,
  ) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/office/consultations/$consultationId/assign-engineer',
      ),
      headers: await _headers(auth: true),
      body: jsonEncode({'engineer_id': engineerId}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تعيين المهندس.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchAdminOfficeApplications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/office-applications'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<File> downloadAdminOfficeApplicationFile({
    required int applicationId,
    required String type,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/office-applications/$applicationId/file/$type'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      Map<String, dynamic> body = const {};
      try {
        body = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map,
        );
      } catch (_) {}
      throw ApiException(_extractErrorMessage(body));
    }

    final dir = await getTemporaryDirectory();
    final extension = _extensionFromContentType(
      response.headers['content-type'],
    );
    final file = File(
      '${dir.path}/office-application-$applicationId-$type$extension',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<String> reviewAdminOfficeApplication({
    required int applicationId,
    required String decision,
    String? rejectionReason,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/office-applications/$applicationId/review'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'decision': decision,
        if (rejectionReason != null && rejectionReason.trim().isNotEmpty)
          'rejection_reason': rejectionReason.trim(),
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تمت مراجعة الطلب.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchAdminOfficeSubscriptions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/office-subscriptions'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<File> downloadAdminOfficeSubscriptionReceipt({
    required int subscriptionId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/office-subscriptions/$subscriptionId/receipt'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      Map<String, dynamic> body = const {};
      try {
        body = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map,
        );
      } catch (_) {}
      throw ApiException(_extractErrorMessage(body));
    }

    final dir = await getTemporaryDirectory();
    final extension = _extensionFromContentType(
      response.headers['content-type'],
    );
    final file = File(
      '${dir.path}/office-subscription-$subscriptionId-receipt$extension',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<String> reviewAdminOfficeSubscription({
    required int subscriptionId,
    required String decision,
    String? rejectionReason,
    String? notes,
    int durationValue = 1,
    String durationUnit = 'month',
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/office-subscriptions/$subscriptionId/review'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'decision': decision,
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
        if (notes != null) 'notes': notes,
        'duration_value': durationValue,
        'duration_unit': durationUnit,
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تمت مراجعة الاشتراك.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchMyPayoutAccount() async {
    final response = await http.get(
      Uri.parse('$baseUrl/payout-account/mine'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> saveMyPayoutAccount(
    Map<String, dynamic> fields,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payout-account/mine'),
      headers: await _headers(auth: true),
      body: jsonEncode(fields),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchOfficePayoutAccount() async {
    final response = await http.get(
      Uri.parse('$baseUrl/office/payout-account'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> saveOfficePayoutAccount(
    Map<String, dynamic> fields,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/office/payout-account'),
      headers: await _headers(auth: true),
      body: jsonEncode(fields),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<List<dynamic>> fetchAdminPayoutAccounts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/payout-accounts'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return List<dynamic>.from(body['data'] as List? ?? const []);
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> verifyAdminPayoutAccount(int id) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/payout-accounts/$id/verify'),
      headers: await _headers(auth: true),
      body: jsonEncode(const {}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم توثيق الحساب.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> rejectAdminPayoutAccount(int id, String reason) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/payout-accounts/$id/reject'),
      headers: await _headers(auth: true),
      body: jsonEncode({'rejection_reason': reason}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم رفض الحساب.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<List<dynamic>> fetchAdminOffices() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/offices'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return List<dynamic>.from(body as List);
    throw ApiException(
      _extractErrorMessage(Map<String, dynamic>.from(body as Map)),
    );
  }

  static Future<String> assignAdminOfficeSaasPlan({
    required String officeSlug,
    required int planId,
  }) async {
    final response = await http.put(
      Uri.parse(
        '$baseUrl/admin/offices/${Uri.encodeComponent(officeSlug)}/saas-plan',
      ),
      headers: await _headers(auth: true),
      body: jsonEncode({'saas_plan_id': planId}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body['message']?.toString() ?? 'تم تغيير باقة المكتب.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> updateAdminOfficeStatus({
    required String officeSlug,
    required String status,
    String? reason,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/offices/$officeSlug/status'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'status': status,
        if (reason != null) 'reason': reason,
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تحديث المكتب.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>>
  fetchAdminConsultationOfficeAssignments() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/consultation-office-assignments'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> assignAdminConsultationEngineer({
    required int consultationId,
    required int engineerId,
    String status = 'in_progress',
    String? startedAt,
    String? expectedDeliveryAt,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/consultations/$consultationId/assign-engineer'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'engineer_id': engineerId,
        'status': status,
        if (startedAt != null && startedAt.trim().isNotEmpty)
          'started_at': startedAt.trim(),
        if (expectedDeliveryAt != null && expectedDeliveryAt.trim().isNotEmpty)
          'expected_delivery_at': expectedDeliveryAt.trim(),
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تعيين المهندس.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> assignConsultationToOffice({
    required int consultationId,
    required int officeId,
    String? notes,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/consultations/$consultationId/assign-office'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'office_id': officeId,
        if (notes != null) 'notes': notes,
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تحويل الاستشارة.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> unassignConsultationFromOffice(
    int consultationId,
  ) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/consultations/$consultationId/assign-office'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم إلغاء التحويل.';
    throw ApiException(_extractErrorMessage(body));
  }

  // ---------------------------------------------------------------------
  // المرحلة 12 — دورة المشروع والدفعات والضمان والفريق والإغلاق المالي
  // ---------------------------------------------------------------------

  static Future<List<dynamic>> fetchProjectRequests() async {
    final response = await http.get(
      Uri.parse('$baseUrl/project-requests'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return List<dynamic>.from(body as List);
    throw ApiException(
      _extractErrorMessage(Map<String, dynamic>.from(body as Map)),
    );
  }

  static Future<Map<String, dynamic>> requestFullProject(
    int consultationId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/consultations/$consultationId/request-project'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchProjectRequest(int requestId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/project-requests/$requestId'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> submitProjectProposal({
    required int requestId,
    required String scope,
    required double price,
    required int durationDays,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/project-requests/$requestId/proposals'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'scope': scope,
        'price': price,
        'duration_days': durationDays,
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return body['message']?.toString() ?? 'تم إرسال العرض.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> approveProjectProposal({
    required int requestId,
    required int proposalId,
  }) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/project-requests/$requestId/proposals/$proposalId/approve',
      ),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> addProjectInstallment({
    required int projectId,
    required String title,
    required double percentage,
    required String dueDate,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/installments'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'title': title,
        'percentage': percentage,
        'due_date': dueDate,
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return body['message']?.toString() ?? 'تمت إضافة الدفعة.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> updateProjectInstallment({
    required int projectId,
    required int installmentId,
    required String title,
    required double percentage,
    required String dueDate,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/projects/$projectId/installments/$installmentId'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'title': title,
        'percentage': percentage,
        'due_date': dueDate,
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم تعديل الدفعة.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchProjectInstallmentPaymentInfo({
    required int projectId,
    required int installmentId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/projects/$projectId/installments/$installmentId/payment',
      ),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> initiateProjectInstallmentPayment({
    required int projectId,
    required int installmentId,
    required String countryCode,
    required int platformPaymentMethodId,
    File? receipt,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '$baseUrl/projects/$projectId/installments/$installmentId/payment',
      ),
    );
    request.headers.addAll(
      await _headers(auth: true)
        ..remove('Content-Type'),
    );
    request.fields['payment_country_code'] = countryCode;
    request.fields['platform_payment_method_id'] = platformPaymentMethodId
        .toString();
    if (receipt != null)
      request.files.add(
        await http.MultipartFile.fromPath('receipt', receipt.path),
      );
    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<File> downloadProjectInstallmentReceipt({
    required int projectId,
    required int installmentId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/projects/$projectId/installments/$installmentId/receipt',
      ),
      headers: await _headers(auth: true),
    );
    if (response.statusCode != 200)
      throw ApiException('تعذر تنزيل إيصال الدفعة.');
    final dir = await getTemporaryDirectory();
    final contentType = response.headers['content-type'] ?? '';
    final ext = contentType.contains('pdf') ? 'pdf' : 'jpg';
    final file = File(
      '${dir.path}/project-$projectId-installment-$installmentId-receipt.$ext',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<String> confirmProjectInstallment({
    required int projectId,
    required int installmentId,
  }) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/projects/$projectId/installments/$installmentId/confirm',
      ),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تأكيد الدفعة.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> rejectProjectInstallment({
    required int projectId,
    required int installmentId,
    required String reason,
  }) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/projects/$projectId/installments/$installmentId/reject',
      ),
      headers: await _headers(auth: true),
      body: jsonEncode({'rejection_reason': reason}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم رفض الدفعة.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchProjectEscrow(int projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/escrow'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> fundProjectEscrow({
    required int projectId,
    required int installmentId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/escrow/fund'),
      headers: await _headers(auth: true),
      body: jsonEncode({'project_installment_id': installmentId}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return body['message']?.toString() ?? 'تم تمويل الضمان.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> releaseProjectEscrow({
    required int projectId,
    required int escrowId,
    required String reason,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/escrow/$escrowId/release'),
      headers: await _headers(auth: true),
      body: jsonEncode({'reason': reason}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم الإفراج عن الضمان.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchProjectTeam(int projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/team'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> addProjectTeamMember({
    required int projectId,
    required int engineerId,
    String? teamRole,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/team'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'engineer_id': engineerId,
        if (teamRole != null && teamRole.trim().isNotEmpty)
          'team_role': teamRole.trim(),
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return body['message']?.toString() ?? 'تمت إضافة المهندس.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> removeProjectTeamMember({
    required int projectId,
    required int teamMemberId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/projects/$projectId/team/$teamMemberId'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم حذف المهندس.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> setProjectEngineerAllocation({
    required int projectId,
    required int engineerId,
    required double percentage,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/engineer-allocations'),
      headers: await _headers(auth: true),
      body: jsonEncode({'engineer_id': engineerId, 'percentage': percentage}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return body['message']?.toString() ?? 'تم حفظ نسبة المهندس.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> removeProjectEngineerAllocation({
    required int projectId,
    required int allocationId,
  }) async {
    final response = await http.delete(
      Uri.parse(
        '$baseUrl/projects/$projectId/engineer-allocations/$allocationId',
      ),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم إلغاء نسبة المهندس.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchProjectEngineerEarnings({
    String? status,
  }) async {
    final uri = Uri.parse('$baseUrl/financial/project-engineer-earnings')
        .replace(
          queryParameters: status == null || status.isEmpty
              ? null
              : {'status': status},
        );
    final response = await http.get(uri, headers: await _headers(auth: true));
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> markProjectEngineerEarningPaid(int earningId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/financial/project-engineer-earnings/$earningId/paid'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تسجيل الدفع.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchProjectOfficeEarnings({
    String? project,
    int? officeId,
    String? status,
  }) async {
    final uri = Uri.parse('$baseUrl/financial/project-office-earnings').replace(
      queryParameters: {
        if (project != null && project.trim().isNotEmpty)
          'project': project.trim(),
        if (officeId != null && officeId > 0)
          'office_id': officeId.toString(),
        if (status != null && status.trim().isNotEmpty)
          'status': status.trim(),
      },
    );
    final response = await http.get(
      uri,
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> setProjectOfficePercentage({
    required int projectId,
    required double percentage,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/office-percentage'),
      headers: await _headers(auth: true),
      body: jsonEncode({'office_percentage': percentage}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تحديث النسبة.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> markProjectOfficeEarningPaid(int earningId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/financial/project-office-earnings/$earningId/paid'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تسجيل الدفع.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchProjectFinancialClosing() async {
    final response = await http.get(
      Uri.parse('$baseUrl/financial/project-closing'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> closeProjectFinancially(int projectId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/financial/project-closing/$projectId/close'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم الإغلاق المالي.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> reopenProjectFinancially({
    required int projectId,
    required String reason,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/financial/project-closing/$projectId/reopen'),
      headers: await _headers(auth: true),
      body: jsonEncode({'reopen_reason': reason}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تمت إعادة الفتح.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchAuditLogs({
    String? search,
    String? category,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/audit-logs').replace(
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
      },
    );
    final response = await http.get(uri, headers: await _headers(auth: true));
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  // ---------------------------------------------------------------------
  // المرحلة 13 — التنفيذ المتقدم للمشروع
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchProjectExecutionDashboard(
    int projectId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/execution-dashboard'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchMilestoneSubmissions({
    required int projectId,
    required int milestoneId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/projects/$projectId/milestones/$milestoneId/submissions',
      ),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> submitMilestoneSubmission({
    required int projectId,
    required int milestoneId,
    required int installmentId,
    required String title,
    String? notes,
    File? file,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '$baseUrl/projects/$projectId/milestones/$milestoneId/submissions',
      ),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['project_installment_id'] = installmentId.toString();
    request.fields['title'] = title;
    if (notes != null && notes.trim().isNotEmpty)
      request.fields['notes'] = notes.trim();
    if (file != null)
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return body['message']?.toString() ?? 'تم إرسال التسليم.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> reviewMilestoneSubmission({
    required int projectId,
    required int milestoneId,
    required int submissionId,
    required bool approve,
    String? notes,
  }) async {
    final action = approve ? 'approve' : 'reject';
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/projects/$projectId/milestones/$milestoneId/submissions/$submissionId/$action',
      ),
      headers: await _headers(auth: true),
      body: jsonEncode({'review_notes': notes}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم حفظ القرار.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<File> downloadMilestoneSubmission({
    required int projectId,
    required int milestoneId,
    required int submissionId,
    String fileName = 'milestone-submission',
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/projects/$projectId/milestones/$milestoneId/submissions/$submissionId/download',
      ),
      headers: await _headers(auth: true),
    );
    if (response.statusCode != 200)
      throw ApiException('تعذر تنزيل ملف التسليم.');
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(
      '${dir.path}/${safe.isEmpty ? 'milestone-submission' : safe}',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<Map<String, dynamic>> fetchProjectFileVersions({
    required int projectId,
    required int fileId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/files/$fileId/versions'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> uploadProjectFileVersion({
    required int projectId,
    required int fileId,
    required File file,
    String? changeNotes,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/projects/$projectId/files/$fileId/versions'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    if (changeNotes != null && changeNotes.trim().isNotEmpty) {
      request.fields['change_notes'] = changeNotes.trim();
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return body['message']?.toString() ?? 'تم رفع الإصدار.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> reviewProjectFileVersion({
    required int projectId,
    required int fileId,
    required int versionId,
    required bool approve,
    String? notes,
  }) async {
    final action = approve ? 'approve' : 'reject';
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/projects/$projectId/files/$fileId/versions/$versionId/$action',
      ),
      headers: await _headers(auth: true),
      body: jsonEncode({'review_notes': notes}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم حفظ القرار.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> revokeProjectFileCustomerAccess({
    required int projectId,
    required int fileId,
    String? notes,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/projects/$projectId/files/$fileId/revoke-customer'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        if (notes != null && notes.trim().isNotEmpty)
          'review_notes': notes.trim(),
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return body['message']?.toString() ?? 'تم سحب إتاحة الملف من العميل.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<File> downloadProjectFileVersion({
    required int projectId,
    required int fileId,
    required int versionId,
    required String fileName,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/projects/$projectId/files/$fileId/versions/$versionId/download',
      ),
      headers: await _headers(auth: true),
    );
    if (response.statusCode != 200)
      throw ApiException('تعذر تنزيل إصدار الملف.');
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}/${safe.isEmpty ? 'project-file' : safe}');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  // Phase 3 — Drawing Markup / version review overlays.
  static Future<Map<String, dynamic>> fetchProjectFileMarkups({
    required int projectId,
    required int fileId,
    required int versionId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/projects/$projectId/files/$fileId/versions/$versionId/markups',
      ),
      headers: await _headers(auth: true),
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> createProjectFileMarkup({
    required int projectId,
    required int fileId,
    required int versionId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/projects/$projectId/files/$fileId/versions/$versionId/markups',
      ),
      headers: await _headers(auth: true),
      body: jsonEncode(payload),
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> updateProjectFileMarkup({
    required int projectId,
    required int fileId,
    required int versionId,
    required int markupId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/projects/$projectId/files/$fileId/versions/$versionId/markups/$markupId',
      ),
      headers: await _headers(auth: true),
      body: jsonEncode(payload),
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 409) {
      body['_http_status'] = response.statusCode;
      return body;
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> resolveProjectFileMarkup({
    required int projectId,
    required int fileId,
    required int versionId,
    required int markupId,
  }) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/projects/$projectId/files/$fileId/versions/$versionId/markups/$markupId/resolve',
      ),
      headers: await _headers(auth: true),
      body: jsonEncode(const <String, dynamic>{}),
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> deleteProjectFileMarkup({
    required int projectId,
    required int fileId,
    required int versionId,
    required int markupId,
  }) async {
    final response = await http.delete(
      Uri.parse(
        '$baseUrl/projects/$projectId/files/$fileId/versions/$versionId/markups/$markupId',
      ),
      headers: await _headers(auth: true),
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم حذف طبقة الملاحظات.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchProjectRfis({
    required int projectId,
    String? status,
    String? priority,
    String? query,
  }) async {
    final uri = Uri.parse('$baseUrl/projects/$projectId/rfis').replace(
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (priority != null && priority.isNotEmpty) 'priority': priority,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    final response = await http.get(uri, headers: await _headers(auth: true));
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchProjectRfi({
    required int projectId,
    required int rfiId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/rfis/$rfiId'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> createProjectRfi({
    required int projectId,
    required String subject,
    required String question,
    required String priority,
    int? assignedTo,
    int? relatedTaskId,
    int? relatedMilestoneId,
    String? dueAt,
    List<File> attachments = const [],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/projects/$projectId/rfis'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields.addAll({
      'subject': subject,
      'question': question,
      'priority': priority,
      if (assignedTo != null) 'assigned_to': assignedTo.toString(),
      if (relatedTaskId != null) 'related_task_id': relatedTaskId.toString(),
      if (relatedMilestoneId != null)
        'related_milestone_id': relatedMilestoneId.toString(),
      if (dueAt != null && dueAt.isNotEmpty) 'due_at': dueAt,
    });
    for (final file in attachments) {
      request.files.add(
        await http.MultipartFile.fromPath('attachments[]', file.path),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return body['message']?.toString() ?? 'تم إنشاء RFI.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> answerProjectRfi({
    required int projectId,
    required int rfiId,
    required String answer,
    List<File> attachments = const [],
  }) async {
    // PHP/Laravel يتعامل مع multipart بصورة موثوقة عبر POST مع method spoofing.
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/projects/$projectId/rfis/$rfiId/answer'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['_method'] = 'PATCH';
    request.fields['answer'] = answer;
    for (final file in attachments) {
      request.files.add(
        await http.MultipartFile.fromPath('attachments[]', file.path),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم إرسال الإجابة.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> commentProjectRfi({
    required int projectId,
    required int rfiId,
    required String bodyText,
    List<File> attachments = const [],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/projects/$projectId/rfis/$rfiId/comments'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['body'] = bodyText;
    for (final file in attachments) {
      request.files.add(
        await http.MultipartFile.fromPath('attachments[]', file.path),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201)
      return body['message']?.toString() ?? 'تمت إضافة التعليق.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<File> downloadProjectRfiAttachment({
    required int projectId,
    required int rfiId,
    required int attachmentId,
    required String fileName,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/projects/$projectId/rfis/$rfiId/attachments/$attachmentId/download',
      ),
      headers: await _headers(auth: true),
    );
    if (response.statusCode != 200) throw ApiException('تعذر تنزيل مرفق RFI.');
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}/${safe.isEmpty ? 'rfi-attachment' : safe}');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<String> changeProjectRfiStatus({
    required int projectId,
    required int rfiId,
    required String action,
    String? reason,
  }) async {
    final payload = <String, dynamic>{};
    if (action == 'close' && reason != null) payload['closure_notes'] = reason;
    if ((action == 'reopen' || action == 'cancel') && reason != null)
      payload['reason'] = reason;
    final response = await http.patch(
      Uri.parse('$baseUrl/projects/$projectId/rfis/$rfiId/$action'),
      headers: await _headers(auth: true),
      body: jsonEncode(payload),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تحديث RFI.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchProjectChangeOrders(
    int projectId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/change-orders'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> createProjectChangeOrder({
    required int projectId,
    required String title,
    required String reason,
    required double priceDelta,
    required int durationDaysDelta,
    String? scopeChange,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/change-orders'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'title': title,
        'reason': reason,
        'price_delta': priceDelta,
        'duration_days_delta': durationDaysDelta,
        if (scopeChange != null && scopeChange.trim().isNotEmpty)
          'scope_change': scopeChange.trim(),
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201)
      return body['message']?.toString() ?? 'تم إنشاء أمر التغيير.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> reviewProjectChangeOrder({
    required int projectId,
    required int changeOrderId,
    required bool approve,
    String? rejectionReason,
  }) async {
    final action = approve ? 'approve' : 'reject';
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/projects/$projectId/change-orders/$changeOrderId/$action',
      ),
      headers: await _headers(auth: true),
      body: jsonEncode({if (!approve) 'rejection_reason': rejectionReason}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم حفظ القرار.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchProjectLifecycle(
    int projectId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/lifecycle'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> projectLifecycleAction({
    required int projectId,
    required String action,
    String? reason,
  }) async {
    final payload = <String, dynamic>{};
    if (action == 'pause' && reason != null) payload['pause_reason'] = reason;
    if (action == 'reject-completion' && reason != null)
      payload['rejection_reason'] = reason;
    final response = await http.patch(
      Uri.parse('$baseUrl/projects/$projectId/lifecycle/$action'),
      headers: await _headers(auth: true),
      body: jsonEncode(payload),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تحديث حالة المشروع.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchProjectFinalReport(
    int projectId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/final-report'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<List<dynamic>> fetchProjectTeamChatMessages({
    required int projectId,
    int after = 0,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/projects/$projectId/team-chat/messages',
    ).replace(queryParameters: {'after': after.toString()});
    final response = await http.get(uri, headers: await _headers(auth: true));
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return List<dynamic>.from(body['messages'] as List? ?? const []);
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> sendProjectTeamChatMessage({
    required int projectId,
    required String bodyText,
    int? replyToMessageId,
    List<File> attachments = const [],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/projects/$projectId/team-chat/messages'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['body'] = bodyText;
    if (replyToMessageId != null)
      request.fields['reply_to_message_id'] = replyToMessageId.toString();
    for (final file in attachments) {
      request.files.add(
        await http.MultipartFile.fromPath('attachments[]', file.path),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<void> markProjectTeamChatRead({required int projectId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/team-chat/read'),
      headers: await _headers(auth: true),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final body = _safeResponseMap(response);
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<File> downloadProjectTeamChatAttachment({
    required int projectId,
    required int attachmentId,
    required String fileName,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/projects/$projectId/team-chat/attachments/$attachmentId/download',
      ),
      headers: await _headers(auth: true),
    );
    if (response.statusCode != 200)
      throw ApiException('تعذر تنزيل مرفق المحادثة.');
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}/${safe.isEmpty ? 'attachment' : safe}');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<Map<String, dynamic>> fetchRealtimeConfig() async {
    final response = await http.get(
      Uri.parse('$baseUrl/realtime/config'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchProjectMeetingLiveToken(
    int projectId,
    int meetingId,
  ) => _phase14Json(
    'POST',
    'projects/$projectId/meetings/$meetingId/live/token',
  );

  static Future<Map<String, dynamic>> startProjectMeetingLive(
    int projectId,
    int meetingId,
  ) => _phase14Json(
    'POST',
    'projects/$projectId/meetings/$meetingId/live/start',
  );

  static Future<Map<String, dynamic>> joinProjectMeetingLive(
    int projectId,
    int meetingId, {
    String? participantSid,
  }) => _phase14Json(
    'POST',
    'projects/$projectId/meetings/$meetingId/live/join',
    body: {
      if (participantSid != null && participantSid.isNotEmpty)
        'participant_sid': participantSid,
    },
  );

  static Future<Map<String, dynamic>> leaveProjectMeetingLive(
    int projectId,
    int meetingId,
  ) => _phase14Json(
    'POST',
    'projects/$projectId/meetings/$meetingId/live/leave',
  );

  static Future<Map<String, dynamic>> endProjectMeetingLive(
    int projectId,
    int meetingId,
  ) => _phase14Json('POST', 'projects/$projectId/meetings/$meetingId/live/end');

  static Future<List<dynamic>> fetchProjectMeetingLiveMessages(
    int projectId,
    int meetingId,
  ) async {
    final data = await _phase14Json(
      'GET',
      'projects/$projectId/meetings/$meetingId/live/messages',
    );
    return List<dynamic>.from(data['messages'] as List? ?? const []);
  }

  static Future<Map<String, dynamic>> sendProjectMeetingLiveMessage({
    required int projectId,
    required int meetingId,
    required String body,
  }) async {
    final data = await _phase14Json(
      'POST',
      'projects/$projectId/meetings/$meetingId/live/messages',
      body: {'body': body.trim()},
    );
    return Map<String, dynamic>.from(data['message'] as Map? ?? const {});
  }

  static Future<void> kickProjectMeetingLiveParticipant({
    required int projectId,
    required int meetingId,
    required int userId,
  }) async {
    await _phase14Json(
      'DELETE',
      'projects/$projectId/meetings/$meetingId/live/participants/$userId',
    );
  }

  static Future<void> muteProjectMeetingLiveParticipant({
    required int projectId,
    required int meetingId,
    required int userId,
    required String trackSid,
    required bool muted,
  }) async {
    await _phase14Json(
      'PATCH',
      'projects/$projectId/meetings/$meetingId/live/participants/$userId/track',
      body: {'track_sid': trackSid, 'muted': muted},
    );
  }

  static Future<List<dynamic>> fetchProjectMeetingLiveInvitees(
    int projectId,
    int meetingId, {
    String query = '',
  }) async {
    final path = 'projects/$projectId/meetings/$meetingId/live/invitees';
    final uri = Uri.parse('$baseUrl/$path').replace(
      queryParameters: query.trim().isEmpty ? null : {'q': query.trim()},
    );
    final response = await http.get(uri, headers: await _headers(auth: true));
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) {
      return List<dynamic>.from(body['users'] as List? ?? const []);
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> inviteProjectMeetingLiveUser({
    required int projectId,
    required int meetingId,
    required int userId,
  }) async {
    final data = await _phase14Json(
      'POST',
      'projects/$projectId/meetings/$meetingId/live/invite',
      body: {'user_id': userId},
    );
    return data['message']?.toString() ?? 'تم إرسال الدعوة.';
  }

  // ---------------------------------------------------------------------
  // المرحلة 14 — الإدارة الهندسية المتقدمة + قائمة إعدادات الحساب
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> _phase14Json(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl/$path');
    late http.Response response;
    final headers = await _headers(auth: auth);
    switch (method.toUpperCase()) {
      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const {}),
        );
        break;
      case 'PATCH':
        response = await http.patch(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const {}),
        );
        break;
      case 'PUT':
        response = await http.put(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const {}),
        );
        break;
      case 'DELETE':
        response = await http.delete(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const {}),
        );
        break;
      default:
        response = await http.get(uri, headers: headers);
    }
    dynamic decoded;
    if (response.bodyBytes.isEmpty) {
      decoded = <String, dynamic>{};
    } else {
      final raw = utf8.decode(response.bodyBytes, allowMalformed: true);
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        decoded = <String, dynamic>{
          'message': response.statusCode >= 500
              ? 'حدث خطأ في الخادم. حاول مرة أخرى بعد قليل.'
              : (raw.trim().isEmpty
                    ? 'تعذر قراءة استجابة الخادم.'
                    : raw.trim()),
        };
      }
    }
    final map = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{'data': decoded};
    if (response.statusCode >= 200 && response.statusCode < 300) return map;
    throw ApiException(_extractErrorMessage(map));
  }

  /// Support tools (auto assignment, Email + WhatsApp, attachment scan): /api/support-tools/*
  static Future<Map<String, dynamic>> supportToolsJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _phase14Json(method, 'support-tools/$path', body: body);

  static Future<Map<String, dynamic>> fetchCrm({
    String? query,
    String? stage,
    String? source,
  }) async {
    final uri = Uri.parse('$baseUrl/crm').replace(
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (stage != null && stage.isNotEmpty) 'stage': stage,
        if (source != null && source.isNotEmpty) 'source': source,
      },
    );
    final response = await http.get(uri, headers: await _headers(auth: true));
    final body = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(
            jsonDecode(utf8.decode(response.bodyBytes)) as Map,
          );
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchCrmLead(int leadId) =>
      _phase14Json('GET', 'crm/leads/$leadId');

  static Future<Map<String, dynamic>> saveCrmLead({
    int? leadId,
    required Map<String, dynamic> payload,
  }) => _phase14Json(
    leadId == null ? 'POST' : 'PATCH',
    leadId == null ? 'crm/leads' : 'crm/leads/$leadId',
    body: payload,
  );

  static Future<String> addCrmActivity(
    int leadId,
    Map<String, dynamic> payload,
  ) async {
    final data = await _phase14Json(
      'POST',
      'crm/leads/$leadId/activities',
      body: payload,
    );
    return data['message']?.toString() ?? 'تم تسجيل النشاط.';
  }

  static Future<String> addCrmFollowUp(
    int leadId,
    Map<String, dynamic> payload,
  ) async {
    final data = await _phase14Json(
      'POST',
      'crm/leads/$leadId/follow-ups',
      body: payload,
    );
    return data['message']?.toString() ?? 'تم إنشاء المتابعة.';
  }

  static Future<String> updateCrmFollowUp(
    int followUpId,
    Map<String, dynamic> payload,
  ) async {
    final data = await _phase14Json(
      'PATCH',
      'crm/follow-ups/$followUpId',
      body: payload,
    );
    return data['message']?.toString() ?? 'تم تحديث المتابعة.';
  }

  static Future<String> crmFollowUpAction(int followUpId, String action) async {
    final data = await _phase14Json(
      'PATCH',
      'crm/follow-ups/$followUpId/$action',
    );
    return data['message']?.toString() ?? 'تم تحديث المتابعة.';
  }

  static Future<String> addCrmOpportunity(
    int leadId,
    Map<String, dynamic> payload,
  ) async {
    final data = await _phase14Json(
      'POST',
      'crm/leads/$leadId/opportunities',
      body: payload,
    );
    return data['message']?.toString() ?? 'تم إنشاء الفرصة.';
  }

  static Future<String> updateCrmOpportunity(
    int opportunityId,
    Map<String, dynamic> payload,
  ) async {
    final data = await _phase14Json(
      'PATCH',
      'crm/opportunities/$opportunityId',
      body: payload,
    );
    return data['message']?.toString() ?? 'تم تحديث الفرصة.';
  }

  static Future<Map<String, dynamic>> convertCrmLead(
    int leadId,
    Map<String, dynamic> payload,
  ) => _phase14Json('POST', 'crm/leads/$leadId/convert', body: payload);

  static Future<Map<String, dynamic>> fetchFinancialReport({
    String? from,
    String? to,
    int? officeId,
  }) async {
    final uri = Uri.parse('$baseUrl/financial/reports').replace(
      queryParameters: {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (officeId != null) 'office_id': officeId.toString(),
      },
    );
    final response = await http.get(uri, headers: await _headers(auth: true));
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<File> downloadFinancialReportCsv({
    String? from,
    String? to,
    int? officeId,
  }) async {
    final uri = Uri.parse('$baseUrl/financial/reports/csv').replace(
      queryParameters: {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (officeId != null) 'office_id': officeId.toString(),
      },
    );
    final response = await http.get(uri, headers: await _headers(auth: true));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      Map<String, dynamic> body = const {};
      try {
        body = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map,
        );
      } catch (_) {}
      throw ApiException(_extractErrorMessage(body));
    }
    final dir = await getTemporaryDirectory();
    final disposition = response.headers['content-disposition'] ?? '';
    final match = RegExp(r'filename="?([^";]+)').firstMatch(disposition);
    final name = match?.group(1) ?? 'financial-report.csv';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<Map<String, dynamic>> fetchProfessionalVerification() =>
      _phase14Json('GET', 'profile/professional-verification');

  static Future<String> submitProfessionalVerificationApplication({
    required String subjectType,
    int? experienceYears,
    File? identity,
    File? degree,
    File? syndicate,
    File? experienceProof,
    File? registrationDocument,
    File? licenseDocument,
    String? applicantNote,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/profile/professional-verification/apply'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    if (experienceYears != null)
      request.fields['experience_years'] = experienceYears.toString();
    if (applicantNote != null && applicantNote.trim().isNotEmpty) {
      request.fields['applicant_note'] = applicantNote.trim();
    }
    Future<void> add(String key, File? file) async {
      if (file != null)
        request.files.add(await http.MultipartFile.fromPath(key, file.path));
    }

    if (subjectType == 'office') {
      await add('registration_document', registrationDocument);
      await add('license_document', licenseDocument);
    } else {
      await add('identity', identity);
      await add('degree', degree);
      await add('syndicate', syndicate);
      await add('experience_proof', experienceProof);
    }
    final response = await http.Response.fromStream(await request.send());
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body['message']?.toString() ?? 'تم إرسال طلب التوثيق.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> submitProfessionalVerificationSubscription({
    required String paymentMethod,
    String? paymentReference,
    required File receipt,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/profile/professional-verification/subscribe'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['payment_method'] = paymentMethod;
    if (paymentReference != null && paymentReference.trim().isNotEmpty) {
      request.fields['payment_reference'] = paymentReference.trim();
    }
    request.files.add(
      await http.MultipartFile.fromPath('receipt', receipt.path),
    );
    final response = await http.Response.fromStream(await request.send());
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body['message']?.toString() ?? 'تم إرسال إيصال اشتراك التوثيق.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchAdminProfessionalVerification({
    String? applicationStatus,
    String? subjectType,
    String? query,
  }) => _phase14Json(
    'GET',
    Uri(
      path: 'admin/professional-verification',
      queryParameters: {
        if (applicationStatus != null && applicationStatus.isNotEmpty)
          'application_status': applicationStatus,
        if (subjectType != null && subjectType.isNotEmpty)
          'subject_type': subjectType,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    ).toString(),
  );

  static Future<String> updateAdminProfessionalVerificationSettings({
    required double engineerMinRating,
    required double engineerMaxRating,
    required int engineerMinReviews,
    required int engineerMinPortfolioWorks,
    required int engineerMinExperienceYears,
    required double engineerMonthlyFee,
    required double officeMonthlyFee,
    required String currency,
    required bool bankTransferEnabled,
    required bool walletEnabled,
    required bool onlineGatewayEnabled,
    String? onlineGatewayName,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'admin/professional-verification/settings',
      body: {
        'engineer_min_rating': engineerMinRating,
        'engineer_max_rating': engineerMaxRating,
        'engineer_min_reviews': engineerMinReviews,
        'engineer_min_portfolio_works': engineerMinPortfolioWorks,
        'engineer_min_experience_years': engineerMinExperienceYears,
        'engineer_monthly_fee': engineerMonthlyFee,
        'office_monthly_fee': officeMonthlyFee,
        'currency': currency,
        'bank_transfer_enabled': bankTransferEnabled ? 1 : 0,
        'wallet_enabled': walletEnabled ? 1 : 0,
        'online_gateway_enabled': onlineGatewayEnabled ? 1 : 0,
        if (onlineGatewayName != null && onlineGatewayName.trim().isNotEmpty)
          'online_gateway_name': onlineGatewayName.trim(),
      },
    );
    return data['message']?.toString() ?? 'تم تحديث إعدادات التوثيق.';
  }

  static Future<String> reviewAdminProfessionalVerificationApplication({
    required int applicationId,
    required String decision,
    String? adminNote,
    String? rejectionReason,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'admin/professional-verification/applications/$applicationId',
      body: {
        'decision': decision,
        if (adminNote != null && adminNote.trim().isNotEmpty)
          'admin_note': adminNote.trim(),
        if (rejectionReason != null && rejectionReason.trim().isNotEmpty)
          'rejection_reason': rejectionReason.trim(),
      },
    );
    return data['message']?.toString() ?? 'تمت مراجعة طلب التوثيق.';
  }

  static Future<String> reviewAdminProfessionalVerificationSubscription({
    required int subscriptionId,
    required String decision,
    String? rejectionReason,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'admin/professional-verification/subscriptions/$subscriptionId',
      body: {
        'decision': decision,
        if (rejectionReason != null && rejectionReason.trim().isNotEmpty)
          'rejection_reason': rejectionReason.trim(),
      },
    );
    return data['message']?.toString() ?? 'تمت مراجعة دفعة التوثيق.';
  }

  static Future<File> downloadAdminProfessionalVerificationApplicationFile({
    required int applicationId,
    required String type,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/admin/professional-verification/applications/$applicationId/file/$type',
      ),
      headers: await _headers(auth: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      Map<String, dynamic> body = const {};
      try {
        body = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map,
        );
      } catch (_) {}
      throw ApiException(_extractErrorMessage(body));
    }
    final dir = await getTemporaryDirectory();
    final extension = _extensionFromContentType(
      response.headers['content-type'],
    );
    final file = File(
      '${dir.path}/verification-$applicationId-$type$extension',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<File> downloadAdminProfessionalVerificationReceipt({
    required int subscriptionId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/admin/professional-verification/subscriptions/$subscriptionId/receipt',
      ),
      headers: await _headers(auth: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      Map<String, dynamic> body = const {};
      try {
        body = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map,
        );
      } catch (_) {}
      throw ApiException(_extractErrorMessage(body));
    }
    final dir = await getTemporaryDirectory();
    final extension = _extensionFromContentType(
      response.headers['content-type'],
    );
    final file = File(
      '${dir.path}/verification-subscription-$subscriptionId$extension',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static String _extensionFromContentType(String? contentType) {
    final type = (contentType ?? '').toLowerCase();
    if (type.contains('pdf')) return '.pdf';
    if (type.contains('png')) return '.png';
    if (type.contains('webp')) return '.webp';
    if (type.contains('jpeg') || type.contains('jpg')) return '.jpg';
    return '';
  }

  // Submittals
  static Future<Map<String, dynamic>> fetchProjectSubmittalsAdvanced(
    int projectId,
  ) => _phase14Json('GET', 'projects/$projectId/submittals');

  static Future<Map<String, dynamic>> fetchProjectSubmittalAdvanced(
    int projectId,
    int submittalId,
  ) => _phase14Json('GET', 'projects/$projectId/submittals/$submittalId');

  static Future<String> createProjectSubmittalAdvanced({
    required int projectId,
    required String title,
    required String description,
    required String type,
    required String priority,
    String? specificationSection,
    int? assignedTo,
    String? dueAt,
    List<File> attachments = const [],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/projects/$projectId/submittals'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields.addAll({
      'title': title,
      'description': description,
      'type': type,
      'priority': priority,
      if (specificationSection != null &&
          specificationSection.trim().isNotEmpty)
        'specification_section': specificationSection.trim(),
      if (assignedTo != null) 'assigned_to': assignedTo.toString(),
      if (dueAt != null && dueAt.isNotEmpty) 'due_at': dueAt,
    });
    for (final file in attachments.take(10)) {
      request.files.add(
        await http.MultipartFile.fromPath('attachments[]', file.path),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode >= 200 && response.statusCode < 300)
      return body['message']?.toString() ?? 'تم إنشاء Submittal.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> reviewProjectSubmittalAdvanced({
    required int projectId,
    required int submittalId,
    required String decision,
    required String comment,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'projects/$projectId/submittals/$submittalId/review',
      body: {'decision': decision, 'review_comment': comment},
    );
    return data['message']?.toString() ?? 'تم حفظ نتيجة المراجعة.';
  }

  static Future<String> addProjectSubmittalRevisionAdvanced({
    required int projectId,
    required int submittalId,
    required String description,
    required List<File> attachments,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '$baseUrl/projects/$projectId/submittals/$submittalId/revisions',
      ),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['description'] = description;
    for (final file in attachments.take(10)) {
      request.files.add(
        await http.MultipartFile.fromPath('attachments[]', file.path),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode >= 200 && response.statusCode < 300)
      return body['message']?.toString() ?? 'تم إرسال Revision.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> projectSubmittalActionAdvanced({
    required int projectId,
    required int submittalId,
    required String action,
    String? reason,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'projects/$projectId/submittals/$submittalId/$action',
      body: {
        if (action == 'close') 'closure_notes': reason,
        if (action == 'cancel') 'reason': reason,
      },
    );
    return data['message']?.toString() ?? 'تم تحديث Submittal.';
  }

  // Meetings
  static Future<Map<String, dynamic>> fetchProjectMeetingsAdvanced(
    int projectId,
  ) => _phase14Json('GET', 'projects/$projectId/meetings');
  static Future<Map<String, dynamic>> fetchProjectMeetingAdvanced(
    int projectId,
    int meetingId,
  ) => _phase14Json('GET', 'projects/$projectId/meetings/$meetingId');

  static Future<String> createProjectMeetingAdvanced({
    required int projectId,
    required String title,
    String type = 'coordination',
    required String scheduledAt,
    String? description,
    String? location,
    String? meetingLink,
    int? chairpersonId,
    List<int> attendees = const <int>[],
    List<Map<String, dynamic>> agendaItems = const <Map<String, dynamic>>[],
    List<File> attachments = const <File>[],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/projects/$projectId/meetings'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields.addAll({
      'title': title.trim(),
      'type': type.trim().isEmpty ? 'coordination' : type.trim(),
      'scheduled_at': scheduledAt.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
      if (meetingLink != null && meetingLink.trim().isNotEmpty)
        'meeting_link': meetingLink.trim(),
      if (chairpersonId != null)
        'chairperson_id': chairpersonId.toString(),
    });

    final uniqueAttendees = attendees.toSet().toList();
    for (var index = 0; index < uniqueAttendees.length; index++) {
      request.fields['attendees[$index]'] = uniqueAttendees[index].toString();
    }

    for (var index = 0; index < agendaItems.length; index++) {
      final item = agendaItems[index];
      final itemTitle = item['title']?.toString().trim() ?? '';
      final itemDescription = item['description']?.toString().trim() ?? '';
      final ownerId = int.tryParse(item['owner_id']?.toString() ?? '');
      final duration = int.tryParse(item['duration']?.toString() ?? '');
      request.fields['agenda_titles[$index]'] = itemTitle;
      request.fields['agenda_descriptions[$index]'] = itemDescription;
      if (ownerId != null) {
        request.fields['agenda_owner_ids[$index]'] = ownerId.toString();
      }
      if (duration != null) {
        request.fields['agenda_durations[$index]'] = duration.toString();
      }
    }

    for (final file in attachments.take(10)) {
      request.files.add(
        await http.MultipartFile.fromPath('attachments[]', file.path),
      );
    }

    final response = await http.Response.fromStream(await request.send());
    final body = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(
            jsonDecode(utf8.decode(response.bodyBytes)) as Map,
          );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body['message']?.toString() ?? 'تم إنشاء الاجتماع وجدولته.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> saveProjectMeetingMinutesAdvanced({
    required int projectId,
    required int meetingId,
    required String summary,
    String? decisions,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'projects/$projectId/meetings/$meetingId/minutes',
      body: {
        'summary': summary,
        if (decisions != null && decisions.trim().isNotEmpty)
          'decisions': decisions.trim(),
      },
    );
    return data['message']?.toString() ?? 'تم حفظ المحضر.';
  }

  static Future<String> publishProjectMeetingMinutesAdvanced(
    int projectId,
    int meetingId,
  ) async {
    final data = await _phase14Json(
      'PATCH',
      'projects/$projectId/meetings/$meetingId/minutes/publish',
    );
    return data['message']?.toString() ?? 'تم نشر المحضر.';
  }

  static Future<String> cancelProjectMeetingAdvanced(
    int projectId,
    int meetingId,
    String reason,
  ) async {
    final data = await _phase14Json(
      'PATCH',
      'projects/$projectId/meetings/$meetingId/cancel',
      body: {'reason': reason},
    );
    return data['message']?.toString() ?? 'تم إلغاء الاجتماع.';
  }

  static Future<String> addMeetingActionAdvanced({
    required int projectId,
    required int meetingId,
    required String title,
    String priority = 'normal',
    int? assignedTo,
    String? dueAt,
  }) async {
    final data = await _phase14Json(
      'POST',
      'projects/$projectId/meetings/$meetingId/actions',
      body: {
        'title': title,
        'priority': priority,
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (dueAt != null && dueAt.isNotEmpty) 'due_at': dueAt,
      },
    );
    return data['message']?.toString() ?? 'تمت إضافة Action Item.';
  }

  static Future<String> updateMeetingActionAdvanced({
    required int projectId,
    required int meetingId,
    required int actionId,
    required String status,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'projects/$projectId/meetings/$meetingId/actions/$actionId',
      body: {'status': status},
    );
    return data['message']?.toString() ?? 'تم تحديث Action Item.';
  }

  // Gantt
  static Future<Map<String, dynamic>> fetchProjectGanttAdvanced(
    int projectId,
  ) => _phase14Json('GET', 'projects/$projectId/gantt-advanced');

  static Future<String> saveProjectGanttItemAdvanced({
    required int projectId,
    int? itemId,
    required String title,
    required String type,
    required String status,
    required String priority,
    required String startDate,
    required String endDate,
    required int progress,
    String? description,
    int? parentId,
    int? assignedTo,
  }) async {
    final data = await _phase14Json(
      itemId == null ? 'POST' : 'PATCH',
      itemId == null
          ? 'projects/$projectId/gantt-advanced'
          : 'projects/$projectId/gantt-advanced/$itemId',
      body: {
        'title': title,
        'type': type,
        'status': status,
        'priority': priority,
        'start_date': startDate,
        'end_date': endDate,
        'progress': progress,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (parentId != null) 'parent_id': parentId,
        if (assignedTo != null) 'assigned_to': assignedTo,
      },
    );
    return data['message']?.toString() ?? 'تم حفظ بند Gantt.';
  }

  static Future<String> updateProjectGanttProgressAdvanced(
    int projectId,
    int itemId,
    int progress,
  ) async {
    final data = await _phase14Json(
      'PATCH',
      'projects/$projectId/gantt-advanced/$itemId/progress',
      body: {'progress': progress},
    );
    return data['message']?.toString() ?? 'تم تحديث الإنجاز.';
  }

  static Future<String> deleteProjectGanttItemAdvanced(
    int projectId,
    int itemId,
  ) async {
    final data = await _phase14Json(
      'DELETE',
      'projects/$projectId/gantt-advanced/$itemId',
    );
    return data['message']?.toString() ?? 'تم حذف البند.';
  }

  static Future<String> createProjectGanttBaselineAdvanced(
    int projectId,
    String name,
  ) async {
    final data = await _phase14Json(
      'POST',
      'projects/$projectId/gantt-advanced/baseline',
      body: {'name': name},
    );
    return data['message']?.toString() ?? 'تم حفظ Baseline.';
  }

  static Future<String> createProjectGanttDependencyAdvanced({
    required int projectId,
    required int predecessorId,
    required int successorId,
    required String dependencyType,
    int lagDays = 0,
  }) async {
    final data = await _phase14Json(
      'POST',
      'projects/$projectId/gantt-advanced/dependencies',
      body: {
        'predecessor_id': predecessorId,
        'successor_id': successorId,
        'dependency_type': dependencyType,
        'lag_days': lagDays,
      },
    );
    return data['message']?.toString() ?? 'تمت إضافة Dependency.';
  }

  static Future<String> deleteProjectGanttDependencyAdvanced(
    int projectId,
    int dependencyId,
  ) async {
    final data = await _phase14Json(
      'DELETE',
      'projects/$projectId/gantt-advanced/dependencies/$dependencyId',
    );
    return data['message']?.toString() ?? 'تم حذف Dependency.';
  }

  // Calendar
  static Future<Map<String, dynamic>> fetchProjectCalendarAdvanced(
    int projectId,
  ) => _phase14Json('GET', 'projects/$projectId/calendar');
  static Future<String> saveProjectCalendarEventAdvanced({
    required int projectId,
    int? eventId,
    required String title,
    required String type,
    required String priority,
    required String startAt,
    String? endAt,
    String? description,
    String? location,
    bool allDay = false,
  }) async {
    final data = await _phase14Json(
      eventId == null ? 'POST' : 'PATCH',
      eventId == null
          ? 'projects/$projectId/calendar'
          : 'projects/$projectId/calendar/$eventId',
      body: {
        'title': title,
        'type': type,
        'priority': priority,
        'start_at': startAt,
        'all_day': allDay,
        if (endAt != null && endAt.isNotEmpty) 'end_at': endAt,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (location != null && location.trim().isNotEmpty)
          'location': location.trim(),
      },
    );
    return data['message']?.toString() ?? 'تم حفظ الموعد.';
  }

  static Future<String> projectCalendarActionAdvanced(
    int projectId,
    int eventId,
    String action, {
    String? reason,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'projects/$projectId/calendar/$eventId/$action',
      body: {if (reason != null) 'reason': reason},
    );
    return data['message']?.toString() ?? 'تم تحديث الموعد.';
  }

  static Future<String> deleteProjectCalendarEventAdvanced(
    int projectId,
    int eventId,
  ) async {
    final data = await _phase14Json(
      'DELETE',
      'projects/$projectId/calendar/$eventId',
    );
    return data['message']?.toString() ?? 'تم حذف الموعد.';
  }

  static Future<File> downloadProjectCalendarIcs(int projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/calendar/export/ics'),
      headers: await _headers(auth: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر تصدير تقويم المشروع.');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/project-$projectId-calendar.ics');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  // BOQ
  static Future<Map<String, dynamic>> fetchProjectBoqsAdvanced(int projectId) =>
      _phase14Json('GET', 'projects/$projectId/boqs-advanced');
  static Future<Map<String, dynamic>> fetchProjectBoqAdvanced(
    int projectId,
    int boqId,
  ) => _phase14Json('GET', 'projects/$projectId/boqs-advanced/$boqId');

  static Future<String> createProjectBoqAdvanced({
    required int projectId,
    required String title,
    String currency = 'USD',
    double contingencyPercent = 0,
    double discountAmount = 0,
    double taxPercent = 0,
    String? notes,
  }) async {
    final data = await _phase14Json(
      'POST',
      'projects/$projectId/boqs-advanced',
      body: {
        'title': title,
        'currency': currency,
        'contingency_percent': contingencyPercent,
        'discount_amount': discountAmount,
        'tax_percent': taxPercent,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return data['message']?.toString() ?? 'تم إنشاء BOQ.';
  }

  static Future<String> projectBoqActionAdvanced(
    int projectId,
    int boqId,
    String action, {
    String? note,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'projects/$projectId/boqs-advanced/$boqId/$action',
      body: {if (note != null) 'note': note},
    );
    return data['message']?.toString() ?? 'تم تحديث BOQ.';
  }

  static Future<String> deleteProjectBoqAdvanced(
    int projectId,
    int boqId,
  ) async {
    final data = await _phase14Json(
      'DELETE',
      'projects/$projectId/boqs-advanced/$boqId',
    );
    return data['message']?.toString() ?? 'تم حذف BOQ.';
  }

  static Future<String> saveProjectBoqSectionAdvanced({
    required int projectId,
    required int boqId,
    int? sectionId,
    required String code,
    required String name,
    String? description,
  }) async {
    final data = await _phase14Json(
      sectionId == null ? 'POST' : 'PATCH',
      sectionId == null
          ? 'projects/$projectId/boqs-advanced/$boqId/sections'
          : 'projects/$projectId/boqs-advanced/$boqId/sections/$sectionId',
      body: {
        'code': code,
        'name': name,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    return data['message']?.toString() ?? 'تم حفظ القسم.';
  }

  static Future<String> deleteProjectBoqSectionAdvanced(
    int projectId,
    int boqId,
    int sectionId,
  ) async {
    final data = await _phase14Json(
      'DELETE',
      'projects/$projectId/boqs-advanced/$boqId/sections/$sectionId',
    );
    return data['message']?.toString() ?? 'تم حذف القسم.';
  }

  static Future<String> saveProjectBoqItemAdvanced({
    required int projectId,
    required int boqId,
    int? itemId,
    required int sectionId,
    required String itemCode,
    required String description,
    required String unit,
    required double quantity,
    required double unitRate,
    int? ganttItemId,
    String? notes,
  }) async {
    final data = await _phase14Json(
      itemId == null ? 'POST' : 'PATCH',
      itemId == null
          ? 'projects/$projectId/boqs-advanced/$boqId/items'
          : 'projects/$projectId/boqs-advanced/$boqId/items/$itemId',
      body: {
        'project_boq_section_id': sectionId,
        'item_code': itemCode,
        'description': description,
        'unit': unit,
        'quantity': quantity,
        'unit_rate': unitRate,
        if (ganttItemId != null) 'gantt_item_id': ganttItemId,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return data['message']?.toString() ?? 'تم حفظ البند.';
  }

  static Future<String> deleteProjectBoqItemAdvanced(
    int projectId,
    int boqId,
    int itemId,
  ) async {
    final data = await _phase14Json(
      'DELETE',
      'projects/$projectId/boqs-advanced/$boqId/items/$itemId',
    );
    return data['message']?.toString() ?? 'تم حذف البند.';
  }

  static Future<String> recordProjectBoqProgressAdvanced({
    required int projectId,
    required int boqId,
    required int itemId,
    required double executedQuantity,
    required double actualCost,
    String? note,
  }) async {
    final data = await _phase14Json(
      'POST',
      'projects/$projectId/boqs-advanced/$boqId/items/$itemId/progress',
      body: {
        'executed_quantity': executedQuantity,
        'actual_cost': actualCost,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return data['message']?.toString() ?? 'تم تسجيل تقدم البند.';
  }

  static Future<File> downloadProjectBoqExportAdvanced({
    required int projectId,
    required int boqId,
    required String format,
  }) async {
    if (!['pdf', 'csv'].contains(format)) {
      throw ApiException('صيغة تصدير BOQ غير مدعومة.');
    }
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/boqs-advanced/$boqId/$format'),
      headers: await _headers(auth: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر تصدير BOQ بصيغة ${format.toUpperCase()}.');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/project-$projectId-boq-$boqId.$format');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<File> downloadProjectBoqImportTemplateAdvanced(
    int projectId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/boqs-advanced/import/template'),
      headers: await _headers(auth: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر تنزيل قالب استيراد BOQ.');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/project-$projectId-boq-import-template.csv');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<String> importProjectBoqCsvAdvanced({
    required int projectId,
    required int boqId,
    required File file,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/projects/$projectId/boqs-advanced/$boqId/import/csv'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await http.Response.fromStream(await request.send());
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode >= 200 && response.statusCode < 300)
      return body['message']?.toString() ?? 'تم استيراد CSV.';
    throw ApiException(_extractErrorMessage(body));
  }

  // ---------------------------------------------------------------------
  // المرحلة 15 — المطابقة النهائية
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchMyFeedback() =>
      _phase14Json('GET', 'feedback/mine');

  static Future<String> submitPlatformFeedback({
    required String type,
    required String title,
    required String message,
    int? rating,
  }) async {
    final data = await _phase14Json(
      'POST',
      'feedback',
      body: {
        'type': type,
        'title': title,
        'message': message,
        if (rating != null) 'rating': rating,
      },
    );
    return data['message']?.toString() ?? 'تم إرسال رأيك أو ملاحظتك.';
  }

  static Future<Map<String, dynamic>> fetchAdminFeedback() =>
      _phase14Json('GET', 'admin/feedback');

  static Future<String> adminFeedbackAction(
    int feedbackId,
    String action,
  ) async {
    final data = await _phase14Json(
      'PATCH',
      'admin/feedback/$feedbackId/$action',
    );
    return data['message']?.toString() ?? 'تم تحديث الرأي.';
  }

  static Future<String> adminFeedbackReply(int feedbackId, String reply) async {
    final data = await _phase14Json(
      'PATCH',
      'admin/feedback/$feedbackId/reply',
      body: {'admin_reply': reply},
    );
    return data['message']?.toString() ?? 'تم حفظ رد الإدارة.';
  }

  static Future<Map<String, dynamic>> fetchAdminModeration() =>
      _phase14Json('GET', 'admin/moderation');

  static Future<String> adminWarningAction(
    int warningId,
    String action, {
    String? notes,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'admin/moderation/warnings/$warningId/$action',
      body: {
        if (notes != null && notes.trim().isNotEmpty)
          'review_notes': notes.trim(),
      },
    );
    return data['message']?.toString() ?? 'تم تحديث التحذير.';
  }

  static Future<String> adminSuspendedUserAction(
    int userId,
    String action,
    String notes,
  ) async {
    final data = await _phase14Json(
      'PATCH',
      'admin/moderation/users/$userId/$action',
      body: {'review_notes': notes},
    );
    return data['message']?.toString() ?? 'تم تحديث حالة الحساب.';
  }

  static Future<String> adminAppealAction(
    int appealId,
    String action, {
    String? response,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'admin/moderation-appeals/$appealId/$action',
      body: {
        if (response != null && response.trim().isNotEmpty)
          'admin_response': response.trim(),
      },
    );
    return data['message']?.toString() ?? 'تم تحديث الطعن.';
  }

  static Future<Map<String, dynamic>> fetchMyModerationAppeal() =>
      _phase14Json('GET', 'moderation/appeal');

  static Future<String> submitModerationAppeal({
    required String message,
    File? attachment,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/moderation/appeal'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['message'] = message;
    if (attachment != null) {
      request.files.add(
        await http.MultipartFile.fromPath('attachment', attachment.path),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    final decoded = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded['message']?.toString() ?? 'تم إرسال الطعن.';
    }
    throw ApiException(_extractErrorMessage(decoded));
  }

  static Future<String> cancelModerationAppeal(int appealId) async {
    final data = await _phase14Json('DELETE', 'moderation/appeal/$appealId');
    return data['message']?.toString() ?? 'تم إلغاء الطعن.';
  }

  static Future<File> downloadModerationAppealAttachment(
    int appealId,
    String fileName,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/moderation/appeal/$appealId/attachment'),
      headers: await _headers(auth: true),
    );
    if (response.statusCode != 200)
      throw ApiException('تعذر تنزيل مرفق الطعن.');
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(
      '${dir.path}/${safe.isEmpty ? 'appeal-attachment' : safe}',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  // ---------------------------------------------------------------------
  // المرحلة 16 — سوق المشاريع
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchMarketplaceProjects({
    String view = 'market',
    String? query,
    String? status,
    int? specialtyId,
    String? audience,
    String? currency,
    double? minBudget,
    double? maxBudget,
    bool openOnly = false,
    String sort = 'newest',
  }) {
    final params = <String, String>{
      'view': view,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (specialtyId != null) 'specialty_id': specialtyId.toString(),
      if (audience != null && audience.trim().isNotEmpty)
        'audience': audience.trim(),
      if (currency != null && currency.trim().isNotEmpty)
        'currency': currency.trim(),
      if (minBudget != null) 'min_budget': minBudget.toString(),
      if (maxBudget != null) 'max_budget': maxBudget.toString(),
      if (openOnly) 'open_only': '1',
      'sort': sort,
    };
    final uri = Uri(
      path: 'marketplace/projects',
      queryParameters: params,
    ).toString();
    return _phase14Json('GET', uri);
  }

  static Future<Map<String, dynamic>> fetchMarketplaceProjectDetail(
    int requestId,
  ) => _phase14Json('GET', 'marketplace/projects/$requestId');

  static Future<String> closeMarketplaceProject(int requestId) async {
    final data = await _phase14Json(
      'PATCH',
      'marketplace/projects/$requestId/close',
    );
    return data['message']?.toString() ?? 'تم إغلاق استقبال العروض.';
  }

  static Future<String> cancelMarketplaceProject(int requestId) async {
    final data = await _phase14Json(
      'PATCH',
      'marketplace/projects/$requestId/cancel',
    );
    return data['message']?.toString() ?? 'تم إلغاء الطلب.';
  }

  static Future<Map<String, dynamic>> createMarketplaceProject({
    required String title,
    required String description,
    String? scope,
    int? specialtyId,
    String? projectType,
    String? location,
    double? expectedBudget,
    required String budgetCurrency,
    int? desiredDurationDays,
    required String quotationDeadline,
    required String audience,
    int? preferredOfficeId,
    List<File> files = const [],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/marketplace/projects'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields.addAll({
      'title': title,
      'description': description,
      if (scope != null && scope.trim().isNotEmpty) 'scope': scope.trim(),
      if (specialtyId != null) 'specialty_id': specialtyId.toString(),
      if (projectType != null && projectType.trim().isNotEmpty)
        'project_type': projectType.trim(),
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
      if (expectedBudget != null) 'expected_budget': expectedBudget.toString(),
      'budget_currency': budgetCurrency,
      if (desiredDurationDays != null)
        'desired_duration_days': desiredDurationDays.toString(),
      'quotation_deadline': quotationDeadline,
      'audience': audience,
      if (preferredOfficeId != null)
        'preferred_office_id': preferredOfficeId.toString(),
    });
    for (final file in files) {
      request.files.add(
        await http.MultipartFile.fromPath('files[]', file.path),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    final decoded = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    throw ApiException(_extractErrorMessage(decoded));
  }

  static Future<String> submitMarketplaceQuotation({
    required int requestId,
    required String providerType,
    int? providerOfficeId,
    int? leadEngineerId,
    required double price,
    required String currency,
    required int durationDays,
    String? availableStartDate,
    required String technicalProposal,
    String? scope,
    String? includedItems,
    String? excludedItems,
    String? notes,
    File? attachment,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/marketplace/projects/$requestId/quotations'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields.addAll({
      'provider_type': providerType,
      if (providerOfficeId != null)
        'provider_office_id': providerOfficeId.toString(),
      if (leadEngineerId != null) 'lead_engineer_id': leadEngineerId.toString(),
      'price': price.toString(),
      'currency': currency,
      'duration_days': durationDays.toString(),
      if (availableStartDate != null && availableStartDate.trim().isNotEmpty)
        'available_start_date': availableStartDate.trim(),
      'technical_proposal': technicalProposal,
      if (scope != null && scope.trim().isNotEmpty) 'scope': scope.trim(),
      if (includedItems != null && includedItems.trim().isNotEmpty)
        'included_items': includedItems.trim(),
      if (excludedItems != null && excludedItems.trim().isNotEmpty)
        'excluded_items': excludedItems.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    if (attachment != null) {
      request.files.add(
        await http.MultipartFile.fromPath('attachment', attachment.path),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    final decoded = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded['message']?.toString() ?? 'تم إرسال عرض السعر.';
    }
    throw ApiException(_extractErrorMessage(decoded));
  }

  static Future<String> updateMarketplaceQuotation({
    required int requestId,
    required int quotationId,
    required double price,
    required String currency,
    required int durationDays,
    int? leadEngineerId,
    String? availableStartDate,
    required String technicalProposal,
    String? scope,
    String? includedItems,
    String? excludedItems,
    String? notes,
    File? attachment,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '$baseUrl/marketplace/projects/$requestId/quotations/$quotationId',
      ),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields.addAll({
      '_method': 'PATCH',
      'price': price.toString(),
      'currency': currency,
      'duration_days': durationDays.toString(),
      if (leadEngineerId != null) 'lead_engineer_id': leadEngineerId.toString(),
      if (availableStartDate != null && availableStartDate.trim().isNotEmpty)
        'available_start_date': availableStartDate.trim(),
      'technical_proposal': technicalProposal,
      if (scope != null && scope.trim().isNotEmpty) 'scope': scope.trim(),
      if (includedItems != null && includedItems.trim().isNotEmpty)
        'included_items': includedItems.trim(),
      if (excludedItems != null && excludedItems.trim().isNotEmpty)
        'excluded_items': excludedItems.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    if (attachment != null) {
      request.files.add(
        await http.MultipartFile.fromPath('attachment', attachment.path),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    final decoded = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded['message']?.toString() ?? 'تم تحديث عرض السعر.';
    }
    throw ApiException(_extractErrorMessage(decoded));
  }

  static Future<String> withdrawMarketplaceQuotation({
    required int requestId,
    required int quotationId,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'marketplace/projects/$requestId/quotations/$quotationId/withdraw',
    );
    return data['message']?.toString() ?? 'تم سحب عرض السعر.';
  }

  static Future<Map<String, dynamic>> acceptMarketplaceQuotation({
    required int requestId,
    required int quotationId,
  }) => _phase14Json(
    'PATCH',
    'marketplace/projects/$requestId/quotations/$quotationId/accept',
  );

  static Future<File> downloadMarketplaceRequestFile({
    required int requestId,
    required int fileId,
    required String fileName,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/marketplace/projects/$requestId/files/$fileId/download',
      ),
      headers: await _headers(auth: true),
    );
    if (response.statusCode != 200) {
      throw ApiException('تعذر تنزيل ملف المشروع.');
    }
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(
      '${dir.path}/${safe.isEmpty ? 'marketplace-file' : safe}',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<File> downloadMarketplaceQuotationAttachment({
    required int requestId,
    required int quotationId,
    required String fileName,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/marketplace/projects/$requestId/quotations/$quotationId/attachment',
      ),
      headers: await _headers(auth: true),
    );
    if (response.statusCode != 200) {
      throw ApiException('تعذر تنزيل مرفق عرض السعر.');
    }
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(
      '${dir.path}/${safe.isEmpty ? 'quotation-attachment' : safe}',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  // ---------------------------------------------------------------------
  // المطابقة الكاملة — المصروفات والموردون وميزانيات المشاريع
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchExpenseDashboard() =>
      _phase14Json('GET', 'finance/expenses/dashboard');

  static Future<Map<String, dynamic>> fetchExpenses({
    String? search,
    String? status,
    String? type,
  }) {
    final uri = Uri(
      path: 'finance/expenses',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (type != null && type.isNotEmpty) 'type': type,
      },
    ).toString();
    return _phase14Json('GET', uri);
  }

  static Future<Map<String, dynamic>> fetchExpenseOptions() =>
      _phase14Json('GET', 'finance/expenses/options');

  static Future<Map<String, dynamic>> fetchExpenseDetail(int expenseId) =>
      _phase14Json('GET', 'finance/expenses/$expenseId');

  static Future<Map<String, dynamic>> saveExpense({
    int? expenseId,
    required Map<String, String> fields,
    List<File> attachments = const [],
  }) async {
    final uri = Uri.parse(
      expenseId == null
          ? '$baseUrl/finance/expenses'
          : '$baseUrl/finance/expenses/$expenseId',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields.addAll(fields);
    for (final file in attachments.take(8)) {
      request.files.add(
        await http.MultipartFile.fromPath('attachments[]', file.path),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    final decoded = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(
            jsonDecode(utf8.decode(response.bodyBytes)) as Map,
          );
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    throw ApiException(_extractErrorMessage(decoded));
  }

  static Future<String> expenseAction(
    int expenseId,
    String action, {
    String? reason,
    String? method,
    String? referenceNumber,
    String? notes,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'finance/expenses/$expenseId/$action',
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        if (method != null && method.isNotEmpty) 'method': method,
        if (referenceNumber != null && referenceNumber.trim().isNotEmpty)
          'reference_number': referenceNumber.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return data['message']?.toString() ?? 'تم تحديث المصروف.';
  }

  static Future<File> downloadExpenseAttachment({
    required int attachmentId,
    required String fileName,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/finance/expense-attachments/$attachmentId/download'),
      headers: await _headers(auth: true),
    );
    if (response.statusCode != 200) {
      throw ApiException('تعذر تنزيل مرفق المصروف.');
    }
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(
      '${dir.path}/${safe.isEmpty ? 'expense-attachment' : safe}',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<Map<String, dynamic>> fetchExpenseCategories() =>
      _phase14Json('GET', 'finance/expense-categories');

  static Future<String> saveExpenseCategory({
    int? categoryId,
    int? officeId,
    required String name,
    String? code,
    bool isActive = true,
  }) async {
    final data = await _phase14Json(
      categoryId == null ? 'POST' : 'PATCH',
      categoryId == null
          ? 'finance/expense-categories'
          : 'finance/expense-categories/$categoryId',
      body: {
        if (categoryId == null && officeId != null) 'office_id': officeId,
        'name': name,
        if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
        if (categoryId != null) 'is_active': isActive,
      },
    );
    return data['message']?.toString() ?? 'تم حفظ التصنيف.';
  }

  static Future<Map<String, dynamic>> fetchVendors() =>
      _phase14Json('GET', 'finance/vendors');

  static Future<String> saveVendor({
    int? vendorId,
    int? officeId,
    required String name,
    String? contactName,
    String? email,
    String? phone,
    String? taxNumber,
    String? address,
    String? bankDetails,
    String? notes,
    bool isActive = true,
  }) async {
    final data = await _phase14Json(
      vendorId == null ? 'POST' : 'PATCH',
      vendorId == null ? 'finance/vendors' : 'finance/vendors/$vendorId',
      body: {
        if (officeId != null) 'office_id': officeId,
        'name': name,
        if (contactName != null && contactName.trim().isNotEmpty)
          'contact_name': contactName.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (taxNumber != null && taxNumber.trim().isNotEmpty)
          'tax_number': taxNumber.trim(),
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
        if (bankDetails != null && bankDetails.trim().isNotEmpty)
          'bank_details': bankDetails.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'is_active': isActive,
      },
    );
    return data['message']?.toString() ?? 'تم حفظ المورد.';
  }

  static Future<Map<String, dynamic>> fetchProjectBudget(int projectId) =>
      _phase14Json('GET', 'finance/projects/$projectId/budget');

  static Future<String> saveProjectBudget({
    required int projectId,
    required String currency,
    required double totalBudget,
    required String status,
    String? notes,
  }) async {
    final data = await _phase14Json(
      'POST',
      'finance/projects/$projectId/budget',
      body: {
        'currency': currency,
        'total_budget': totalBudget,
        'status': status,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return data['message']?.toString() ?? 'تم حفظ ميزانية المشروع.';
  }

  static Future<String> saveProjectBudgetItem({
    required int projectId,
    int? itemId,
    int? categoryId,
    required String name,
    required double plannedAmount,
    String? notes,
  }) async {
    final data = await _phase14Json(
      itemId == null ? 'POST' : 'PATCH',
      itemId == null
          ? 'finance/projects/$projectId/budget/items'
          : 'finance/projects/$projectId/budget/items/$itemId',
      body: {
        if (categoryId != null) 'expense_category_id': categoryId,
        'name': name,
        'planned_amount': plannedAmount,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return data['message']?.toString() ?? 'تم حفظ بند الميزانية.';
  }

  static Future<String> deleteProjectBudgetItem({
    required int projectId,
    required int itemId,
  }) async {
    final data = await _phase14Json(
      'DELETE',
      'finance/projects/$projectId/budget/items/$itemId',
    );
    return data['message']?.toString() ?? 'تم حذف بند الميزانية.';
  }

  // ---------------------------------------------------------------------
  // مالية المكتب — المالك + الإدارة المالية
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchOfficeFinance() =>
      _phase14Json('GET', 'office/finance');

  static Future<String> setOfficeConsultationEngineerPercentage({
    required int consultationId,
    required double percentage,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'office/finance/consultations/$consultationId/engineer-percentage',
      body: {'percentage': percentage},
    );
    return data['message']?.toString() ?? 'تم تحديث نسبة المهندس.';
  }

  static Future<String> markOfficeConsultationEngineerPaid(
    int earningId,
  ) async {
    final data = await _phase14Json(
      'PATCH',
      'office/finance/consultation-engineer-earnings/$earningId/paid',
    );
    return data['message']?.toString() ?? 'تم تسجيل الدفع.';
  }

  static Future<String> markOfficeProjectEngineerPaid(int earningId) async {
    final data = await _phase14Json(
      'PATCH',
      'office/finance/project-engineer-earnings/$earningId/paid',
    );
    return data['message']?.toString() ?? 'تم تسجيل الدفع.';
  }

  static Future<Map<String, dynamic>> fetchAdminOfficeFinance() =>
      _phase14Json('GET', 'admin/office-finance');

  static Future<String> setAdminOfficeConsultationPercentage({
    required int consultationId,
    required double percentage,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'admin/office-finance/consultations/$consultationId/percentage',
      body: {'office_percentage': percentage},
    );
    return data['message']?.toString() ?? 'تم تحديث نسبة المكتب.';
  }

  static Future<String> markAdminConsultationOfficePaid(int financialId) async {
    final data = await _phase14Json(
      'PATCH',
      'admin/office-finance/consultation-financials/$financialId/paid',
    );
    return data['message']?.toString() ?? 'تم تسجيل دفع المكتب.';
  }

  static Future<String> setAdminOfficeProjectPercentage({
    required int projectId,
    required double percentage,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'admin/office-finance/projects/$projectId/percentage',
      body: {'office_percentage': percentage},
    );
    return data['message']?.toString() ?? 'تم تحديث نسبة المكتب.';
  }

  // ---------------------------------------------------------------------
  // استرداد الحساب وطرق 2FA البديلة
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchLoginAlternativeMethods(
    String challengeToken,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/two-factor/methods'),
      headers: await _headers(),
      body: jsonEncode({'challenge_token': challengeToken}),
    );
    final data = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    throw ApiException(_extractErrorMessage(data));
  }

  static Future<Map<String, dynamic>> completeLoginAuthenticator({
    required String challengeToken,
    required String code,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/two-factor/authenticator'),
      headers: await _headers(),
      body: jsonEncode({
        'challenge_token': challengeToken,
        'authenticator_code': code,
      }),
    );
    final data = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _saveToken(data['token'].toString());
      return data;
    }
    throw ApiException(_extractErrorMessage(data));
  }

  static Future<Map<String, dynamic>> completeLoginRecoveryCode({
    required String challengeToken,
    required String recoveryCode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/two-factor/recovery-code'),
      headers: await _headers(),
      body: jsonEncode({
        'challenge_token': challengeToken,
        'recovery_code': recoveryCode,
      }),
    );
    final data = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _saveToken(data['token'].toString());
      return data;
    }
    throw ApiException(_extractErrorMessage(data));
  }

  static Future<Map<String, dynamic>> submitManualAccountRecovery({
    required String accountIdentifier,
    required String identityClaimName,
    required String ticketEmail,
    required String reason,
    required String contactMethod,
    required String contactValue,
    List<File> evidence = const <File>[],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/account-recovery/manual'),
    );
    request.headers.addAll(await _multipartHeaders());
    request.fields.addAll({
      'account_identifier': accountIdentifier.trim(),
      'identity_claim_name': identityClaimName.trim(),
      'ticket_email': ticketEmail.trim(),
      'accept_recovery_policy': '1',
      'reason': reason.trim(),
      'contact_method': contactMethod,
      'contact_value': contactValue.trim(),
    });
    for (final file in evidence.take(5)) {
      request.files.add(
        await http.MultipartFile.fromPath('evidence[]', file.path),
      );
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchManualAccountRecoveryStatus(
    String recoveryToken,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/account-recovery/manual/status'),
      headers: await _headers(),
      body: jsonEncode({'recovery_token': recoveryToken}),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> submitLoginAccountRecovery({
    required String challengeToken,
    required String reason,
    required String contactMethod,
    String? contactValue,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/account-recovery'),
      headers: await _headers(),
      body: jsonEncode({
        'challenge_token': challengeToken,
        'reason': reason,
        'contact_method': contactMethod,
        if (contactValue != null && contactValue.trim().isNotEmpty)
          'contact_value': contactValue.trim(),
      }),
    );
    final data = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    throw ApiException(_extractErrorMessage(data));
  }

  static Future<Map<String, dynamic>> fetchLoginAccountRecoveryStatus(
    String recoveryToken,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/account-recovery/status'),
      headers: await _headers(),
      body: jsonEncode({'recovery_token': recoveryToken}),
    );
    final data = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    throw ApiException(_extractErrorMessage(data));
  }

  static Future<Map<String, dynamic>> continueLoginAccountRecovery(
    String recoveryToken,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/account-recovery/continue'),
      headers: await _headers(),
      body: jsonEncode({'recovery_token': recoveryToken}),
    );
    final data = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _saveToken(data['token'].toString());
      return data;
    }
    throw ApiException(_extractErrorMessage(data));
  }

  static Future<Map<String, dynamic>> fetchSupportAccountRecoveries({
    String? status,
  }) {
    final path = Uri(
      path: 'account-recovery/support',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    ).toString();
    return _phase14Json('GET', path);
  }

  static Future<Map<String, dynamic>> fetchSupportAccountRecovery(int id) =>
      _phase14Json('GET', 'account-recovery/support/$id');

  static Future<String> supportAccountRecoveryAction(
    int id,
    String action, {
    String? verificationMethod,
    String? notes,
    String? currentPassword,
    String? rejectionReason,
  }) async {
    final data = await _phase14Json(
      'POST',
      'account-recovery/support/$id/$action',
      body: {
        if (verificationMethod != null)
          'verification_method': verificationMethod,
        if (notes != null) 'identity_check_notes': notes,
        if (currentPassword != null) 'current_password': currentPassword,
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
      },
    );
    return data['message']?.toString() ?? 'تم تحديث طلب الاسترداد.';
  }

  static Future<Map<String, dynamic>> issueSupportTemporaryPassword({
    required int recoveryId,
    required String currentPassword,
  }) async {
    return _phase14Json(
      'POST',
      'account-recovery/support/$recoveryId/issue-temporary-password',
      body: {'current_password': currentPassword},
    );
  }

  static Future<File> downloadSupportRecoveryEvidence({
    required int recoveryId,
    required int evidenceId,
    required String fileName,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/account-recovery/support/$recoveryId/evidence/$evidenceId',
      ),
      headers: await _headers(auth: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      Map<String, dynamic> body = const <String, dynamic>{};
      try {
        body = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map,
        );
      } catch (_) {}
      throw ApiException(_extractErrorMessage(body));
    }
    final dir = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(
      '${dir.path}/recovery_${recoveryId}_${evidenceId}_$safeName',
    );
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  static Future<String> updateRecoveryAgentPermission({
    required int userId,
    required bool enabled,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'account-recovery/agents/$userId',
      body: {'enabled': enabled},
    );
    return data['message']?.toString() ?? 'تم تحديث الصلاحية.';
  }

  static Future<Map<String, dynamic>> lookupPublicSupportTicket({
    required String email,
    required String ticketNumber,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/support/public/lookup'),
      headers: await _headers(),
      body: jsonEncode({
        'email': email.trim(),
        'ticket_number': ticketNumber.trim(),
      }),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchPublicSupportTicket(
    String accessToken,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/support/public/ticket'),
      headers: await _headers(),
      body: jsonEncode({'access_token': accessToken}),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> replyPublicSupportTicket({
    required String accessToken,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/support/public/reply'),
      headers: await _headers(),
      body: jsonEncode({
        'access_token': accessToken,
        'message': message.trim(),
      }),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> searchSupportCustomers(String query) =>
      _phase14Json(
        'GET',
        Uri(
          path: 'support/customers/search',
          queryParameters: {'q': query},
        ).toString(),
      );

  static Future<Map<String, dynamic>> fetchSupportCustomerProfile(int userId) =>
      _phase14Json('GET', 'support/customers/$userId');

  // ---------------------------------------------------------------------
  // إدارة المستخدمين الكاملة
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchAdminUsers({
    String? search,
    String? role,
    String? status,
  }) {
    final path = Uri(
      path: 'admin/employees',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (role != null && role.isNotEmpty) 'role': role,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    ).toString();
    return _phase14Json('GET', path);
  }

  static Future<Map<String, dynamic>> fetchAdminUser(int userId) =>
      _phase14Json('GET', 'admin/employees/$userId');

  static Future<Map<String, dynamic>> saveAdminUser({
    int? userId,
    required Map<String, dynamic> payload,
  }) => _phase14Json(
    userId == null ? 'POST' : 'PATCH',
    userId == null ? 'admin/employees' : 'admin/employees/$userId',
    body: payload,
  );

  static Future<String> deleteAdminUser(int userId) async {
    final data = await _phase14Json('DELETE', 'admin/employees/$userId');
    return data['message']?.toString() ?? 'تم حذف المستخدم.';
  }

  static Future<String> deleteProjectFile({
    required int projectId,
    required int fileId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/projects/$projectId/files/$fileId'),
      headers: await _headers(auth: true),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      return (body is Map ? body['message'] : null)?.toString() ??
          'تم حذف الملف.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<File> downloadOfficeMembershipApplicationFile({
    required int applicationId,
    required String type,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/office-membership-applications/$applicationId/file/$type',
      ),
      headers: await _headers(auth: true),
    );
    if (response.statusCode != 200) {
      throw ApiException('تعذر تنزيل ملف طلب الانضمام.');
    }

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    final disposition = response.headers['content-disposition'] ?? '';
    String extension = '';
    final fileNameMatch = RegExp(
      r"""filename\*?=(?:UTF-8'')?["']?([^"';]+)""",
      caseSensitive: false,
    ).firstMatch(disposition);
    if (fileNameMatch != null) {
      final name = Uri.decodeComponent(fileNameMatch.group(1)!.trim());
      final dot = name.lastIndexOf('.');
      if (dot >= 0) extension = name.substring(dot);
    }
    if (extension.isEmpty) {
      if (contentType.contains('pdf')) {
        extension = '.pdf';
      } else if (contentType.contains('png')) {
        extension = '.png';
      } else if (contentType.contains('jpeg') || contentType.contains('jpg')) {
        extension = '.jpg';
      } else if (contentType.contains('word')) {
        extension = '.docx';
      }
    }

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/office-membership-$applicationId-$type$extension',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<Map<String, dynamic>> fetchProjectEngineerAllocations(
    int projectId,
  ) async {
    return _phase14Json('GET', 'projects/$projectId/engineer-allocations');
  }

  static Future<String> saveProjectEngineerAllocation({
    required int projectId,
    required int engineerId,
    required double percentage,
  }) async {
    final data = await _phase14Json(
      'POST',
      'projects/$projectId/engineer-allocations',
      body: {'engineer_id': engineerId, 'percentage': percentage},
    );
    return data['message']?.toString() ?? 'تم حفظ نسبة المهندس.';
  }

  static Future<String> deleteProjectEngineerAllocation({
    required int projectId,
    required int allocationId,
  }) async {
    final data = await _phase14Json(
      'DELETE',
      'projects/$projectId/engineer-allocations/$allocationId',
    );
    return data['message']?.toString() ?? 'تم إلغاء نسبة المهندس.';
  }

  // ---------------------------------------------------------------------
  // Phase 4 — BIM Viewer + Clash Detection
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchProjectBim(int projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/bim'),
      headers: await _headers(auth: true),
    );
    final decoded = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> createProjectBimModel({
    required int projectId,
    required String title,
    String? discipline,
    String? description,
    String? notes,
    required File modelFile,
    File? elementsManifest,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/projects/$projectId/bim/models'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['title'] = title.trim();
    if (discipline != null && discipline.trim().isNotEmpty) {
      request.fields['discipline'] = discipline.trim();
    }
    if (description != null && description.trim().isNotEmpty) {
      request.fields['description'] = description.trim();
    }
    if (notes != null && notes.trim().isNotEmpty) {
      request.fields['notes'] = notes.trim();
    }
    request.files.add(
      await http.MultipartFile.fromPath('model_file', modelFile.path),
    );
    if (elementsManifest != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'elements_manifest',
          elementsManifest.path,
        ),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    final decoded = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> uploadProjectBimVersion({
    required int projectId,
    required int modelId,
    required File modelFile,
    File? elementsManifest,
    String? notes,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/projects/$projectId/bim/models/$modelId/versions'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    if (notes != null && notes.trim().isNotEmpty) {
      request.fields['notes'] = notes.trim();
    }
    request.files.add(
      await http.MultipartFile.fromPath('model_file', modelFile.path),
    );
    if (elementsManifest != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'elements_manifest',
          elementsManifest.path,
        ),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    final decoded = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> runProjectBimClash({
    required int projectId,
    required int primaryVersionId,
    int? secondaryVersionId,
    String? title,
    double tolerance = 0.002,
    String engine = 'auto',
    String clashType = 'intersection',
    bool allowTouching = false,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/bim/clash-runs'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'primary_version_id': primaryVersionId,
        if (secondaryVersionId != null)
          'secondary_version_id': secondaryVersionId,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        'tolerance': tolerance,
        'engine': engine,
        'clash_type': clashType,
        'allow_touching': allowTouching,
      }),
    );
    final decoded = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> importProjectBimClashReport({
    required int projectId,
    required int primaryVersionId,
    int? secondaryVersionId,
    String? title,
    required File report,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/projects/$projectId/bim/clash-runs/import'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['primary_version_id'] = primaryVersionId.toString();
    if (secondaryVersionId != null) {
      request.fields['secondary_version_id'] = secondaryVersionId.toString();
    }
    if (title != null && title.trim().isNotEmpty)
      request.fields['title'] = title.trim();
    request.files.add(await http.MultipartFile.fromPath('report', report.path));
    final response = await http.Response.fromStream(await request.send());
    final decoded = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchProjectBimClashRun({
    required int projectId,
    required int runId,
    String? status,
    String? severity,
  }) async {
    final uri = Uri.parse('$baseUrl/projects/$projectId/bim/clash-runs/$runId')
        .replace(
          queryParameters: {
            if (status != null && status.isNotEmpty) 'status': status,
            if (severity != null && severity.isNotEmpty) 'severity': severity,
          },
        );
    final response = await http.get(uri, headers: await _headers(auth: true));
    final decoded = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> updateProjectBimClash({
    required int projectId,
    required int runId,
    required int clashId,
    required String status,
    String? severity,
    int? assignedTo,
    bool clearAssignee = false,
    String? resolution,
  }) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/projects/$projectId/bim/clash-runs/$runId/clashes/$clashId',
      ),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'status': status,
        if (severity != null) 'severity': severity,
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (clearAssignee) 'assigned_to': null,
        if (resolution != null) 'resolution': resolution,
      }),
    );
    final decoded = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchProjectBimViewerLink({
    required int projectId,
    required int versionId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/projects/$projectId/bim/versions/$versionId/viewer-link',
      ),
      headers: await _headers(auth: true),
    );
    final decoded = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<File> downloadProjectBimVersion({
    required int projectId,
    required int versionId,
    required String fileName,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/projects/$projectId/bim/versions/$versionId/download',
      ),
      headers: await _headers(auth: true),
    );
    if (response.statusCode != 200) throw ApiException('تعذر تنزيل نموذج BIM.');
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._\-]'), '_');
    final file = File('${dir.path}/${safe.isEmpty ? 'bim-model' : safe}');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  // ---------------------------------------------------------------------
  // إدارة الموقع / Site & Field Management (offline-first mobile)
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchProjectFieldRecords(
    int projectId, {
    String? type,
    String? status,
    String? updatedAfter,
    int limit = 200,
  }) async {
    final uri = Uri.parse('$baseUrl/projects/$projectId/field').replace(
      queryParameters: {
        if (type != null && type.isNotEmpty) 'type': type,
        if (status != null && status.isNotEmpty) 'status': status,
        if (updatedAfter != null && updatedAfter.isNotEmpty)
          'updated_after': updatedAfter,
        'limit': limit.clamp(1, 200).toString(),
      },
    );
    final response = await http.get(uri, headers: await _headers(auth: true));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> syncProjectFieldOperations({
    required int projectId,
    required List<Map<String, dynamic>> operations,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/field/sync'),
      headers: await _headers(auth: true),
      body: jsonEncode({'operations': operations}),
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> uploadProjectFieldAttachment({
    required int projectId,
    required int fieldRecordId,
    required File attachment,
    String? clientUuid,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '$baseUrl/projects/$projectId/field/$fieldRecordId/attachments',
      ),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    if (clientUuid != null && clientUuid.trim().isNotEmpty) {
      request.fields['client_uuid'] = clientUuid.trim();
    }
    request.files.add(
      await http.MultipartFile.fromPath('attachment', attachment.path),
    );
    final response = await http.Response.fromStream(await request.send());
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<File> downloadProjectFieldAttachment({
    required int projectId,
    required int fieldRecordId,
    required int attachmentId,
    String? fileName,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/projects/$projectId/field/$fieldRecordId/attachments/$attachmentId',
      ),
      headers: await _headers(auth: true),
    );
    if (response.statusCode != 200) {
      throw ApiException('تعذر تنزيل مرفق إدارة الموقع.');
    }
    final dir = await getTemporaryDirectory();
    final safeName = (fileName == null || fileName.trim().isEmpty)
        ? 'field-$fieldRecordId-attachment-$attachmentId'
        : fileName.replaceAll(RegExp(r'[^A-Za-z0-9._\-]'), '_');
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  // ---------------------------------------------------------------------
  // Enterprise Multi-Tenancy / API Tokens / Webhooks
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchEnterpriseSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/enterprise'),
      headers: await _headers(auth: true),
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> createEnterpriseApiToken({
    required String name,
    required List<String> abilities,
    String? expiresAt,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/enterprise/api-tokens'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'name': name,
        'abilities': abilities,
        if (expiresAt != null) 'expires_at': expiresAt,
      }),
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> revokeEnterpriseApiToken(int tokenId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/enterprise/api-tokens/$tokenId'),
      headers: await _headers(auth: true),
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم الإلغاء.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> createEnterpriseWebhook({
    required String name,
    required String url,
    required List<String> events,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/enterprise/webhooks'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'name': name,
        'url': url,
        'events': events,
        'is_active': true,
      }),
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> deleteEnterpriseWebhook(int webhookId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/enterprise/webhooks/$webhookId'),
      headers: await _headers(auth: true),
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم الحذف.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> testEnterpriseWebhook(int webhookId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/enterprise/webhooks/$webhookId/test'),
      headers: await _headers(auth: true),
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم إرسال الاختبار.';
    throw ApiException(_extractErrorMessage(body));
  }

  static String _extractErrorMessage(Map<String, dynamic> body) {
    // نعرض أخطاء Laravel validation نفسها بدل الرسالة العامة فقط.
    // ندعم Map/List/String حتى لا يحدث TypeError أثناء محاولة عرض الخطأ.
    final validationMessages = <String>[];

    void addMessage(dynamic value) {
      if (value == null) return;
      if (value is Map) {
        for (final item in value.values) {
          addMessage(item);
        }
        return;
      }
      if (value is Iterable && value is! String) {
        for (final item in value) {
          addMessage(item);
        }
        return;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty && !validationMessages.contains(text)) {
        validationMessages.add(text);
      }
    }

    addMessage(body['errors']);
    addMessage(body['error_list']);
    if (validationMessages.isNotEmpty) {
      return validationMessages.take(3).join('\n');
    }

    for (final key in const ['message', 'error', 'detail']) {
      final raw = body[key];
      if (raw == null) continue;
      final text = raw.toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }

    return 'تعذر تنفيذ العملية. تحقق من اتصالك وحاول مرة أخرى.';
  }

  static Future<Map<String, dynamic>> fetchAdminPlatformPaymentMethods() async {
    final uri = Uri.parse('$baseUrl/admin/platform-payment-methods').replace(
      queryParameters: {
        '_ts': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    final r = await http.get(uri, headers: await _headers(auth: true));
    final b = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(r.bodyBytes)) as Map,
    );
    if (r.statusCode == 200) return b;
    throw ApiException(_extractErrorMessage(b));
  }

  static Future<Map<String, dynamic>> saveAdminPlatformPaymentMethod(
    Map<String, dynamic> data, {
    int? id,
  }) async {
    final uri = Uri.parse(
      id == null
          ? '$baseUrl/admin/platform-payment-methods'
          : '$baseUrl/admin/platform-payment-methods/$id',
    );
    final r = id == null
        ? await http.post(
            uri,
            headers: await _headers(auth: true),
            body: jsonEncode(data),
          )
        : await http.put(
            uri,
            headers: await _headers(auth: true),
            body: jsonEncode(data),
          );
    final b = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(r.bodyBytes)) as Map,
    );
    if (r.statusCode >= 200 && r.statusCode < 300) return b;
    throw ApiException(_extractErrorMessage(b));
  }

  static Future<Map<String, dynamic>> fetchPayoutQueue() async {
    final r = await http.get(
      Uri.parse('$baseUrl/admin/payout-queue'),
      headers: await _headers(auth: true),
    );
    final b = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(r.bodyBytes)) as Map,
    );
    if (r.statusCode == 200) return b;
    throw ApiException(_extractErrorMessage(b));
  }

  static Future<String> startPayout(String kind, int id) async {
    final r = await http.post(
      Uri.parse(
        '$baseUrl/admin/payout-queue/${kind == 'engineer' ? 'engineers' : 'offices'}/$id',
      ),
      headers: await _headers(auth: true),
    );
    final b = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(r.bodyBytes)) as Map,
    );
    if (r.statusCode >= 200 && r.statusCode < 300)
      return b['message']?.toString() ?? 'تم بدء الصرف.';
    throw ApiException(_extractErrorMessage(b));
  }

  static Future<Map<String, dynamic>> fetchConversationReviews() async {
    final r = await http.get(
      Uri.parse('$baseUrl/admin/conversation-reviews'),
      headers: await _headers(auth: true),
    );
    final b = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(r.bodyBytes)) as Map,
    );
    if (r.statusCode == 200) return b;
    throw ApiException(_extractErrorMessage(b));
  }

  static Future<Map<String, dynamic>> reviewConversation(
    String kind,
    int id,
    String reason,
  ) async {
    final uri = Uri.parse(
      '$baseUrl/admin/conversation-reviews/$kind/$id',
    ).replace(queryParameters: {'reason': reason});
    final r = await http.get(uri, headers: await _headers(auth: true));
    final b = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(r.bodyBytes)) as Map,
    );
    if (r.statusCode == 200) return b;
    throw ApiException(_extractErrorMessage(b));
  }

  // SaaS Phase 5 — disputes / refunds / financial control
  static Future<Map<String, dynamic>> fetchDisputes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/disputes'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> createDispute(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/disputes'),
      headers: await _headers(auth: true),
      body: jsonEncode(data),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchDispute(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/disputes/$id'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> addDisputeMessage(
    int id,
    String bodyText, {
    bool internal = false,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/disputes/$id/messages'),
      headers: await _headers(auth: true),
      body: jsonEncode({'body': bodyText, 'is_internal': internal}),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body['message']?.toString() ?? 'تمت إضافة الرسالة.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> reviewDispute(
    int id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/disputes/$id/review'),
      headers: await _headers(auth: true),
      body: jsonEncode(data),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchFinancialControl() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/financial-control'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchRefunds() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/refunds'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> markRefundProcessing(int id) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/refunds/$id/processing'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body['message']?.toString() ?? 'تم وضع الاسترداد قيد التنفيذ.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> completeRefund(int id, String providerReference) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/refunds/$id/complete'),
      headers: await _headers(auth: true),
      body: jsonEncode({'provider_reference': providerReference}),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body['message']?.toString() ?? 'تم تأكيد الاسترداد.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> rejectRefund(int id, String reason) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/refunds/$id/reject'),
      headers: await _headers(auth: true),
      body: jsonEncode({'reason': reason}),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body['message']?.toString() ?? 'تم رفض الاسترداد.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  // SaaS Phase 6 — SLA automation / deadline escalation center
  static Future<Map<String, dynamic>> fetchSlaCenter({
    String status = 'active',
    String? category,
    String? priority,
  }) async {
    final query = <String, String>{'status': status};
    if (category != null && category.trim().isNotEmpty)
      query['category'] = category.trim();
    if (priority != null && priority.trim().isNotEmpty)
      query['priority'] = priority.trim();
    final uri = Uri.parse(
      '$baseUrl/sla-center',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: await _headers(auth: true));
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> acknowledgeSlaItem(int id) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/sla-center/items/$id/acknowledge'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body['message']?.toString() ?? 'تم تسجيل الاطلاع على الإجراء.';
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> updateSlaRule(
    int id, {
    required int warningMinutes,
    int? dueMinutes,
    required int escalationMinutes,
    required bool notifyOwner,
    required bool notifyAdmin,
    required bool isActive,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/sla-rules/$id'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'warning_minutes': warningMinutes,
        'due_minutes': dueMinutes,
        'escalation_minutes': escalationMinutes,
        'notify_owner': notifyOwner,
        'notify_admin': notifyAdmin,
        'is_active': isActive,
      }),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  // ---------------------------------------------------------------------
  // SaaS Phase 7 — Project Handover & Acceptance
  // ---------------------------------------------------------------------
  static Future<Map<String, dynamic>> fetchProjectHandover(int projectId) =>
      _phase14Json('GET', 'projects/$projectId/handover');

  static Future<Map<String, dynamic>> createProjectHandover({
    required int projectId,
    required String packageType,
    int? milestoneId,
    required String title,
    String? summary,
    required List<String> items,
  }) => _phase14Json(
    'POST',
    'projects/$projectId/handover',
    body: {
      'package_type': packageType,
      if (milestoneId != null) 'project_milestone_id': milestoneId,
      'title': title.trim(),
      if (summary != null && summary.trim().isNotEmpty)
        'summary': summary.trim(),
      'items': items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
    },
  );

  static Future<Map<String, dynamic>> updateProjectHandoverItem({
    required int projectId,
    required int handoverId,
    required int itemId,
    required String status,
    String? notes,
  }) => _phase14Json(
    'PATCH',
    'projects/$projectId/handover/$handoverId/items/$itemId',
    body: {
      'status': status,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    },
  );

  static Future<Map<String, dynamic>> uploadProjectHandoverAttachment({
    required int projectId,
    required int handoverId,
    required File file,
    String? label,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '$baseUrl/projects/$projectId/handover/$handoverId/attachments',
      ),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    if (label != null && label.trim().isNotEmpty)
      request.fields['label'] = label.trim();
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await http.Response.fromStream(await request.send());
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> deleteProjectHandoverAttachment({
    required int projectId,
    required int handoverId,
    required int attachmentId,
  }) => _phase14Json(
    'DELETE',
    'projects/$projectId/handover/$handoverId/attachments/$attachmentId',
  );

  static Future<Map<String, dynamic>> cancelProjectHandover({
    required int projectId,
    required int handoverId,
  }) =>
      _phase14Json('PATCH', 'projects/$projectId/handover/$handoverId/cancel');

  static Future<Map<String, dynamic>> submitProjectHandover({
    required int projectId,
    required int handoverId,
  }) => _phase14Json('POST', 'projects/$projectId/handover/$handoverId/submit');

  static Future<Map<String, dynamic>> acceptProjectHandover({
    required int projectId,
    required int handoverId,
  }) =>
      _phase14Json('PATCH', 'projects/$projectId/handover/$handoverId/accept');

  static Future<Map<String, dynamic>> requestProjectHandoverChanges({
    required int projectId,
    required int handoverId,
    required String notes,
  }) => _phase14Json(
    'PATCH',
    'projects/$projectId/handover/$handoverId/request-changes',
    body: {'review_notes': notes.trim()},
  );

  static Future<File> downloadProjectHandoverAttachment({
    required int projectId,
    required int handoverId,
    required int attachmentId,
    required String fileName,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/projects/$projectId/handover/$handoverId/attachments/$attachmentId',
      ),
      headers: await _headers(auth: true),
    );
    if (response.statusCode != 200)
      throw ApiException('تعذر تنزيل ملف التسليم.');
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}/${safe.isEmpty ? 'handover-file' : safe}');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<File> downloadProjectHandoverCertificate({
    required int projectId,
    required int handoverId,
    required String certificateNumber,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/projects/$projectId/handover/$handoverId/certificate',
      ),
      headers: await _headers(auth: true),
    );
    if (response.statusCode != 200)
      throw ApiException('تعذر تنزيل شهادة الاستلام.');
    final dir = await getTemporaryDirectory();
    final safe = certificateNumber.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(
      '${dir.path}/${safe.isEmpty ? 'acceptance-certificate' : safe}.pdf',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  /// حالة التحقق من الهوية من API الخاص بـ Didit؛ لا ترجع بيانات حساسة.
  static Future<Map<String, dynamic>> fetchIdentityVerificationStatus() async {
    final response = await http.get(
      Uri.parse('$baseUrl/identity-verification'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  /// يطلب جلسة جديدة من الخادم ولا ينشئها داخل التطبيق.
  static Future<Map<String, dynamic>> startIdentityVerification() async {
    final response = await http.post(
      Uri.parse('$baseUrl/identity-verification/start'),
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body['verification_url'] is! String ||
          (body['verification_url'] as String).trim().isEmpty) {
        throw ApiException('الخادم لم يُرجع رابط توثيق هوية صالحًا.');
      }
      return body;
    }
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  // ---------------------------------------------------------------------
  // KYC / توثيق الهوية
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchKyc() async {
    final response = await http.get(
      Uri.parse('$baseUrl/kyc'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> submitUserKyc({
    required String legalName,
    required String identityNumber,
    String? dateOfBirth,
    String? nationality,
    String? countryCode,
    required Map<String, File> documents,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/kyc/user'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['legal_name'] = legalName.trim();
    request.fields['identity_number'] = identityNumber.trim();
    if ((dateOfBirth ?? '').trim().isNotEmpty)
      request.fields['date_of_birth'] = dateOfBirth!.trim();
    if ((nationality ?? '').trim().isNotEmpty)
      request.fields['nationality'] = nationality!.trim();
    if ((countryCode ?? '').trim().isNotEmpty)
      request.fields['country_code'] = countryCode!.trim().toUpperCase();
    for (final entry in documents.entries) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'documents[${entry.key}]',
          entry.value.path,
        ),
      );
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> submitOfficeKyc({
    required int officeId,
    required String legalName,
    required String identityNumber,
    String? countryCode,
    required Map<String, File> documents,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/kyc/offices/$officeId'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['legal_name'] = legalName.trim();
    request.fields['identity_number'] = identityNumber.trim();
    if ((countryCode ?? '').trim().isNotEmpty)
      request.fields['country_code'] = countryCode!.trim().toUpperCase();
    for (final entry in documents.entries) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'documents[${entry.key}]',
          entry.value.path,
        ),
      );
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> prepareKycFaceVerification({
    required String legalName,
    required String identityNumber,
    required File identityFront,
    File? identityBack,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/kyc/face-verification/prepare'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['legal_name'] = legalName.trim();
    request.fields['identity_number'] = identityNumber.trim();
    request.files.add(
      await http.MultipartFile.fromPath('identity_front', identityFront.path),
    );
    if (identityBack != null)
      request.files.add(
        await http.MultipartFile.fromPath('identity_back', identityBack.path),
      );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> startKycFaceVerification() =>
      _phase14Json('POST', 'kyc/face-verification/start');

  static Future<Map<String, dynamic>> fetchKycFaceVerificationStatus() =>
      _phase14Json('GET', 'kyc/face-verification/status');

  static Future<Map<String, dynamic>> checkKycLocalFaceStep({
    required File frame,
    required String challenge,
    File? baseline,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/kyc/face-verification/local-check-step'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.fields['challenge'] = challenge;
    request.files.add(await http.MultipartFile.fromPath('frame', frame.path));
    if (baseline != null) {
      request.files.add(
        await http.MultipartFile.fromPath('baseline', baseline.path),
      );
    }
    http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(const Duration(seconds: 75));
    } on SocketException {
      throw ApiException(
        'تعذر الوصول إلى خدمة فحص الوجه. تحقق من الاتصال ثم حاول مجددًا.',
      );
    } on TimeoutException {
      throw ApiException(
        'استغرق فحص الوجه وقتًا أطول من المتوقع. انتظر ثوانٍ ثم حاول من نفس المرحلة.',
      );
    }
    final response = await http.Response.fromStream(streamed);
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    if (response.statusCode == 429) {
      final retryAfter = response.headers['retry-after'];
      throw ApiException(
        retryAfter == null
            ? 'خدمة فحص الوجه مشغولة مؤقتًا. انتظر ثوانٍ قليلة ثم أكمل من نفس المرحلة.'
            : 'خدمة فحص الوجه مشغولة مؤقتًا. أكمل بعد $retryAfter ثانية.',
        statusCode: 429,
        data: body,
      );
    }
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> submitKycLocalFaceVerification({
    required File front,
    required File blink,
    required File left,
    required File right,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/kyc/face-verification/local-submit'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));
    request.files.add(await http.MultipartFile.fromPath('front', front.path));
    request.files.add(await http.MultipartFile.fromPath('blink', blink.path));
    request.files.add(await http.MultipartFile.fromPath('left', left.path));
    request.files.add(await http.MultipartFile.fromPath('right', right.path));
    http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(const Duration(seconds: 150));
    } on SocketException {
      throw ApiException(
        'تعذر الوصول إلى خادم التحقق النهائي. تحقق من الاتصال ثم حاول مجددًا.',
      );
    } on TimeoutException {
      throw ApiException(
        'تحليل الذكاء الاصطناعي استغرق وقتًا أطول من المتوقع. انتظر قليلًا ثم أعد الإرسال النهائي.',
      );
    }
    final response = await http.Response.fromStream(streamed);
    final body = _safeResponseMap(response);
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    if (response.statusCode == 429) {
      final retryAfter = response.headers['retry-after'];
      throw ApiException(
        retryAfter == null
            ? 'تم إيقاف الإرسال النهائي مؤقتًا لحماية الحساب. انتظر لحظات واضغط التحقق مرة واحدة فقط.'
            : 'انتظر $retryAfter ثانية ثم أعد الإرسال النهائي مرة واحدة.',
        statusCode: 429,
        data: body,
      );
    }
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }

  static Future<Map<String, dynamic>> startSupportRecoveryFaceVerification(
    int recoveryId,
  ) => _phase14Json(
    'POST',
    'account-recovery/support/$recoveryId/face-verification/start',
  );

  static Future<Map<String, dynamic>>
  fetchSupportRecoveryFaceVerificationStatus(int recoveryId) => _phase14Json(
    'GET',
    'account-recovery/support/$recoveryId/face-verification/status',
  );

  static Future<List<Map<String, dynamic>>> fetchAdminKyc({
    String? status,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/kyc').replace(
      queryParameters: {if ((status ?? '').isNotEmpty) 'status': status!},
    );
    final response = await http.get(uri, headers: await _headers(auth: true));
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(
        (body['data'] as List? ?? const []).whereType<Map>().map(
          (e) => Map<String, dynamic>.from(e),
        ),
      );
    }
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchAdminKycProfile(
    int profileId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/kyc/$profileId'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> reviewAdminKycDocument({
    required int documentId,
    required String status,
    String? rejectionReason,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/kyc/documents/$documentId/review'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'status': status,
        if ((rejectionReason ?? '').trim().isNotEmpty)
          'rejection_reason': rejectionReason!.trim(),
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تحديث المستند.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<String> reviewAdminKyc({
    required int profileId,
    required String status,
    String? note,
    String? emailSubject,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/kyc/$profileId/review'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'status': status,
        if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
        if ((emailSubject ?? '').trim().isNotEmpty)
          'email_subject': emailSubject!.trim(),
      }),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200)
      return body['message']?.toString() ?? 'تم تحديث KYC.';
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchPackagesCenter() async {
    final response = await http.get(
      Uri.parse('$baseUrl/packages-center'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchActiveOffers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/offers/active'),
      headers: await _headers(auth: true),
    );
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchFaq({String? q}) async {
    final uri = Uri.parse(
      '$baseUrl/faq',
    ).replace(queryParameters: {if ((q ?? '').isNotEmpty) 'q': q!});
    final response = await http.get(uri, headers: await _headers(auth: false));
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    if (response.statusCode == 200) return body;
    throw ApiException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> fetchAdminPackagesCenter() async =>
      _phase14Json('GET', 'admin/packages-center');
  static Future<Map<String, dynamic>> updateAdminPackage(
    String type,
    int id,
    Map<String, dynamic> data,
  ) async =>
      _phase14Json('PATCH', 'admin/packages-center/$type/$id', body: data);
  static Future<String> sendSupportCustomEmail(
    int userId, {
    required String subject,
    required String message,
    String? actionUrl,
    String? actionLabel,
  }) async {
    final d = await _phase14Json(
      'POST',
      'support/customers/$userId/email',
      body: {
        'subject': subject,
        'message': message,
        if ((actionUrl ?? '').isNotEmpty) 'action_url': actionUrl,
        if ((actionLabel ?? '').isNotEmpty) 'action_label': actionLabel,
      },
    );
    return d['message']?.toString() ?? 'تم الإرسال';
  }

  static Future<Map<String, dynamic>> fetchAdminFaq() async =>
      _phase14Json('GET', 'admin/faq');
  static Future<Map<String, dynamic>> saveAdminFaq({
    int? id,
    required String question,
    required String answer,
    required String category,
    String? keywords,
    int sortOrder = 100,
    required bool isPublic,
    required bool aiEnabled,
    required bool isActive,
  }) async => _phase14Json(
    id == null ? 'POST' : 'PATCH',
    id == null ? 'admin/faq' : 'admin/faq/$id',
    body: {
      'question': question,
      'answer': answer,
      'category': category,
      'keywords': (keywords ?? '').trim(),
      'is_public': isPublic,
      'ai_enabled': aiEnabled,
      'is_active': isActive,
      'sort_order': sortOrder,
    },
  );

  static Future<Map<String, dynamic>> fetchSupportKnowledge({
    String? q,
  }) async {
    final query = (q ?? '').trim();
    final uri = Uri.parse('$baseUrl/support-workspace/knowledge').replace(
      queryParameters: query.isEmpty ? null : {'q': query},
    );
    final response = await http.get(
      uri,
      headers: await _headers(auth: true),
    );
    final body = _safeResponseMap(response);
    if (response.statusCode == 200) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }
  static Future<Map<String, dynamic>> deleteAdminFaq(int id) async =>
      _phase14Json('DELETE', 'admin/faq/$id');
  static Future<String> sendSupportKycRecovery(int userId) async {
    final d = await _phase14Json(
      'POST',
      'support/customers/$userId/kyc-recovery',
    );
    return d['message']?.toString() ?? 'تم الإرسال';
  }

  static Future<String> reopenSupportTicket(
    int ticketId, {
    required String reason,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'support-ticket-actions/$ticketId/reopen',
      body: {'reason': reason.trim()},
    );
    return data['message']?.toString() ?? 'تمت إعادة فتح التذكرة.';
  }

  static Future<String> changeSupportTicketPriority(
    int ticketId, {
    required String priority,
    required String reason,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'support-ticket-actions/$ticketId/priority',
      body: {'priority': priority, 'reason': reason.trim()},
    );
    return data['message']?.toString() ?? 'تم تحديث الأولوية.';
  }

  static Future<String> assignSupportTicket(
    int ticketId, {
    int? employeeId,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'support-ticket-actions/$ticketId/assign',
      body: {if (employeeId != null) 'employee_id': employeeId},
    );
    return data['message']?.toString() ?? 'تم تعيين التذكرة.';
  }

  static Future<String> escalateSupportTicketTarget(
    int ticketId, {
    required String target,
    required String reason,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'support-ticket-actions/$ticketId/escalate-target',
      body: {'target': target, 'reason': reason.trim()},
    );
    return data['message']?.toString() ?? 'تم تصعيد التذكرة.';
  }

  // ---------------------------------------------------------------------
  // V24 — Support Enterprise Operations
  // ---------------------------------------------------------------------
  static Future<Map<String, dynamic>> fetchSupportOperationsDashboard() =>
      _phase14Json('GET', 'support-operations/dashboard');

  static Future<Map<String, dynamic>> fetchSupportOperationsCustomer(
    int userId,
  ) => _phase14Json('GET', 'support-operations/customers/$userId');

  static Future<String> supportAccountAction(
    int userId, {
    required String action,
    String? reason,
    Map<String, bool>? checklist,
  }) async {
    final response = await _phase14Json(
      'POST',
      'support-operations/customers/$userId/action',
      body: {
        'action': action,
        if (reason != null) 'reason': reason,
        if (checklist != null) 'checklist': checklist,
      },
    );
    return '${response['message'] ?? 'تم تنفيذ الإجراء.'}';
  }

  static Future<String> requestSupportSensitiveAction(
    int userId, {
    required String actionType,
    required String reason,
    int? recoveryId,
    required Map<String, bool> checklist,
  }) async {
    final response = await _phase14Json(
      'POST',
      'support-operations/customers/$userId/sensitive',
      body: {
        'action_type': actionType,
        'reason': reason,
        if (recoveryId != null) 'recovery_id': recoveryId,
        'checklist': checklist,
      },
    );
    return '${response['message'] ?? 'تم إرسال الطلب للمشرف.'}';
  }

  static Future<Map<String, dynamic>> fetchSupportApprovals() =>
      _phase14Json('GET', 'support-operations/approvals');

  static Future<String> reviewSupportApproval(
    int approvalId, {
    required String decision,
    required String notes,
  }) async {
    final data = await _phase14Json(
      'PATCH',
      'support-operations/approvals/$approvalId',
      body: {'decision': decision, 'notes': notes.trim()},
    );
    return data['message']?.toString() ?? 'تمت المراجعة.';
  }

  static Future<Map<String, dynamic>> fetchSupportTemplates() =>
      _phase14Json('GET', 'support-operations/templates');

  static Future<String> requestSupportRefund(
    int userId, {
    required int paymentId,
    required double amount,
    required String reason,
  }) async {
    final data = await _phase14Json(
      'POST',
      'support-operations/customers/$userId/refund',
      body: {
        'payment_id': paymentId,
        'amount': amount,
        'reason': reason.trim(),
      },
    );
    return data['message']?.toString() ?? 'تم رفع طلب الاسترداد.';
  }

  static Future<String> recommendSupportModeration(
    int userId, {
    required String type,
    required String reason,
  }) async {
    final data = await _phase14Json(
      'POST',
      'support-operations/customers/$userId/moderation',
      body: {'recommendation_type': type, 'reason': reason.trim()},
    );
    return data['message']?.toString() ?? 'تم رفع التوصية.';
  }

  // ---------------------------------------------------------------------
  // V25 — Support Trust / Package detail / Incidents
  // ---------------------------------------------------------------------
  static Future<Map<String, dynamic>> fetchAdminPackageDetail(
    String type,
    int id,
  ) => _phase14Json('GET', 'admin/packages-center/$type/$id');
  static Future<Map<String, dynamic>> createAdminPackageCoupon(
    String type,
    int id,
    Map<String, dynamic> data, {
    File? image,
  }) async {
    if (image == null) {
      return _phase14Json(
        'POST',
        'admin/packages-center/$type/$id/coupons',
        body: data,
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/admin/packages-center/$type/$id/coupons'),
    );
    request.headers.addAll(await _multipartHeaders(auth: true));

    data.forEach((key, value) {
      if (value == null) return;
      if (value is bool) {
        request.fields[key] = value ? '1' : '0';
      } else {
        request.fields[key] = value.toString();
      }
    });
    request.files.add(await http.MultipartFile.fromPath('image', image.path));

    final response = await http.Response.fromStream(await request.send());
    final body = _safeResponseMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
      data: body,
    );
  }
  static Future<Map<String, dynamic>> fetchSupportTrustDashboard() =>
      _phase14Json('GET', 'support-trust/dashboard');
  static Future<Map<String, dynamic>> revealSupportSensitive(
    int userId, {
    required String field,
    required String reason,
  }) => _phase14Json(
    'POST',
    'support-trust/customers/$userId/reveal',
    body: {'field': field, 'reason': reason},
  );
  static Future<Map<String, dynamic>> linkSupportDispute(
    int ticketId, {
    required int disputeCaseId,
    required String reason,
    bool holdPayout = false,
  }) => _phase14Json(
    'POST',
    'support-trust/tickets/$ticketId/dispute',
    body: {
      'dispute_case_id': disputeCaseId,
      'reason': reason,
      'hold_payout': holdPayout,
    },
  );
  static Future<Map<String, dynamic>> mergeSupportTicketV25(
    int ticketId, {
    required int targetTicketId,
    required String reason,
  }) => _phase14Json(
    'POST',
    'support-trust/tickets/$ticketId/merge',
    body: {'target_ticket_id': targetTicketId, 'reason': reason},
  );
  static Future<Map<String, dynamic>> markSupportSpamV25(
    int ticketId, {
    required String reason,
    bool blockSender = false,
    int? hours,
  }) => _phase14Json(
    'POST',
    'support-trust/tickets/$ticketId/spam',
    body: {
      'reason': reason,
      'block_sender': blockSender,
      if (hours != null) 'hours': hours,
    },
  );
  static Future<Map<String, dynamic>> acquireSupportTicketLock(int ticketId) =>
      _phase14Json('POST', 'support-trust/tickets/$ticketId/lock');
  static Future<Map<String, dynamic>> releaseSupportTicketLock(int ticketId) =>
      _phase14Json('DELETE', 'support-trust/tickets/$ticketId/lock');
  static Future<Map<String, dynamic>> fetchSupportIncidentsV25() =>
      _phase14Json('GET', 'support-trust/incidents');
  static Future<Map<String, dynamic>> createSupportIncidentV25(
    Map<String, dynamic> data,
  ) => _phase14Json('POST', 'support-trust/incidents', body: data);
  static Future<Map<String, dynamic>> fetchActiveSupportIncident() =>
      _phase14Json('GET', 'support/status/active', auth: false);

  // ---------------------------------------------------------------------
  // V25.4 — KYC AI Review + Customer Email Center
  // ---------------------------------------------------------------------
  static Future<Map<String, dynamic>> fetchSupportKycAi({
    String? band,
    String? q,
    String? status,
  }) async {
    final params = <String, String>{
      if (band != null && band.isNotEmpty) 'band': band,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final path = params.isEmpty
        ? 'support/kyc-ai'
        : 'support/kyc-ai?${Uri(queryParameters: params).query}';
    return _phase14Json('GET', path);
  }

  static Future<Map<String, dynamic>> fetchSupportKycAiProfile(int id) =>
      _phase14Json('GET', 'support/kyc-ai/$id');
  static Future<Map<String, dynamic>> fetchCustomerEmailCenter() =>
      _phase14Json('GET', 'support/email-center');
  static Future<Map<String, dynamic>> fetchEmailPreferences() =>
      _phase14Json('GET', 'me/email-preferences');
  static Future<Map<String, dynamic>> updateEmailPreferences({
    required bool platformUpdates,
    required bool supportUpdates,
    required bool productTips,
  }) => _phase14Json(
    'PUT',
    'me/email-preferences',
    body: {
      'platform_updates': platformUpdates,
      'support_updates': supportUpdates,
      'product_tips': productTips,
    },
  );
  // ---------------------------------------------------------------------
  // V25.6 — Financial Manager Center
  // ---------------------------------------------------------------------
  static Future<Map<String, dynamic>> fetchFinancialManagerCenter() =>
      _phase14Json('GET', 'financial-manager/center');

  static Future<Map<String, dynamic>> fetchFinancialManagerFeature(
    String feature,
  ) => _phase14Json('GET', 'financial-manager/features/$feature');

  static Future<Map<String, dynamic>> revealFinancialPayoutAccount(
    int id,
    String reason,
  ) => _phase14Json(
    'POST',
    'financial-manager/payout-accounts/$id/reveal',
    body: {'reason': reason},
  );

  static Future<String> releaseFinancialSecurityHold(int id, String reason) async {
    final data = await _phase14Json('POST',
      'financial-manager/security-holds/$id/release', body: {'reason': reason});
    return data['message']?.toString() ?? 'تم فك التعليق الأمني.';
  }

  static Future<String> toggleFinancialCoupon(int id, bool active) async {
    final data = await _phase14Json(
      'PATCH',
      'financial-manager/coupons/$id',
      body: {'is_active': active},
    );
    return data['message']?.toString() ?? 'تم تحديث الكوبون.';
  }

  // ---------------------------------------------------------------------
  // V25.11 - Platform commission settings
  // ---------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchPlatformCommissionSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/platform-commissions'),
      headers: await _headers(auth: true),
    );
    final decoded = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(
            jsonDecode(utf8.decode(response.bodyBytes)) as Map,
          );
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    throw ApiException(_extractErrorMessage(decoded));
  }

  static Future<Map<String, dynamic>> updatePlatformCommissionSettings({
    required double projectRate,
    required double consultationRate,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/platform-commissions'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'project_commission_percentage': projectRate,
        'consultation_commission_percentage': consultationRate,
      }),
    );
    final decoded = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(
            jsonDecode(utf8.decode(response.bodyBytes)) as Map,
          );
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    throw ApiException(_extractErrorMessage(decoded));
  }

  // ---------------------------------------------------------------------
  // V25.13 — Reports center + archive
  // ---------------------------------------------------------------------
  static Future<Map<String, dynamic>> fetchReportCenter({
    String? type,
    required String from,
    required String to,
  }) async {
    final params = <String, String>{
      if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
      'from': from,
      'to': to,
    };
    final query = Uri(queryParameters: params).query;
    return _phase14Json('GET', 'report-center?$query');
  }

  static Future<Map<String, dynamic>> saveReportSnapshot({
    required String reportType,
    required String title,
    required String from,
    required String to,
  }) => _phase14Json(
    'POST',
    'report-center/saved',
    body: {
      'report_type': reportType,
      'title': title,
      'from': from,
      'to': to,
    },
  );

  static Future<Map<String, dynamic>> fetchReportArchive() =>
      _phase14Json('GET', 'report-center/archive');

  static Future<Map<String, dynamic>> archiveSavedReport(int id) =>
      _phase14Json('PATCH', 'report-center/saved/$id/archive');

  static Future<Map<String, dynamic>> restoreSavedReport(int id) =>
      _phase14Json('PATCH', 'report-center/saved/$id/restore');

  static Future<String> downloadReportExport({
    required String format,
    required String type,
    required String from,
    required String to,
  }) async {
    final normalized = format.toLowerCase() == 'excel' ? 'excel' : 'pdf';
    final query = Uri(queryParameters: {
      'type': type,
      'from': from,
      'to': to,
    }).query;
    final response = await http.get(
      Uri.parse('$baseUrl/report-center/export/$normalized?$query'),
      headers: await _headers(auth: true),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = _safeResponseMap(response);
      throw ApiException(
        _extractErrorMessage(decoded),
        statusCode: response.statusCode,
        data: decoded,
      );
    }
    final directory = await getTemporaryDirectory();
    final extension = normalized == 'excel' ? 'xls' : 'pdf';
    final safeType = type.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${directory.path}/report_${safeType}_${from}_$to.$extension');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file.path;
  }

}


class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? data;

  ApiException(String message, {this.statusCode, this.data})
      : message = AppLanguage.instance.translateUi(message);

  @override
  String toString() => message;

  // V25.11 — Platform commissions
}
