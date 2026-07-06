import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';

/// Real-time OTP Service
/// Receives OTP via Socket.IO in real-time without SMS gateway
/// Uses device-specific rooms to prevent OTP being broadcast to multiple devices on shared phone numbers
class OTPService {
  static io.Socket? _socket;
  static String? _lastReceivedOTP;
  static String? _lastReceivedPhone;
  static String? _deviceId;
  static Function(String otp, String phone, int expiresIn)? _onOTPReceived;
  static Completer<bool>? _connectionCompleter;
  static bool _initialized = false;
  static bool _isConnecting = false;
  static bool _reportedConnectError = false;

  /// Render free tier can take 50+ seconds for the first WebSocket handshake.
  static const Duration _connectionTimeout = Duration(seconds: 90);

  /// Wake the backend over HTTP before opening WebSocket (helps Render cold start).
  static Future<void> _wakeBackend(String serverUrl) async {
    try {
      final healthUrl = Uri.parse('$serverUrl/api/health');
      final response = await http
          .get(healthUrl)
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        print('✅ Backend wake-up ping OK');
      } else {
        print('⚠️ Backend wake-up ping returned ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Backend wake-up ping failed: $e');
    }
  }

  /// Initialize OTP Socket connection (no JWT needed for pre-auth)
  static Future<void> initializeOTPConnection(String serverUrl) async {
    if (_initialized && _socket != null && _socket!.connected) {
      print('ℹ️  OTP Socket already initialized and connected');
      return;
    }

    if (_isConnecting) {
      print('ℹ️  OTP Socket connection already in progress');
      if (_connectionCompleter != null) {
        await _connectionCompleter!.future.timeout(
          _connectionTimeout,
          onTimeout: () => false,
        );
      }
      return;
    }

    _isConnecting = true;
    _reportedConnectError = false;

    try {
      print('🔌 Initializing OTP Socket connection to: $serverUrl');
      await _wakeBackend(serverUrl);

      if (_socket != null) {
        print('🧹 Disposing old socket before creating new one...');
        try {
          _socket!.clearListeners();
          _socket!.disconnect();
          _socket!.dispose();
        } catch (e) {
          print('⚠️  Error disposing old socket: $e');
        }
        _socket = null;
      }

      _connectionCompleter = Completer<bool>();

      // Flutter mobile only supports WebSocket transport (not HTTP polling).
      // Render free tier needs a longer timeout than the default 20 seconds.
      _socket = io.io(
        serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableForceNew()
            .disableMultiplex()
            .setTimeout(_connectionTimeout.inMilliseconds)
            .setReconnectionAttempts(2)
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(8000)
            .build(),
      );

      _socket!.onConnect((_) {
        print('✅ OTP Socket connected successfully!');
        print('   Socket ID: ${_socket!.id}');
        _reportedConnectError = false;

        if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
          _connectionCompleter!.complete(true);
        }
      });

      _socket!.onConnectError((data) {
        if (!_reportedConnectError) {
          _reportedConnectError = true;
          print('⚠️ OTP Socket unavailable ($data) — OTP will be delivered via SMS');
        }

        if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
          _connectionCompleter!.complete(false);
        }
      });

      _socket!.onDisconnect((_) {
        print('⚠️  OTP Socket disconnected');
      });

      _socket!.onError((data) {
        if (!_reportedConnectError) {
          print('⚠️  OTP Socket error: $data (SMS fallback active)');
        }
      });

      _socket!.on('auth:otp-received', (data) {
        final otp = data['otp'] as String?;
        final phone = data['phone'] as String?;
        final expiresIn = data['expiresIn'] as int? ?? 600;
        final message = data['message'] as String? ?? '';

        if (otp != null && phone != null) {
          _lastReceivedOTP = otp;
          _lastReceivedPhone = phone;

          _onOTPReceived?.call(otp, phone, expiresIn);

          print('🎉 OTP Received via Socket.IO:');
          print('   Phone: $phone');
          print('   OTP: $otp');
          print(
            '   Expires in: $expiresIn seconds (${expiresIn ~/ 60} minutes)',
          );
          if (message.isNotEmpty) print('   Message: $message');
        }
      });

