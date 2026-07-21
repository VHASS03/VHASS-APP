import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import 'sms_service.dart';
import 'storage_service.dart';

/// Live Location Service
/// Provides continuous real-time location tracking during SOS
/// Sends location updates to backend and emergency contacts
class LiveLocationService {
  static LiveLocationService? _instance;
  static LiveLocationService get instance => _instance ??= LiveLocationService._();
  
  LiveLocationService._();
  
  // Stream subscription for location updates
  StreamSubscription<Position>? _positionStream;
  
  // Timer for periodic SMS updates
  Timer? _smsUpdateTimer;
  
  // Current tracking state
  bool _isTracking = false;
  String? _currentSosId;
  Position? _lastKnownPosition;
  List<Position> _locationHistory = [];
  
  // Callbacks
  Function(Position)? onLocationUpdate;
  Function(String)? onError;
  
  // Configuration
  static const int _locationUpdateIntervalSeconds = 5;
  static const int _smsUpdateIntervalSeconds = 30; // Send SMS every 30 seconds
  static const int _distanceFilterMeters = 5; // Update every 5 meters moved
  
  /// Getters
  bool get isTracking => _isTracking;
  Position? get lastKnownPosition => _lastKnownPosition;
  List<Position> get locationHistory => List.unmodifiable(_locationHistory);
  
  /// Start continuous live location tracking
  Future<bool> startTracking({
    required String sosId,
    Function(Position)? onUpdate,
    Function(String)? onErrorCallback,
  }) async {
    if (_isTracking) {
      print('⚠️ [LiveLocation] Already tracking');
      return true;
    }
    
    _currentSosId = sosId;
    onLocationUpdate = onUpdate;
    onError = onErrorCallback;
    
    print('🗺️ [LiveLocation] Starting live location tracking for SOS: $sosId');
    
    // Check permissions
    final ready = await _ensureLocationReady();
    if (!ready) {
      print('❌ [LiveLocation] Location not ready');
      return false;
    }
    
    // Get initial location immediately
    await _getInitialLocation();
    
    // Start continuous tracking
    _startLocationStream();
    
    // Start periodic SMS updates
    _startPeriodicSMSUpdates();
    
    _isTracking = true;
    print('✅ [LiveLocation] Live tracking started');
    
    return true;
  }
  
  /// Stop tracking
  Future<void> stopTracking() async {
    print('🛑 [LiveLocation] Stopping live location tracking');
    
    _isTracking = false;
    
    // Cancel location stream
    await _positionStream?.cancel();
    _positionStream = null;
    
    // Cancel SMS timer
    _smsUpdateTimer?.cancel();
    _smsUpdateTimer = null;
    
    // Send final location
    if (_lastKnownPosition != null) {
      await _sendLocationToBackend(_lastKnownPosition!, isFinal: true);
    }
    
    // Clear state
    _currentSosId = null;
    _locationHistory.clear();
    onLocationUpdate = null;
    onError = null;
    
    print('✅ [LiveLocation] Tracking stopped');
  }
  
