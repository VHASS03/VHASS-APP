import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/services/sos_service.dart';
import '../../core/services/sms_service.dart';
import '../../core/services/contacts_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/phone_formatter.dart';
import '../sos_map/sos_map_screen.dart';

class EmergencyActiveScreen extends StatefulWidget {
  const EmergencyActiveScreen({super.key});

  @override
  State<EmergencyActiveScreen> createState() => _EmergencyActiveScreenState();
}

class _EmergencyActiveScreenState extends State<EmergencyActiveScreen> {
  final Battery _battery = Battery();
  final LocalAuthentication _localAuth = LocalAuthentication();
  int _batteryLevel = 100;
  late StreamSubscription<BatteryState> _batterySubscription;

  // Native method channel for automatic calls
  static const platform = MethodChannel('com.example.my_app/dialer');

  // --- STOPWATCH VARIABLES ---
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  // --- CONTACTS AND CALLING ---
  List<Contact> _contacts = [];
  int _currentContactIndex = 0;
  bool _calledContacts = false;

  // --- SOS DATA ---
  String? _sosId;

  @override
  void initState() {
    super.initState();
    _getBatteryLevel();
    _startStopwatch(); // Start counting when screen opens

    _batterySubscription = _battery.onBatteryStateChanged.listen((
      BatteryState state,
    ) {
      _getBatteryLevel();
    });

    // Load contacts and trigger calls/SMS when SOS is activated
    _initializeEmergency();
  }

  /// Initialize emergency by loading contacts and triggering calls
  Future<void> _initializeEmergency() async {
    try {
      print('🚨 Emergency initialized - Loading contacts from cache...');
      final response = await ContactsService.getContactsFromCache();
      if (response.success && response.data != null) {
        setState(() {
          _contacts = response.data!;
          _contacts.sort((a, b) => a.priority.compareTo(b.priority));
        });
        print('✅ Loaded ${_contacts.length} contacts');

        // Trigger SOS and call contacts
        if (_contacts.isNotEmpty) {
          await _triggerSOSAndCallContacts();
        }
      }
    } catch (e) {
      print('❌ Error initializing emergency: $e');
    }
  }

