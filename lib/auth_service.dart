import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String baseUrl = 'https://real-pleasantly-grizzly.ngrok-free.app';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Storage key
  static const String _accessTokenKey = 'access_token';

  String? _accessToken;
  bool _isLoggedIn = false;

  // Initialize auth state
  static Future<void> initialize() async {
    await _instance._loadToken();
  }

  Future<void> _loadToken() async {
    _accessToken = await _storage.read(key: _accessTokenKey);
    _isLoggedIn = _accessToken != null;
  }

  // --- LOGIN Function ---
  static Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/token/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _instance._storeToken(accessToken: data['access']);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<void> _storeToken({required String accessToken}) async {
    _accessToken = accessToken;
    _isLoggedIn = true;
    await _storage.write(key: _accessTokenKey, value: accessToken);
  }

  // --- LOGOUT Function ---
  static Future<void> logout() async {
    await _storage.delete(key: _accessTokenKey);
    _instance._accessToken = null;
    _instance._isLoggedIn = false;
  }

  // --- AUTH HEADER FOR API CALLS ---
  static Future<Map<String, String>> getAuthHeader() async {
    if (_instance._accessToken == null) {
      await _instance._loadToken();
    }

    return {
      'Authorization': 'Bearer ${_instance._accessToken}',
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true'
    };
  }

  // --- PROTECTED API CALL WRAPPER ---
  static Future<http.Response> protectedApiCall(
      Future<http.Response> Function() apiCall,
      ) async {
    try {
      // First attempt
      var response = await apiCall();

      // If unauthorized, clear token and throw
      if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please login again.');
      }

      return response;
    } catch (e) {
      debugPrint('Protected API call error: $e');
      rethrow;
    }
  }

  // --- GETTERS ---
  static bool get isLoggedIn => _instance._isLoggedIn;
  static String? get accessToken => _instance._accessToken;

  // --- USER REGISTRATION ---
  static Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required bool isOwner,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'phone': phone,
          'is_owner': isOwner,
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Registration error: $e');
      return false;
    }
  }
}