import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/storage_service.dart';
import '../services/session_service.dart';
import '../models/api_response.dart';

/// Base API Service
/// Handles HTTP requests with authentication
class ApiService {
  /// Get headers with authentication token
  static Future<Map<String, String>> _getHeaders() async {
    final token = await StorageService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Endpoints where 401 means "wrong credentials" (e.g. wrong OTP), not an expired session
  static const _credentialEndpoints = [
    ApiConfig.authSendOtp,
    ApiConfig.authVerifyOtp,
    '/auth/signup',
  ];

  /// A 401 only means the session expired if the request was sent with a token
  /// and isn't a login/OTP call. Otherwise the caller shows the server's message.
  static Future<void> _handleUnauthorized(
    String endpoint,
    Map<String, String> headers,
  ) async {
    final sentWithToken = headers.containsKey('Authorization');
    final isCredentialCall =
        _credentialEndpoints.any((e) => endpoint.startsWith(e));
    if (sentWithToken && !isCredentialCall) {
      await SessionService.handleExpired();
    }
  }

  /// Make GET request
  static Future<ApiResponse<T>> get<T>(
    String endpoint, {
    T? Function(dynamic)? fromJson,
    bool handleUnauthorized = true,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _getHeaders();

      print('🔵 [GET] $endpoint - Headers: $headers');

      final response = await http.get(url, headers: headers);

      print('🟡 [GET] Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 401 && handleUnauthorized) {
        await _handleUnauthorized(endpoint, headers);
      }

      final jsonData = json.decode(response.body);
      return ApiResponse.fromJson(
        jsonData,
        fromJson,
        statusCode: response.statusCode,
      );
    } catch (e) {
      print('🔴 [GET] Error: $e');
      return ApiResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Make POST request
  static Future<ApiResponse<T>> post<T>(
    String endpoint,
    Map<String, dynamic> body, {
    T? Function(dynamic)? fromJson,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _getHeaders();

      // Debug log request
      // ignore: avoid_print
      print(
        '🔵 [POST] $endpoint - Headers: $headers - Body: ${json.encode(body)}',
      );

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      // Debug log response
      // ignore: avoid_print
      print('🟡 [POST] Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 401) {
        await _handleUnauthorized(endpoint, headers);
      }

      final jsonData = json.decode(response.body);
      return ApiResponse.fromJson(
        jsonData,
        fromJson,
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Make PUT request
  static Future<ApiResponse<T>> put<T>(
    String endpoint,
    Map<String, dynamic> body, {
    T? Function(dynamic)? fromJson,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _getHeaders();

      final response = await http.put(
        url,
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 401) {
        await _handleUnauthorized(endpoint, headers);
      }

      final jsonData = json.decode(response.body);
      return ApiResponse.fromJson(
        jsonData,
        fromJson,
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Make DELETE request
  static Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    T? Function(dynamic)? fromJson,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _getHeaders();

      final response = await http.delete(url, headers: headers);

      if (response.statusCode == 401) {
        await _handleUnauthorized(endpoint, headers);
      }

      final jsonData = json.decode(response.body);
      return ApiResponse.fromJson(
        jsonData,
        fromJson,
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
        error: e,
      );
    }
  }
}