  /// Trigger SOS and start calling contacts
  Future<void> _triggerSOSAndCallContacts() async {
    try {
      print('📞 Triggering SOS...');

      // Get current user name for alert
      final userName = await StorageService.getUserName() ?? 'User';

      // Get current location for alert
      Position? currentPosition;
      try {
        currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
      } catch (e) {
        print('⚠️ Could not get current position: $e');
      }

      final sosResponse = await SOSService.triggerSOS();

      if (sosResponse.success && sosResponse.data != null) {
        final data = sosResponse.data as Map<String, dynamic>;
        final sosId = data['sosId'] as String?;

        print('✅ SOS triggered successfully with ID: $sosId');

        setState(() {
          _sosId = sosId;
          _calledContacts = true;
        });

        // Send SOS alerts to all emergency contacts
        if (_contacts.isNotEmpty && currentPosition != null) {
          _sendSOSAlertsToContacts(
            userName,
            currentPosition.latitude,
            currentPosition.longitude,
          );
        }

        // Open real-time location map
        if (sosId != null && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => SOSMapScreen(sosId: sosId)),
          );
        }

        // Start calling contacts sequentially
        if (_contacts.isNotEmpty) {
          _callNextContact();
          _sendSMSToAllContacts();
        }
      } else if (sosResponse.message?.contains('already active') == true) {
        // SOS already active - still make calls to contacts
        print('! SOS already active, but proceeding with calls anyway');

        // Try to get the active SOS ID from response data first
        String? activeSosId;
        if (sosResponse.data is Map<String, dynamic>) {
          final dataMap = sosResponse.data as Map<String, dynamic>;
          activeSosId = dataMap['sosId'] as String?;
        }

        // Fallback to SOSService if not in response
        activeSosId ??= SOSService.getCurrentSosId();

        setState(() {
          _sosId = activeSosId;
          _calledContacts = true;
        });

        // Send alerts even if SOS already active
        if (_contacts.isNotEmpty && currentPosition != null) {
          _sendSOSAlertsToContacts(
            userName,
            currentPosition.latitude,
            currentPosition.longitude,
          );
        }

        // Start calling contacts
        if (_contacts.isNotEmpty) {
          _callNextContact();
          _sendSMSToAllContacts();
        }
      } else {
        print('❌ Failed to trigger SOS: ${sosResponse.message}');
      }
    } catch (e) {
      print('❌ Error triggering SOS: $e');
    }
  }

  /// Send SOS alert notifications to all emergency contacts concurrently
  /// Like Indian weather alerts - bypasses silent mode with sound and vibration
  Future<void> _sendSOSAlertsToContacts(
    String userName,
    double latitude,
    double longitude,
  ) async {
    print('🚨 Sending SOS alerts to ${_contacts.length} contacts (concurrent)');

    // Send all alerts concurrently using Future.wait()
    final alertFutures = _contacts.map((contact) async {
      try {
        await NotificationService.sendSOSAlert(
          userName: userName,
          contactName: contact.name,
          latitude: latitude,
          longitude: longitude,
          address: null, // Could be populated if geocoding is available
        );
        print('✅ SOS alert sent to ${contact.name}');
      } catch (e) {
        print('❌ Error sending alert to ${contact.name}: $e');
      }
    }).toList();

    await Future.wait(alertFutures);
  }

  /// Call next contact in priority order
  Future<void> _callNextContact() async {
    if (_currentContactIndex >= _contacts.length) {
      print('📞 All contacts called');
      return;
    }

    final contact = _contacts[_currentContactIndex];
    print('📞 Calling contact: ${contact.name}');

    try {
      final phoneNumber = PhoneFormatter.getInternationalFormat(
        contact.phone,
        contact.countryCode,
      );

      // Use native method to make automatic call (no dialer popup)
      try {
        final result = await platform.invokeMethod('makeCall', {
          'phoneNumber': phoneNumber,
        });
        if (result == true) {
          print('✅ Call initiated to ${contact.name}');
        } else {
          print('❌ Failed to initiate call to ${contact.name}');
        }
      } on PlatformException catch (e) {
        print('❌ Platform exception: ${e.message}');
      }

      _currentContactIndex++;

      // Call next contact after 5 seconds if first doesn't answer
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _currentContactIndex < _contacts.length) {
          _callNextContact();
        }
      });
    } catch (e) {
      print('❌ Error calling ${contact.name}: $e');
      _currentContactIndex++;
      _callNextContact();
    }
  }

  /// Send SMS to all contacts concurrently
  Future<void> _sendSMSToAllContacts() async {
    print(
      '📱 Sending automatic SMS to all emergency contacts with location (concurrent)...',
    );

    // Request SMS permission first
    final hasPermission = await SMSService.requestSMSPermission();
    if (!hasPermission) {
      print('⚠️ SMS permission denied - cannot send SMS alerts');
      return;
    }

    // Get current location once for all SMS
    Position? currentPosition;
    try {
      currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      print('⚠️ Could not get location for SMS: $e');
    }

    // Create SMS message with location
    String message;
    if (currentPosition != null) {
      message =
          'EMERGENCY: I need immediate help! Location: ${currentPosition.latitude.toStringAsFixed(6)}, ${currentPosition.longitude.toStringAsFixed(6)} - https://maps.google.com/?q=${currentPosition.latitude},${currentPosition.longitude}';
    } else {
      message =
          'EMERGENCY: I need immediate help! Please call me back urgently. My location is being shared with emergency services.';
    }

    // Send all SMS concurrently using Future.wait()
    final smsFutures = _contacts.map((contact) async {
      try {
        final phoneNumber = PhoneFormatter.getInternationalFormat(
          contact.phone,
          contact.countryCode,
        );

        // Send SMS directly using device native SMS (not opening dialog)
        final success = await SMSService.sendCustomSMS(phoneNumber, message);

        if (success) {
          print('✅ SMS sent to ${contact.name} ($phoneNumber)');
        } else {
          print('⚠️ Failed to send SMS to ${contact.name}');
        }
      } catch (e) {
        print('❌ Error sending SMS to ${contact.name}: $e');
      }
    }).toList();

    await Future.wait(smsFutures);
  }

  // Logic to increment timer every second
  void _startStopwatch() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime += const Duration(seconds: 1);
      });
    });
  }

  // Helper to format Duration into 0:00 string
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _getBatteryLevel() async {
    final level = await _battery.batteryLevel;
    if (mounted) {
      setState(() {
        _batteryLevel = level;
      });
    }
  }

  /// Request device PIN/password/biometric to cancel emergency
  Future<void> _requestPINToCancel(BuildContext context) async {
    try {
      // Check if device supports biometric/device authentication
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics && !isDeviceSupported) {
        // Fallback: Show warning dialog if device doesn't support authentication
        if (mounted) {
          final confirm = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('⚠️ Warning'),
              content: const Text(
                'Your device does not support biometric authentication.\n\n'
                'Are you sure you want to cancel the emergency?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No, Keep Active'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Yes, Cancel Emergency'),
                ),
              ],
            ),
          );

          if (confirm == true) {
            await _cancelEmergency();
          }
        }
        return;
      }

      // Get available biometric types
      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      String authMessage = 'Authenticate to cancel emergency';
      if (availableBiometrics.contains(BiometricType.fingerprint)) {
        authMessage = 'Scan fingerprint to cancel emergency';
      } else if (availableBiometrics.contains(BiometricType.face)) {
        authMessage = 'Face ID to cancel emergency';
      }

      // Attempt authentication
      final authenticated = await _localAuth.authenticate(
        localizedReason: authMessage,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/password fallback
        ),
      );

      if (authenticated && mounted) {
        print('✅ Authentication successful - Canceling emergency');
        await _cancelEmergency();
      } else {
        print('❌ Authentication failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. Emergency still active.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Authentication error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Cancel the emergency after successful authentication
  Future<void> _cancelEmergency() async {
    try {
      await SOSService.endSOS(reason: 'CANCELLED');
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Error canceling SOS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // Stop the timer and clear memory
    _batterySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // --- RED STATUS HEADER ---
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFD32F2F),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EMERGENCY ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Contacts being notified',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(_elapsedTime), // DISPLAY DYNAMIC TIME
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFeatures: [
                          FontFeature.tabularFigures(),
                        ], // Keeps numbers from jumping
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ... Rest of your Column code remains exactly the same ...
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Clickable Map Icon
                GestureDetector(
                  onTap: () {
                    final sosId = _sosId ?? SOSService.getCurrentSosId();
                    if (sosId != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => SOSMapScreen(sosId: sosId),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'SOS session not available. Please try again.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(0.15),
                          border: Border.all(
                            color: const Color(0xFFD32F2F),
                            width: 2,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.map,
                            color: Color(0xFFD32F2F),
                            size: 50,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'View Map',
                            style: TextStyle(
                              color: const Color(0xFFD32F2F),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Live location tracking active',
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Updates every 5 seconds',
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F0F14) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Help is being notified',
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stay calm. We\'re reaching your contacts.',
                        style: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatusItem(
                      context,
                      Icons.battery_std,
                      'Battery',
                      '$_batteryLevel%',
                    ),
                    const SizedBox(width: 16),
                    _buildStatusItem(
                      context,
                      Icons.phone_in_talk,
                      'Calling',
                      '${_contacts.length} contacts',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _requestPINToCancel(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'End SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F0F14) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