      _socket!.on('auth:otp-room-joined', (data) {
        print('✅ Successfully joined OTP room: ${data['phone']}');
        print('   Ready to receive OTP for this phone number');
      });

      print('🔌 Connecting OTP Socket (WebSocket, up to 90s on cold start)...');
      _socket!.connect();

      try {
        final connected = await _connectionCompleter!.future.timeout(
          _connectionTimeout,
          onTimeout: () {
            print(
              '⚠️ OTP Socket not ready yet — SMS will deliver OTP (Render cold start can be slow)',
            );
            return false;
          },
        );

        if (connected) {
          print('✅ OTP Socket ready to receive OTP');
          _initialized = true;
        } else {
          print('ℹ️ OTP Socket skipped — SMS fallback is active');
        }
      } catch (e) {
        print('⚠️ OTP Socket connection wait ended: $e');
      }
    } catch (e) {
      print('⚠️ OTP Socket init failed (SMS fallback active): $e');
    } finally {
      _isConnecting = false;
    }
  }

  /// Register for OTP notifications for a specific phone
  /// IMPORTANT: Uses device-specific room (not phone room) to prevent multi-device OTP sends
  /// MUST be called BEFORE sending OTP API request
  static Future<void> registerForOTP(String phone) async {
    try {
      if (_deviceId == null) {
        await _getDeviceId();
      }

      final isConnected = _socket != null && _socket!.connected;

      print('📲 Registering for OTP on phone: $phone');
      print('   Device ID: $_deviceId');
      print('   Socket connected: $isConnected');

      if (!isConnected) {
        print(
          '⏳ Socket not connected, waiting briefly for WebSocket (SMS is primary)...',
        );

        int attempts = 0;
        const maxAttempts = 100; // 10 seconds
        while ((_socket == null || !_socket!.connected) && attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }

        if (_socket == null || !_socket!.connected) {
          print('ℹ️ Socket not ready — OTP will arrive via SMS');
          return;
        }
      }

      _socket!.emit('auth:register-for-otp', {
        'phone': phone,
        'deviceId': _deviceId,
      });
      print('✅ Registered for OTP on device: $_deviceId');
      print('   Phone: $phone');
      print('   Waiting for OTP to arrive...');
    } catch (e) {
      print('⚠️ Socket OTP registration skipped: $e');
    }
  }

  /// Get device ID for this device
  static Future<void> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'unknown';
      } else {
        _deviceId = 'unknown';
      }

      print('🔍 Device ID: $_deviceId');
    } catch (e) {
      print('⚠️  Could not get device ID: $e');
      _deviceId = 'unknown';
    }
  }

  /// Set callback to be called when OTP is received
  static void onOTPReceived(
    Function(String otp, String phone, int expiresIn) callback,
  ) {
    _onOTPReceived = callback;
  }

  /// Get the last received OTP
  static String? getLastOTP() => _lastReceivedOTP;

  /// Get the phone number OTP was received for
  static String? getLastPhone() => _lastReceivedPhone;

  /// Clear the last received OTP
  static void clearLastOTP() {
    _lastReceivedOTP = null;
    _lastReceivedPhone = null;
  }

  /// Disconnect from OTP Socket
  /// Call this when leaving auth screens to clean up resources
  static void disconnect() {
    try {
      if (_socket != null) {
        print('📴 Disconnecting OTP Socket...');
        _socket!.clearListeners();
        _socket!.disconnect();
        _socket!.dispose();
        _socket = null;
      }
      _initialized = false;
      _isConnecting = false;
      _reportedConnectError = false;
      _onOTPReceived = null;
      _connectionCompleter = null;
      print('📴 OTP Socket disconnected and disposed');
    } catch (e) {
      print('❌ Failed to disconnect OTP Socket: $e');
      _socket = null;
      _initialized = false;
      _isConnecting = false;
      _reportedConnectError = false;
      _onOTPReceived = null;
      _connectionCompleter = null;
    }
  }
}
