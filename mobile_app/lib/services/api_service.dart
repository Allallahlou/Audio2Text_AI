import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class ApiService {
  ApiService._();

  static String get baseUrl => ApiConfig.baseUrl;

  static const Duration uploadTimeout = Duration(minutes: 3);
  static const Duration transcriptionTimeout = Duration(minutes: 20);
  static const Duration historyTimeout = Duration(seconds: 30);

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.instance.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please log in first.');
    }

    return {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid server response.');
    }

    if (decoded is! Map) {
      throw Exception('Invalid server response.');
    }

    final data = Map<String, dynamic>.from(decoded);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data['detail'] ?? 'Request failed.';
      throw Exception(message.toString());
    }

    return data;
  }

  static Future<Map<String, dynamic>> uploadAudio({
    required String fileName,
    required List<int> bytes,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('The selected audio file is empty.');
    }

    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));

    request.headers.addAll(await _authHeaders());

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final streamedResponse = await request.send().timeout(uploadTimeout);

    final response = await http.Response.fromStream(streamedResponse);

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> transcribeAudio(String fileId) async {
    final headers = await _authHeaders();

    final response = await http
        .post(Uri.parse('$baseUrl/transcribe/$fileId'), headers: headers)
        .timeout(transcriptionTimeout);

    return _decodeResponse(response);
  }

  static Future<List<Map<String, dynamic>>> loadHistory() async {
    final headers = await _authHeaders();

    final response = await http
        .get(Uri.parse('$baseUrl/history'), headers: headers)
        .timeout(historyTimeout);

    final data = _decodeResponse(response);
    final items = data['recordings'] as List? ?? [];

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
