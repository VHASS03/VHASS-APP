import '../models/api_response.dart';
import 'api_service.dart';

/// Chat message model
class ChatMessage {
  final String sender; // 'user' or 'bot'
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      sender: json['sender'] ?? 'bot',
      text: json['text'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
}

/// HTTP-based Chat Service
/// Uses REST API instead of Socket.IO for reliable chat functionality
class ChatService {
  /// Send a message and get AI response
  static Future<ApiResponse<Map<String, dynamic>>> sendMessage(
    String message,
  ) async {
    try {
      print('💬 [ChatService] Sending message: "$message"');

      final response = await ApiService.post<Map<String, dynamic>>(
        '/chat/message',
        {'message': message},
      );

      if (response.success) {
        print('✅ [ChatService] Got response: ${response.data?['response']?.substring(0, 50)}...');
      } else {
        print('❌ [ChatService] Error: ${response.message}');
      }

      return response;
    } catch (e) {
      print('❌ [ChatService] Exception: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to send message: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Get chat history
  static Future<ApiResponse<List<ChatMessage>>> getHistory({
    int limit = 50,
  }) async {
    try {
      print('📜 [ChatService] Loading chat history...');

      final response = await ApiService.get<Map<String, dynamic>>(
        '/chat/history?limit=$limit',
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final messagesJson = data['messages'] as List? ?? [];
        
        final messages = messagesJson
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();

        print('✅ [ChatService] Loaded ${messages.length} messages');

        return ApiResponse(
          success: true,
          data: messages,
          message: 'Chat history loaded',
        );
      }

      return ApiResponse(
        success: false,
        message: response.message ?? 'Failed to load history',
        data: [],
      );
    } catch (e) {
      print('❌ [ChatService] History error: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to load chat history: ${e.toString()}',
        error: e,
        data: [],
      );
    }
  }

  /// Clear chat history and start fresh
  static Future<ApiResponse<void>> clearChat() async {
    try {
      print('🗑️ [ChatService] Clearing chat...');

      final response = await ApiService.post<Map<String, dynamic>>(
        '/chat/clear',
        {},
      );

      if (response.success) {
        print('✅ [ChatService] Chat cleared');
      }

      return ApiResponse(
        success: response.success,
        message: response.message,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to clear chat: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Check if chat service is healthy
  static Future<bool> checkHealth() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        '/chat/health',
      );
      return response.success;
    } catch (e) {
      return false;
    }
  }
}

