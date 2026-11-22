import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _tokenKey = 'audio2text_access_token';

  static const Duration _timeout = Duration(seconds: 30);

  // Decode JSON and handle server errors consistently.
  Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> data = {};

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Keep an empty response map if the body is not valid JSON.
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          data['detail'] ??
          data['message'] ??
          'Request failed: ${response.statusCode}';

      throw Exception(message.toString());
    }

    return data;
  }

  // Save the access token securely.
  Future<void> _saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  // Read the saved access token.
  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  // Remove the saved access token.
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // Register a new client account.
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'full_name': fullName.trim(),
            'email': email.trim(),
            'phone': phone.trim(),
            'password': password,
          }),
        )
        .timeout(_timeout);

    final data = _decodeResponse(response);
    final token = data['access_token'];

    if (token is String && token.isNotEmpty) {
      await _saveToken(token);
    }

    return data;
  }

  // Log in an existing client.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'password': password}),
        )
        .timeout(_timeout);

    final data = _decodeResponse(response);
    final token = data['access_token'];

    if (token is String && token.isNotEmpty) {
      await _saveToken(token);
    }

    return data;
  }

  // Get the currently authenticated user.
  Future<Map<String, dynamic>> getMe() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('No active session. Please log in.');
    }

    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/auth/me'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(_timeout);

    try {
      return _decodeResponse(response);
    } catch (_) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        await clearToken();
      }
      rethrow;
    }
  }

  // Log out and always clear the local session.
  Future<void> logout() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      await clearToken();
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(_timeout);

      _decodeResponse(response);
    } finally {
      await clearToken();
    }
  }
}
