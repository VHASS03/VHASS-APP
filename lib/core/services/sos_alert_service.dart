import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;

/// SOS Alert Service
/// Handles incoming SOS alerts from emergency contacts
/// Listens for real-time alerts via Socket.IO
class SOSAlertService {
  static IO.Socket? _socket;
  static final List<SOSAlert> _receivedAlerts = [];
  static Function(SOSAlert alert)? _onAlertReceived;

  static const Duration _connectionTimeout = Duration(seconds: 90);

  static Future<void> _wakeBackend(String serverUrl) async {
    try {
      final response = await http
          .get(Uri.parse('$serverUrl/api/health'))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        print('✅ [SOSAlertService] Backend wake-up ping OK');
      }
    } catch (e) {
      print('⚠️ [SOSAlertService] Backend wake-up ping failed: $e');
    }
  }

  /// Initialize Socket.IO connection for SOS alerts
  static Future<void> initializeSOSAlerts(
    String serverUrl,
    String? token,
  ) async {
    if (_socket != null && _socket!.connected) {
      print('🚨 [SOSAlertService] Already initialized');
      return;
    }

    try {
      print(
        '🚨 [SOSAlertService] Initializing SOS alert listener at $serverUrl',
      );

      await _wakeBackend(serverUrl);

      if (_socket != null) {
        _socket!.clearListeners();
        _socket!.disconnect();
        _socket!.dispose();
        _socket = null;
      }

      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableForceNew()
            .disableMultiplex()
            .setTimeout(_connectionTimeout.inMilliseconds)
            .setAuth(token != null ? {'token': token} : {})
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(8000)
            .build(),
      );

      _socket!.on('sos:alert-received', (data) {
        _handleSOSAlertReceived(data);
      });

      _socket!.onConnect((_) {
        print('✅ [SOSAlertService] Connected to alert server');
      });

      _socket!.onConnectError((data) {
        print('⚠️ [SOSAlertService] Connect error: $data');
      });

      _socket!.onDisconnect((_) {
        print('⚠️ [SOSAlertService] Disconnected from alert server');
      });

      _socket!.onError((dynamic error) {
        print('⚠️ [SOSAlertService] Socket error: $error');
      });

      print('✅ [SOSAlertService] SOS alert service initialized');
    } catch (e) {
      print('❌ [SOSAlertService] Failed to initialize: $e');
    }
  }

  /// Handle incoming SOS alert
  static void _handleSOSAlertReceived(dynamic data) {
    try {
      print('🚨 [SOSAlertService] Received SOS alert: $data');

      final alert = SOSAlert.fromJson(data as Map<String, dynamic>);
      _receivedAlerts.add(alert);

      if (_onAlertReceived != null) {
        _onAlertReceived!(alert);
      }

      print('🚨 [SOSAlertService] Alert from ${alert.userName} stored');
    } catch (e) {
      print('❌ [SOSAlertService] Error handling alert: $e');
    }
  }

  /// Register callback for incoming alerts
  static void onAlertReceived(Function(SOSAlert alert) callback) {
    _onAlertReceived = callback;
    print('🚨 [SOSAlertService] Alert callback registered');
  }

  /// Get all received alerts
  static List<SOSAlert> getReceivedAlerts() => _receivedAlerts;

  /// Clear received alerts
  static void clearAlerts() {
    _receivedAlerts.clear();
  }

  /// Disconnect from alert service
  static void dispose() {
    _socket?.clearListeners();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    print('🚨 [SOSAlertService] Disconnected');
  }
}

/// SOS Alert Model
class SOSAlert {
  final String sosId;
  final String userId;
  final String userName;
  final double? latitude;
  final double? longitude;
  final String timestamp;
  final String message;

  SOSAlert({
    required this.sosId,
    required this.userId,
    required this.userName,
    this.latitude,
    this.longitude,
    required this.timestamp,
    required this.message,
  });

  factory SOSAlert.fromJson(Map<String, dynamic> json) {
    return SOSAlert(
      sosId: json['sosId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Unknown User',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      timestamp:
          json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      message: json['message'] as String? ?? '🚨 Emergency Alert',
    );
  }

  @override
  String toString() =>
      'SOSAlert(sosId: $sosId, user: $userName, lat: $latitude, lng: $longitude)';
}
