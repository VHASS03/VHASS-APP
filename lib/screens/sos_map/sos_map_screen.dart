import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import '../../core/services/sos_service.dart';
import '../../core/services/api_service.dart';

/// Real-time SOS Map Screen
/// Displays user's live location and sends updates to emergency contacts
class SOSMapScreen extends StatefulWidget {
  final String sosId;

  const SOSMapScreen({super.key, required this.sosId});

  @override
  State<SOSMapScreen> createState() => _SOSMapScreenState();
}

class _SOSMapScreenState extends State<SOSMapScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStream;
  Timer? _periodicLocationTimer; // Timer for stationary user refresh
  Position? _currentPosition;
  final bool _isTracking = true;
  int _updateCount = 0;
  bool _isSending = false;
  bool _hasReceivedFirstLocation = false; // NEW: Track first location

  static const LatLng _fallbackPosition = LatLng(20.5937, 78.9629);
  static const Duration _periodicRefreshInterval = Duration(seconds: 10); // Refresh location every 10s for stationary users

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _locationHistory = [];
  final List<LatLng> _routePoints = []; // Points for polyline (50m+ apart)
  LatLng? _lastRoutePoint; // Last point added to route
  static const double _minRouteDistanceMeters = 50.0; // Minimum distance for route points

  @override
  void initState() {
    super.initState();
    print(
      '🗺️ [SOSMapScreen] Initializing map screen for SOS: ${widget.sosId}',
    );
    _initializeTracking();
  }

  /// Ensure location service and permission are granted before starting stream
  Future<void> _initializeTracking() async {
    print('🗺️ [SOSMapScreen] _initializeTracking called');
    final ready = await _ensureLocationReady();
    print('🗺️ [SOSMapScreen] Location ready: $ready');
    if (!ready || !mounted) {
      print('🗺️ [SOSMapScreen] Not ready or not mounted, aborting');
      return;
    }
    print('🗺️ [SOSMapScreen] Starting location tracking...');

    // CHANGED: Get first location immediately before starting stream
    try {
      final Position firstPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _currentPosition = firstPosition;
          _hasReceivedFirstLocation = true;
          _updateCount++;
          _updateMarkerAndPolyline(firstPosition);
        });
        print(
          '✅ First location received immediately: ${firstPosition.latitude}, ${firstPosition.longitude}',
        );
      }
    } catch (e) {
      print('⚠️ Could not get first location: $e');
    }

    _startLocationTracking();
    _startPeriodicLocationRefresh(); // Start periodic refresh for stationary users
  }

  Future<bool> _ensureLocationReady() async {
    print('🗺️ [SOSMapScreen] Checking location service enabled...');
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    print('🗺️ [SOSMapScreen] Location service enabled: $serviceEnabled');
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enable location services to view the map'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    print('🗺️ [SOSMapScreen] Checking location permission...');
    var permission = await Geolocator.checkPermission();
    print('🗺️ [SOSMapScreen] Current permission: $permission');
    if (permission == LocationPermission.denied) {
      print('🗺️ [SOSMapScreen] Requesting location permission...');
      permission = await Geolocator.requestPermission();
      print('🗺️ [SOSMapScreen] Permission after request: $permission');
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print('🗺️ [SOSMapScreen] Permission denied, showing error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to show the map'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    print('🗺️ [SOSMapScreen] Location is ready');
    return true;
  }

  /// Calculate distance between two coordinates using Haversine formula
  double _calculateDistanceMeters(LatLng from, LatLng to) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double lat1Rad = from.latitude * pi / 180;
    final double lat2Rad = to.latitude * pi / 180;
    final double deltaLat = (to.latitude - from.latitude) * pi / 180;
    final double deltaLng = (to.longitude - from.longitude) * pi / 180;

    final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLng / 2) * sin(deltaLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// REFACTORED: Update marker and polyline in separate method
  void _updateMarkerAndPolyline(Position position) {
    final latLng = LatLng(position.latitude, position.longitude);
    _locationHistory.add(latLng);

    // Add to route points only if moved more than 50 meters from last route point
    if (_lastRoutePoint == null) {
      // First point - always add
      _routePoints.add(latLng);
      _lastRoutePoint = latLng;
      print('📍 [Route] Added first route point: $latLng');
    } else {
      final distance = _calculateDistanceMeters(_lastRoutePoint!, latLng);
      if (distance >= _minRouteDistanceMeters) {
        _routePoints.add(latLng);
        _lastRoutePoint = latLng;
        print('📍 [Route] Added route point (moved ${distance.toStringAsFixed(1)}m): $latLng');
      } else {
        print('📍 [Route] Skipped point (only ${distance.toStringAsFixed(1)}m from last)');
      }
    }

    // Update current location marker with EXACT pinpoint (ALWAYS shows current position)
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: latLng,
        infoWindow: InfoWindow(
          title: 'EMERGENCY - Current Location',
          snippet:
              'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}',
          onTap: () {
            print('📍 Tapped location: $latLng');
          },
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed, // Red pin for emergency
        ),
      ),
    );

    // Add markers for each route point (50m+ apart)
    // Start point gets green marker, intermediate waypoints get blue markers
    for (int i = 0; i < _routePoints.length; i++) {
      // Skip the last point if it's the current location (already marked in red)
      if (i == _routePoints.length - 1 && _routePoints[i] == latLng) continue;
      
      _markers.add(
        Marker(
          markerId: MarkerId('route_point_$i'),
          position: _routePoints[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(
            i == 0 ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueBlue, // Green for start, blue for waypoints
          ),
          infoWindow: InfoWindow(
            title: i == 0 ? 'Start Point' : 'Waypoint ${i}',
            snippet: 'Lat: ${_routePoints[i].latitude.toStringAsFixed(6)}, Lng: ${_routePoints[i].longitude.toStringAsFixed(6)}',
          ),
        ),
      );
    }

    // Update polyline showing path taken (only route points 50m+ apart)
    if (_routePoints.length > 1) {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: Colors.blue,
          width: 4,
          geodesic: true,
        ),
      );
    }

    // Animate camera to current position (ALWAYS follows user)
    _animateCameraToPosition(latLng, position.heading);
    print('🗺️ [SOSMapScreen] Map state updated, update count: $_updateCount, route points: ${_routePoints.length}');
  }

  /// Start real-time location tracking
  void _startLocationTracking() {
    try {
      print('🗺️ [SOSMapScreen] Creating position stream...');
      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: AndroidSettings(
              accuracy: LocationAccuracy.high, // Use high instead of best for faster updates
              distanceFilter: 5, // Update every 5 meters for more responsive tracking
              forceLocationManager: false,
              intervalDuration: const Duration(seconds: 2), // Request updates every 2 seconds
            ),
          ).listen(
            (Position position) {
              print(
                '🗺️ [SOSMapScreen] Position received: ${position.latitude}, ${position.longitude}',
              );
              if (mounted) {
                setState(() {
                  _currentPosition = position;
                  _hasReceivedFirstLocation = true;
                  _updateCount++;
                  _updateMarkerAndPolyline(position);
                });
                _sendLocationUpdate(position);
              }
            },
            onError: (error) {
              print(
                '🗺️ [SOSMapScreen] CRITICAL Location stream error: $error',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Location error: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          );
    } catch (e) {
      print('🗺️ [SOSMapScreen] CRITICAL Location tracking setup error: $e');
    }
  }

  /// Animate camera to position
  void _animateCameraToPosition(LatLng position, double heading) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 17,
          bearing: heading >= 0 ? heading : 0,
          tilt: 30,
        ),
      ),
    );
  }

  /// Send location update to backend
  Future<void> _sendLocationUpdate(Position position) async {
    if (_isSending || !_isTracking) return;

    setState(() => _isSending = true);

    try {
      await ApiService.post('/sos/update-location', {
        'sosId': widget.sosId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
      });

      print('✅ Location update sent');
    } catch (e) {
      print('❌ Location update failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send location: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  /// End SOS and return to home
  Future<void> _endSOS() async {
    try {
      await SOSService.endSOS(reason: 'User cancelled SOS');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS ended successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end SOS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _periodicLocationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  /// Start periodic location refresh for stationary users
  void _startPeriodicLocationRefresh() {
    _periodicLocationTimer = Timer.periodic(_periodicRefreshInterval, (timer) async {
      if (!mounted || !_isTracking) {
        timer.cancel();
        return;
      }
      
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        
        if (mounted && _isTracking) {
          // Only update if position changed significantly (>2m) or hasn't updated in a while
          if (_currentPosition == null || 
              Geolocator.distanceBetween(
                _currentPosition!.latitude, _currentPosition!.longitude,
                position.latitude, position.longitude
              ) > 2) {
            setState(() {
              _currentPosition = position;
              _updateCount++;
              _updateMarkerAndPolyline(position);
            });
            _sendLocationUpdate(position);
            print('📍 [Periodic] Location refreshed: ${position.latitude}, ${position.longitude}');
          }
        }
      } catch (e) {
        print('⚠️ [Periodic] Location refresh failed: $e');
      }
    });
  }

  /// Manually refresh location (called from refresh button)
  Future<void> _manualRefreshLocation() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refreshing location...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _updateCount++;
          _updateMarkerAndPolyline(position);
        });
        _sendLocationUpdate(position);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Location Tracking'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Manual refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Location',
            onPressed: _manualRefreshLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map - CHANGED: Show map immediately
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    )
                  : _fallbackPosition,
              zoom: 17,
            ),
            onMapCreated: (controller) {
              print('🗺️ [SOSMapScreen] GoogleMap created successfully');
              _mapController = controller;
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: _currentPosition != null,
            myLocationButtonEnabled: _currentPosition != null,
            zoomControlsEnabled: true,
            mapType: MapType.normal,
            compassEnabled: true,
            onCameraMoveStarted: () {
              print('🗺️ [SOSMapScreen] Camera move started');
            },
          ),

          // CHANGED: Only show loading if NO location received yet
          if (!_hasReceivedFirstLocation)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  const Text('Getting exact location...'),
                ],
              ),
            ),

          // Info Card - Location Details
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Live Location',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Updates: $_updateCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // CHANGED: Show location details only when available
                    if (_currentPosition != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.notes, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.my_location, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Accuracy: ${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      if (_isSending)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Sending location...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.primary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ] else ...[
                      Text(
                        'Waiting for location fix...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // End SOS Button
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isTracking ? _endSOS : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.red.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'End SOS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
