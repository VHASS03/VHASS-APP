import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/storage_service.dart';
import '../models/api_response.dart';

/// Base API Service
/// Handles HTTP requests with authentication
class ApiService {
  /// HTTP request timeout duration
  static const Duration _requestTimeout = Duration(seconds: 15);

  /// Get headers with authentication token
  static Future<Map<String, String>> _getHeaders() async {
    final token = await StorageService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Make GET request
  static Future<ApiResponse<T>> get<T>(
    String endpoint, {
    T? Function(dynamic)? fromJson,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _getHeaders();

      print('🔵 [GET] $endpoint - Headers: $headers');

      final response = await http.get(url, headers: headers).timeout(_requestTimeout);

      print('🟡 [GET] Response: ${response.statusCode} - ${response.body}');

      final jsonData = json.decode(response.body);
      return ApiResponse.fromJson(jsonData, fromJson);
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
      ).timeout(_requestTimeout);

      // Debug log response
      // ignore: avoid_print
      print('🟡 [POST] Response: ${response.statusCode} - ${response.body}');

      final jsonData = json.decode(response.body);
      return ApiResponse.fromJson(jsonData, fromJson);
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
      ).timeout(_requestTimeout);

      final jsonData = json.decode(response.body);
      return ApiResponse.fromJson(jsonData, fromJson);
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

      final response = await http.delete(url, headers: headers).timeout(_requestTimeout);

      final jsonData = json.decode(response.body);
      return ApiResponse.fromJson(jsonData, fromJson);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
        error: e,
      );
    }
  }
}
