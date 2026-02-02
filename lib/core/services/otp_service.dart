import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async';
import 'dart:io';

/// Real-time OTP Service
/// Receives OTP via Socket.IO in real-time without SMS gateway
/// Uses device-specific rooms to prevent OTP being broadcast to multiple devices on shared phone numbers
class OTPService {
  static late io.Socket _socket;
  static String? _lastReceivedOTP;
  static String? _lastReceivedPhone;
  static String? _deviceId;
  static Function(String otp, String phone, int expiresIn)? _onOTPReceived;
  static Completer<bool>? _connectionCompleter;
  static bool _initialized = false;

  /// Initialize OTP Socket connection (no JWT needed for pre-auth)
  static Future<void> initializeOTPConnection(String serverUrl) async {
    if (_initialized && _socket.connected) {
      print('ℹ️  OTP Socket already initialized and connected');
      return;
    }

    try {
      print('🔌 Initializing OTP Socket connection to: $serverUrl');

      _connectionCompleter = Completer<bool>();

      _socket = io.io(
        serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(10)
            .build(),
      );

      // Listen for connection events
      _socket.onConnect((_) {
        print('✅ OTP Socket connected successfully!');
        print('   Socket ID: ${_socket.id}');

        if (!_connectionCompleter!.isCompleted) {
          _connectionCompleter!.complete(true);
        }
      });

      _socket.onConnectError((data) {
        print('❌ OTP Socket connection ERROR: $data');
        print('   ⚠️  CRITICAL: Check if backend is running at $serverUrl');
        print(
          '   ⚠️  For Android Emulator: Backend should be at http://10.0.2.2:5000',
        );
        print(
          '   ⚠️  For Physical Device: Backend should be at http://YOUR_COMPUTER_IP:5000',
        );

        if (!_connectionCompleter!.isCompleted) {
          _connectionCompleter!.complete(false);
        }
      });

      _socket.onDisconnect((_) {
        print('⚠️  OTP Socket disconnected');
      });

      _socket.onError((data) {
        print('⚠️  OTP Socket error event: $data');
      });

      // Listen for OTP events
      _socket.on('auth:otp-received', (data) {
        final otp = data['otp'] as String?;
        final phone = data['phone'] as String?;
        final expiresIn = data['expiresIn'] as int? ?? 600;
        final message = data['message'] as String? ?? '';

        if (otp != null && phone != null) {
          _lastReceivedOTP = otp;
          _lastReceivedPhone = phone;

          // Call the callback if registered
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

      // Listen for room join confirmation
      _socket.on('auth:otp-room-joined', (data) {
        print('✅ Successfully joined OTP room: ${data['phone']}');
        print('   Ready to receive OTP for this phone number');
      });

      // IMPORTANT: Actually connect!
      print('🔌 Calling _socket.connect()...');
      _socket.connect();

      // Wait for connection with timeout
      print('⏳ Waiting for Socket.IO connection (max 5 seconds)...');
      try {
        final connected = await _connectionCompleter!.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('❌ Socket.IO connection timeout after 5 seconds');
            print('   Backend at $serverUrl did not respond');
            return false;
          },
        );

        if (connected) {
          print('✅ OTP Socket ready to send/receive OTP');
          _initialized = true;
        } else {
          print('❌ OTP Socket failed to connect');
          print('   Check backend URL and ensure backend is running');
          print('   Check firewall and network connectivity');
        }
      } catch (e) {
        print('❌ Error waiting for connection: $e');
      }
    } catch (e) {
      print('❌ Failed to initialize OTP Socket: $e');
      rethrow;
    }
  }

  /// Register for OTP notifications for a specific phone
  /// IMPORTANT: Uses device-specific room (not phone room) to prevent multi-device OTP sends
  /// MUST be called BEFORE sending OTP API request
  static Future<void> registerForOTP(String phone) async {
    try {
      // Get device ID if not already cached
      if (_deviceId == null) {
        await _getDeviceId();
      }

      print('📲 Registering for OTP on phone: $phone');
      print('   Device ID: $_deviceId');
      print('   Socket connected: ${_socket.connected}');

      // If not connected, wait up to 3 seconds for connection
      if (!_socket.connected) {
        print(
          '⏳ Socket not connected, waiting for connection (max 3 seconds)...',
        );

        int attempts = 0;
        while (!_socket.connected && attempts < 30) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }

        if (!_socket.connected) {
          print('❌ Socket failed to connect after waiting');
          print('   OTP will rely on SMS fallback');
          return;
        }
      }

      // Register for OTP using DEVICE room, not phone room
      // This prevents multiple devices on same phone from all receiving OTP
      _socket.emit('auth:register-for-otp', {
        'phone': phone,
        'deviceId': _deviceId, // Device-specific routing
      });
      print('✅ Registered for OTP on device: $_deviceId');
      print('   Phone: $phone');
      print('   Waiting for OTP to arrive...');
    } catch (e) {
      print('❌ Failed to register for OTP: $e');
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
  static void disconnect() {
    try {
      _socket.disconnect();
      print('📴 OTP Socket disconnected');
    } catch (e) {
      print('❌ Failed to disconnect OTP Socket: $e');
    }
  }
}
