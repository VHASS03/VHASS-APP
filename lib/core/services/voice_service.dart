import '../models/api_response.dart';
import 'api_service.dart';

/// Voice Service
/// Handles voice detection and sends transcribed text to backend
class VoiceService {
  /// Trigger SOS via voice command
  /// Sends transcribed text to backend for voice trigger phrase detection
  static Future<ApiResponse<Map<String, dynamic>>> triggerVoice({
    required String text,
    double? latitude,
    double? longitude,
    double? confidence,
  }) async {
    try {
      final Map<String, dynamic> body = {'text': text};

      if (latitude != null && longitude != null) {
        body['latitude'] = latitude;
        body['longitude'] = longitude;
      }

      if (confidence != null) {
        body['confidence'] = confidence;
      }

      // ignore: avoid_print
      print('🎤 [VoiceService] Sending voice input: "$text"');

      final response = await ApiService.post<Map<String, dynamic>>(
        '/voice/trigger',
        body,
      );

      return response;
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to send voice input: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Check voice service health and get available trigger phrases
  static Future<ApiResponse<Map<String, dynamic>>> checkHealth() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        '/voice/health',
      );

      return response;
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Voice service health check failed: ${e.toString()}',
        error: e,
      );
    }
  }
}
