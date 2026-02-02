/// API Configuration
///
/// IMPORTANT: Update baseUrl based on environment:
/// - Development (Emulator): http://10.0.2.2:5000/api
/// - Development (Physical Device): http://YOUR_COMPUTER_IP:5000/api
/// - Production (All Users): https://your-app.render.com/api
class ApiConfig {
  // 🚀 PRODUCTION - Works for ALL phones worldwide
  // Deploy backend to Render/Railway/Fly.io and use that URL
  // static const String baseUrl = 'https://vhass-backend.onrender.com/api';
  // static const String socketUrl = 'https://vhass-backend.onrender.com';

  // 🔧 DEVELOPMENT - Local testing only
  // For Physical Device (Your phone - RMX3771):
  static const String baseUrl = 'http://10.1.178.99:5000/api';
  static const String socketUrl = 'http://10.1.178.99:5000';

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
