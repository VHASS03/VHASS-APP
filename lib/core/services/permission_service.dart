import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request phone call permission
  static Future<bool> requestCallPermission() async {
    final status = await Permission.phone.request();
    return status.isGranted;
  }

  /// Request location permissions
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request all essential permissions
  static Future<Map<String, bool>> requestAllPermissions() async {
    final permissions = await [
      Permission.phone,
      Permission.location,
      Permission.microphone,
      Permission.contacts,
    ].request();

    return {
      'phone': permissions[Permission.phone]?.isGranted ?? false,
      'location': permissions[Permission.location]?.isGranted ?? false,
      'microphone': permissions[Permission.microphone]?.isGranted ?? false,
      'contacts': permissions[Permission.contacts]?.isGranted ?? false,
    };
  }

  /// Check if a specific permission is granted
  static Future<bool> isPermissionGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  /// Open app settings
  static Future<void> openAppSettings() async {
    openAppSettings();
  }

  /// Get permission status message
  static String getPermissionStatusMessage(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Permission granted';
      case PermissionStatus.denied:
        return 'Permission denied';
      case PermissionStatus.restricted:
        return 'Permission restricted by system';
      case PermissionStatus.limited:
        return 'Permission limited';
      case PermissionStatus.provisional:
        return 'Permission provisional';
      case PermissionStatus.permanentlyDenied:
        return 'Permission permanently denied. Please enable in app settings.';
    }
  }
}