  /// Ensure location permissions and service are ready
  Future<bool> _ensureLocationReady() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onError?.call('Location services are disabled');
        return false;
      }
      
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        onError?.call('Location permission denied');
        return false;
      }
      
      return true;
    } catch (e) {
      onError?.call('Error checking location: $e');
      return false;
    }
  }
  
  /// Get initial location immediately
  Future<void> _getInitialLocation() async {
    try {
      print('📍 [LiveLocation] Getting initial location...');
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );
      
      _lastKnownPosition = position;
      _locationHistory.add(position);
      
      print('✅ [LiveLocation] Initial location: ${position.latitude}, ${position.longitude}');
      
      // Notify callback
      onLocationUpdate?.call(position);
      
      // Send to backend immediately
      await _sendLocationToBackend(position);
      
      // Send initial SMS with location
      await _sendLocationSMSToContacts(position, isInitial: true);
      
    } catch (e) {
      print('❌ [LiveLocation] Error getting initial location: $e');
      onError?.call('Could not get initial location: $e');
    }
  }
  
  /// Start continuous location stream
  void _startLocationStream() {
    print('🔄 [LiveLocation] Starting location stream...');
    
    _positionStream = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: _distanceFilterMeters,
        intervalDuration: Duration(seconds: _locationUpdateIntervalSeconds),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'VHASS Emergency',
          notificationText: 'Sharing your live location with emergency contacts',
          enableWakeLock: true,
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        ),
      ),
    ).listen(
      (Position position) {
        _handleLocationUpdate(position);
      },
      onError: (error) {
        print('❌ [LiveLocation] Stream error: $error');
        onError?.call('Location error: $error');
      },
    );
  }
  
  /// Handle each location update
  void _handleLocationUpdate(Position position) {
    print('📍 [LiveLocation] New position: ${position.latitude}, ${position.longitude} '
          '(accuracy: ${position.accuracy.toStringAsFixed(1)}m)');
    
    _lastKnownPosition = position;
    _locationHistory.add(position);
    
    // Notify callback
    onLocationUpdate?.call(position);
    
    // Send to backend
    _sendLocationToBackend(position);
  }
  
  /// Send location update to backend
  Future<void> _sendLocationToBackend(Position position, {bool isFinal = false}) async {
    if (_currentSosId == null) return;
    
    try {
      await ApiService.post('/sos/update-location', {
        'sosId': _currentSosId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': DateTime.now().toIso8601String(),
        'isFinal': isFinal,
      });
      
      print('✅ [LiveLocation] Location sent to backend');
    } catch (e) {
      print('❌ [LiveLocation] Failed to send location: $e');
    }
  }
  
  /// Start periodic SMS updates to contacts (every 30 seconds)
  void _startPeriodicSMSUpdates() {
    print('📱 [LiveLocation] Starting periodic SMS updates (every $_smsUpdateIntervalSeconds seconds)');
    
    _smsUpdateTimer = Timer.periodic(
      Duration(seconds: _smsUpdateIntervalSeconds),
      (timer) async {
        if (_lastKnownPosition != null && _isTracking) {
          await _sendLocationSMSToContacts(_lastKnownPosition!, isInitial: false);
        }
      },
    );
  }
  
  /// Send location SMS to all emergency contacts
  Future<void> _sendLocationSMSToContacts(Position position, {bool isInitial = false}) async {
    try {
      final userName = await StorageService.getUserName() ?? 'User';
      final contacts = await _getEmergencyContacts();
      
      if (contacts.isEmpty) {
        print('⚠️ [LiveLocation] No emergency contacts to send SMS');
        return;
      }
      
      final message = _createLocationSMSMessage(
        userName: userName,
        position: position,
        isInitial: isInitial,
      );

      print('📱 [LiveLocation] Sending ${isInitial ? "initial" : "update"} SMS to ${contacts.length} contacts');

      // Send all SMS concurrently for fastest delivery
      final smsFutures = contacts.map((contact) async {
        try {
          await SMSService.sendCustomSMS(contact['phone'] ?? '', message);
          print('✅ [LiveLocation] SMS sent to ${contact['name']}');
        } catch (e) {
          print('❌ [LiveLocation] SMS failed for ${contact['name']}: $e');
        }
      }).toList();

      await Future.wait(smsFutures);
    } catch (e) {
      print('❌ [LiveLocation] Error sending location SMS: $e');
    }
  }
  
  /// Create SMS message with LIVE tracking link
  String _createLocationSMSMessage({
    required String userName,
    required Position position,
    required bool isInitial,
  }) {
    final lat = position.latitude.toStringAsFixed(6);
    final lng = position.longitude.toStringAsFixed(6);
    final staticMapsLink = 'https://maps.google.com/?q=$lat,$lng';
    final time = DateTime.now();
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    
    // Create LIVE tracking link that continuously updates
    final liveTrackingLink = _currentSosId != null 
        ? 'https://vhass-backend-jfpr.onrender.com/track/$_currentSosId'
        : staticMapsLink;
    
    if (isInitial) {
      return '🚨 EMERGENCY ALERT 🚨\n'
          '$userName needs help!\n\n'
          '🔴 LIVE TRACKING LINK:\n'
          '$liveTrackingLink\n\n'
          '📍 Current Location:\n'
          '$staticMapsLink\n\n'
          '⏰ Time: $timeStr\n'
          '📏 Accuracy: ${position.accuracy.toStringAsFixed(0)}m\n\n'
          'Track LIVE location with link above!\n'
          'Call 112 if you cannot reach them!';
    } else {
      return '📍 LIVE LOCATION UPDATE\n'
          '$userName - Emergency active\n\n'
          '🔴 LIVE TRACKING:\n'
          '$liveTrackingLink\n\n'
          '📍 Current: $lat, $lng\n'
          '⏰ Updated: $timeStr';
    }
  }
  
  /// Get emergency contacts from storage/API
  Future<List<Map<String, String>>> _getEmergencyContacts() async {
    try {
      final response = await ApiService.get<List<dynamic>>(
        '/contacts',
        fromJson: (data) => data is List ? data : [],
      );
      
      if (response.success && response.data != null) {
        return (response.data as List).map((c) => {
          'name': (c['name'] ?? 'Contact') as String,
          'phone': (c['phone'] ?? '') as String,
        }).where((c) => c['phone']!.isNotEmpty).toList();
      }
      
      return [];
    } catch (e) {
      print('❌ [LiveLocation] Error getting contacts: $e');
      return [];
    }
  }
  
  /// Get Google Maps link for current location
  String? getGoogleMapsLink() {
    if (_lastKnownPosition == null) return null;
    
    final lat = _lastKnownPosition!.latitude.toStringAsFixed(6);
    final lng = _lastKnownPosition!.longitude.toStringAsFixed(6);
    return 'https://maps.google.com/?q=$lat,$lng';
  }
  
  /// Get live tracking URL (for sharing)
  String? getLiveTrackingUrl() {
    if (_currentSosId == null) return null;
    // This would be your backend URL for live tracking
    return 'https://vhass.app/track/$_currentSosId';
  }
  
  /// Manually trigger location update
  Future<Position?> forceLocationUpdate() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      
      _handleLocationUpdate(position);
      return position;
    } catch (e) {
      print('❌ [LiveLocation] Force update failed: $e');
      return null;
    }
  }
}

