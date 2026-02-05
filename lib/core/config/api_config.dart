/// API Configuration
///
/// IMPORTANT: Update baseUrl based on environment:
/// - Development (Emulator): http://10.0.2.2:5000/api
/// - Development (Physical Device): http://YOUR_COMPUTER_IP:5000/api
/// - Production (All Users): https://your-app.render.com/api
///
/// For production builds, use: flutter build --dart-define=API_URL=https://your-app.render.com
class ApiConfig {
  // Default development URLs (override with --dart-define for production)
  static const String _devBaseUrl = 'http://10.1.178.99:5000';
  
  // Use environment variable if provided, otherwise use development URL
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: '$_devBaseUrl/api',
  );
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL', 
    defaultValue: _devBaseUrl,
  );

  // For Android Emulator (if testing on emulator):
  // static const String baseUrl = 'http://10.0.2.2:5000/api';
  // static const String socketUrl = 'http://10.0.2.2:5000';

  // API Endpoints
  static const String authSendOtp = '/auth/send-otp';
  static const String authVerifyOtp = '/auth/verify-otp';
  static const String sosTrigger = '/sos/trigger';
  static const String sosUpdateLocation = '/sos/update-location';
  static const String sosReportCallResult = '/sos/report-call-result';
  static const String sosEnd = '/sos/end';
  static const String sosStatus = '/sos/status';
  static const String contacts = '/contacts';
  static const String devicePair = '/device/pair';
  static const String deviceValidateTrigger = '/device/validate-trigger';
  static const String chatMessage = '/chat/message';
}
