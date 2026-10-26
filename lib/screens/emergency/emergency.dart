import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/services/sos_service.dart';
import '../../core/services/sms_service.dart';
import '../../core/services/contacts_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/live_location_service.dart';
import '../../core/utils/phone_formatter.dart';
import '../sos_map/sos_map_screen.dart';

/// Whether the SOS actually reached the server — drives what the screen claims.
enum _SosDeliveryState {
  sending(
    headline: 'SENDING SOS…',
    subtitle: 'Contacting the server',
    cardTitle: 'Sending your SOS',
    cardBody: 'Hold on — this takes a few seconds.',
  ),
  active(
    headline: 'EMERGENCY ACTIVE',
    subtitle: 'Contacts being notified',
    cardTitle: 'Help is being notified',
    cardBody: 'Stay calm. We\'re reaching your contacts.',
  ),
  serverUnreachable(
    headline: 'SOS NOT DELIVERED',
    subtitle: 'Server unreachable — contacting directly',
    cardTitle: 'Could not reach the server',
    cardBody:
        'We are calling and texting your contacts directly from this phone. '
        'Call 112 if you are in danger.',
  );

  const _SosDeliveryState({
    required this.headline,
    required this.subtitle,
    required this.cardTitle,
    required this.cardBody,
  });

  final String headline;
  final String subtitle;
  final String cardTitle;
  final String cardBody;
}

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
  static const platform = MethodChannel('com.syava.ai/dialer');

  // --- STOPWATCH VARIABLES ---
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  // --- CONTACTS AND CALLING ---
  List<Contact> _contacts = [];

  // --- SOS DATA ---
  String? _sosId;

  // What the header/status card tells the user. Must reflect reality:
  // never claim contacts are being notified when the SOS did not go out.
  _SosDeliveryState _deliveryState = _SosDeliveryState.sending;

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

  /// Initialize emergency by loading FRESH contacts from API and triggering calls
  Future<void> _initializeEmergency() async {
    try {
      print('🚨 Emergency initialized - Fetching FRESH contacts from server...');
      
      // IMPORTANT: Fetch FRESH contacts from API, NOT cache
      // This ensures we always have the latest contacts (deleted ones removed)
      final response = await ContactsService.getContacts();
      
      if (response.success && response.data != null) {
        // Filter only ACTIVE contacts
        final activeContacts = response.data!.where((c) => c.isActive).toList();
        activeContacts.sort((a, b) => a.priority.compareTo(b.priority));
        
        setState(() {
          _contacts = activeContacts;
        });
        
        print('✅ Loaded ${_contacts.length} ACTIVE contacts from server');
        
        // Also update cache with fresh data
        await ContactsService.preloadContacts();

        if (_contacts.isEmpty) {
          print('⚠️ No active emergency contacts found!');
        }
      } else {
        print('❌ Failed to fetch contacts: ${response.message}');
        // Fallback to cache only if API fails
        print('⚠️ Falling back to cached contacts...');
        final cachedResponse = await ContactsService.getContactsFromCache();
        if (cachedResponse.success && cachedResponse.data != null) {
          final activeContacts = cachedResponse.data!.where((c) => c.isActive).toList();
          activeContacts.sort((a, b) => a.priority.compareTo(b.priority));
          if (mounted) {
            setState(() {
              _contacts = activeContacts;
            });
          }
        }
      }
    } catch (e) {
      print('❌ Error loading contacts for emergency: $e');
    }

    // Always raise the SOS on the server, even with no contacts:
    // the server still records it and escalates.
    await _triggerSOSAndCallContacts();
  }

  /// Open the live map. Its "End SOS" button pops with `true`, and the
  /// authenticated cancel flow then runs here.
  void _openMap(String sosId) {
    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute(builder: (context) => SOSMapScreen(sosId: sosId)),
        )
        .then((endRequested) {
      if (endRequested == true && mounted) {
        _requestPINToCancel(context);
      }
    });
  }

  /// Retry sending the SOS to the server after a failed attempt
  Future<void> _retrySOS() async {
    setState(() => _deliveryState = _SosDeliveryState.sending);
    await _triggerSOSAndCallContacts(isRetry: true);
  }

  /// Trigger SOS and start calling contacts.
  /// Contacts are called/texted from the device even if the server is unreachable.
  Future<void> _triggerSOSAndCallContacts({bool isRetry = false}) async {
    try {
      print('📞 Triggering SOS...');

      // Get current user name for alert
      final userName = await StorageService.getUserName() ?? 'User';

      // Bounded location lookup — an SOS must never wait indefinitely for GPS
      final currentPosition = await SOSService.getQuickPosition();

      // This screen calls and texts contacts itself, so the service must not repeat it
      final sosResponse = await SOSService.triggerSOS(
        position: currentPosition,
        executeDeviceActions: false,
      );

      if (sosResponse.success && sosResponse.data != null) {
        final data = sosResponse.data as Map<String, dynamic>;
        final sosId = data['sosId'] as String?;

        print('✅ SOS triggered successfully with ID: $sosId');

        if (!mounted) return;
        setState(() {
          _sosId = sosId;
          _deliveryState = _SosDeliveryState.active;
        });

        // START LIVE LOCATION TRACKING IMMEDIATELY
        // This sends SMS updates every 30 seconds with live tracking link
        if (sosId != null) {
          print('🗺️ Starting live location tracking service...');
          await LiveLocationService.instance.startTracking(
            sosId: sosId,
            onUpdate: (position) {
              print('📍 Live location update: ${position.latitude}, ${position.longitude}');
            },
            onErrorCallback: (error) {
              print('❌ Live location error: $error');
            },
          );
        }

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
          _openMap(sosId);
        }

        // Call contacts one after another (no conference, no delay)
        if (_contacts.isNotEmpty && !isRetry) {
          _callAllContactsOneAfterAnother();
          _sendSMSToAllContacts(sosId, position: currentPosition);
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

        if (!mounted) return;
        setState(() {
          _sosId = activeSosId;
          _deliveryState = _SosDeliveryState.active;
        });

        // START LIVE LOCATION TRACKING for existing SOS
        if (activeSosId != null) {
          print('🗺️ Starting live location tracking for existing SOS...');
          await LiveLocationService.instance.startTracking(
            sosId: activeSosId,
            onUpdate: (position) {
              print('📍 Live location update: ${position.latitude}, ${position.longitude}');
            },
            onErrorCallback: (error) {
              print('❌ Live location error: $error');
            },
          );
        }

        // Send alerts even if SOS already active
        if (_contacts.isNotEmpty && currentPosition != null) {
          _sendSOSAlertsToContacts(
            userName,
            currentPosition.latitude,
            currentPosition.longitude,
          );
        }

        // Call contacts one after another (no conference, no delay)
        if (_contacts.isNotEmpty && !isRetry) {
          _callAllContactsOneAfterAnother();
          _sendSMSToAllContacts(activeSosId, position: currentPosition);
        }
      } else {
        print('❌ Failed to trigger SOS: ${sosResponse.message}');
        await _handleServerUnreachable(userName, currentPosition, isRetry);
      }
    } catch (e) {
      print('❌ Error triggering SOS: $e');
      await _handleServerUnreachable(
        await StorageService.getUserName() ?? 'User',
        null,
        isRetry,
      );
    }
  }

  /// The server could not be reached: say so honestly and still reach contacts
  /// directly from the phone (calls/SMS do not need the server).
  Future<void> _handleServerUnreachable(
    String userName,
    Position? position,
    bool isRetry,
  ) async {
    if (!mounted) return;
    setState(() => _deliveryState = _SosDeliveryState.serverUnreachable);

    // Contacts were already called/texted on the first attempt
    if (isRetry || _contacts.isEmpty) return;

    if (position != null) {
      _sendSOSAlertsToContacts(userName, position.latitude, position.longitude);
    }
    _callAllContactsOneAfterAnother();
    _sendSMSToAllContacts(null, position: position);
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

  /// Call contacts one after another with no delay between starting each call
  Future<void> _callAllContactsOneAfterAnother() async {
    if (_contacts.isEmpty) {
      print('📞 No contacts to call');
      return;
    }

    print('📞 Calling ${_contacts.length} contacts one after another (no delay)');

    for (final contact in _contacts) {
      try {
        final phoneNumber = PhoneFormatter.getInternationalFormat(
          contact.phone,
          contact.countryCode,
        );
        print('📞 Calling ${contact.name} ($phoneNumber)');
        platform.invokeMethod('makeCall', {
          'phoneNumber': phoneNumber,
        }).catchError((e) {
          print('❌ Call failed for ${contact.name}: $e');
        });
      } catch (e) {
        print('❌ Error initiating call to ${contact.name}: $e');
      }
    }
    print('✅ All ${_contacts.length} contacts called');
  }

  /// Send SMS to all contacts concurrently WITH LIVE TRACKING LINK
  Future<void> _sendSMSToAllContacts(String? sosId, {Position? position}) async {
    print(
      '📱 Sending automatic SMS with LIVE TRACKING LINK to all contacts...',
    );

    // Request SMS permission first
    final hasPermission = await SMSService.requestSMSPermission();
    if (!hasPermission) {
      print('⚠️ SMS permission denied - cannot send SMS alerts');
      return;
    }

    // Location for the SMS: reuse the one already fetched, else a bounded lookup
    final currentPosition = position ?? await SOSService.getQuickPosition();

    // Create LIVE TRACKING LINK if we have sosId
    final liveTrackingLink = sosId != null 
        ? 'https://vhass-backend-jfpr.onrender.com/track/$sosId'
        : null;
    
    final time = DateTime.now();
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    // Create SMS message with LIVE TRACKING LINK
    String message;
    if (currentPosition != null && liveTrackingLink != null) {
      message = '🚨 EMERGENCY ALERT 🚨\n'
          'I need IMMEDIATE help!\n\n'
          '🔴 LIVE TRACKING LINK:\n'
          '$liveTrackingLink\n\n'
          '📍 Current Location:\n'
          'https://maps.google.com/?q=${currentPosition.latitude},${currentPosition.longitude}\n\n'
          '⏰ Time: $timeStr\n'
          'Location updates every 30 seconds!\n'
          'Call 112 if you cannot reach me!';
    } else if (currentPosition != null) {
      message = '🚨 EMERGENCY ALERT 🚨\n'
          'I need IMMEDIATE help!\n\n'
          '📍 Location:\n'
          'https://maps.google.com/?q=${currentPosition.latitude},${currentPosition.longitude}\n\n'
          '⏰ Time: $timeStr\n'
          'Call 112 if you cannot reach me!';
    } else {
      message = '🚨 EMERGENCY ALERT 🚨\n'
          'I need IMMEDIATE help!\n'
          '${liveTrackingLink != null ? '\n🔴 LIVE TRACKING:\n$liveTrackingLink\n' : ''}\n'
          '⏰ Time: $timeStr\n'
          'Please call me back urgently!\n'
          'Call 112 if you cannot reach me!';
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
        await _confirmCancelWithoutAuth();
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
    } on PlatformException catch (e) {
      // No screen lock / nothing enrolled: authentication can never succeed, so
      // without this fallback the user could never cancel the SOS
      if (const ['NotAvailable', 'NotEnrolled', 'PasscodeNotSet'].contains(e.code)) {
        print('⚠️ Device authentication unavailable (${e.code}) - asking for confirmation');
        await _confirmCancelWithoutAuth();
        return;
      }
      print('❌ Authentication error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: ${e.message ?? e.code}'),
            backgroundColor: Colors.red,
          ),
        );
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

  /// Confirmation used when the device has no PIN/biometric to verify with
  Future<void> _confirmCancelWithoutAuth() async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('⚠️ Warning'),
        content: const Text(
          'This device has no screen lock or biometrics set up.\n\n'
          'Are you sure you want to cancel the emergency?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No, Keep Active'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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

  /// Cancel the emergency after successful authentication
  Future<void> _cancelEmergency() async {
    try {
      // The SOS never reached the server: nothing to end there
      if (_sosId == null && SOSService.getCurrentSosId() == null) {
        await LiveLocationService.instance.stopTracking();
        if (mounted) Navigator.pop(context);
        return;
      }

      final response = await SOSService.endSOS(reason: 'CANCELLED');
      if (!response.success) {
        // Keep the screen (and tracking) up so the user knows it is still active
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not end SOS: ${response.message ?? 'server error'}. It is still active.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Stop live location tracking only once the server confirmed
      await LiveLocationService.instance.stopTracking();
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _deliveryState.headline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        _deliveryState.subtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
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
                      _openMap(sosId);
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
                  _deliveryState == _SosDeliveryState.active
                      ? 'Live location tracking active'
                      : 'Live tracking starts once the SOS reaches the server',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_deliveryState == _SosDeliveryState.active) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Updates every 5 seconds',
                    style: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
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
                        _deliveryState.cardTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _contacts.isEmpty &&
                                _deliveryState != _SosDeliveryState.sending
                            ? 'You have no emergency contacts. Call 112 if you are in danger.'
                            : _deliveryState.cardBody,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      if (_deliveryState ==
                          _SosDeliveryState.serverUnreachable) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _retrySOS,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry sending SOS'),
                        ),
                      ],
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
