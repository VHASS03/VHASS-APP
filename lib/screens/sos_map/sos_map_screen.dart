import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../core/services/sos_service.dart';
import '../../core/services/live_location_service.dart';

/// Real-time SOS Map Screen
/// Displays user's LIVE location with continuous tracking
/// Sends location updates to emergency contacts automatically
class SOSMapScreen extends StatefulWidget {
  final String sosId;

  const SOSMapScreen({super.key, required this.sosId});

  @override
  State<SOSMapScreen> createState() => _SOSMapScreenState();
}

class _SOSMapScreenState extends State<SOSMapScreen> {
  GoogleMapController? _mapController;
  final LiveLocationService _liveLocationService = LiveLocationService.instance;
  
  Position? _currentPosition;
  bool _isTracking = true;
  int _updateCount = 0;
  bool _hasReceivedFirstLocation = false;
  DateTime? _lastUpdateTime;
  String? _googleMapsLink;

  static const LatLng _fallbackPosition = LatLng(20.5937, 78.9629);

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _locationHistory = [];

  @override
  void initState() {
    super.initState();
    print(
      '🗺️ [SOSMapScreen] Initializing map screen for SOS: ${widget.sosId}',
    );
    _initializeLiveTracking();
  }

  /// Initialize live location tracking using LiveLocationService
  Future<void> _initializeLiveTracking() async {
    print('🗺️ [SOSMapScreen] Starting LIVE location tracking...');
    
    final success = await _liveLocationService.startTracking(
      sosId: widget.sosId,
      onUpdate: (Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
            _hasReceivedFirstLocation = true;
            _updateCount++;
            _lastUpdateTime = DateTime.now();
            _googleMapsLink = _liveLocationService.getGoogleMapsLink();
            _updateMarkerAndPolyline(position);
          });
        }
      },
      onErrorCallback: (String error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start live tracking. Check location permissions.'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      setState(() => _isTracking = true);
    }
  }

  /// REFACTORED: Update marker and polyline in separate method
  void _updateMarkerAndPolyline(Position position) {
    final latLng = LatLng(position.latitude, position.longitude);
    _locationHistory.add(latLng);

    // Update current location marker with EXACT pinpoint
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

    // Update polyline showing path taken
    if (_locationHistory.length > 1) {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _locationHistory,
          color: Colors.blue,
          width: 4,
          geodesic: true,
        ),
      );
    }

    // Animate camera to current position
    _animateCameraToPosition(latLng, position.heading);
    print('🗺️ [SOSMapScreen] Map state updated, update count: $_updateCount');
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
  
  /// Share location via other apps
  Future<void> _shareLocation() async {
    if (_googleMapsLink == null) return;
    
    try {
      final uri = Uri.parse('sms:?body=My emergency location: $_googleMapsLink');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      print('❌ Error sharing location: $e');
    }
  }
  
  /// Force refresh location
  Future<void> _forceRefreshLocation() async {
    final position = await _liveLocationService.forceLocationUpdate();
    if (position != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location refreshed'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  /// End SOS and return to home
  Future<void> _endSOS() async {
    try {
      // Stop live tracking first
      await _liveLocationService.stopTracking();
      
      // End SOS on backend
      await SOSService.endSOS(reason: 'User cancelled SOS');
      
      if (mounted) {
        setState(() => _isTracking = false);
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
    // Don't stop tracking on dispose - let it run in background
    // _liveLocationService.stopTracking(); // Only stop when user explicitly ends SOS
    _mapController?.dispose();
    super.dispose();
  }

  /// Get time since last update
  String _getTimeSinceUpdate() {
    if (_lastUpdateTime == null) return 'Never';
    final diff = DateTime.now().difference(_lastUpdateTime!);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LIVE Location Tracking'),
            Text(
              _isTracking ? '● Tracking Active' : '○ Tracking Stopped',
              style: TextStyle(
                fontSize: 12,
                color: _isTracking ? Colors.greenAccent : Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _forceRefreshLocation,
            tooltip: 'Refresh Location',
          ),
          // Share button
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _googleMapsLink != null ? _shareLocation : null,
            tooltip: 'Share Location',
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
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _isTracking ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isTracking ? Icons.gps_fixed : Icons.gps_off,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'LIVE Location',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Updated: ${_getTimeSinceUpdate()}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broadcast_on_personal,
                                size: 14,
                                color: Colors.red[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_updateCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Location details
                    if (_currentPosition != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildLocationInfo(
                              'Latitude',
                              _currentPosition!.latitude.toStringAsFixed(6),
                              Icons.north,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildLocationInfo(
                              'Longitude',
                              _currentPosition!.longitude.toStringAsFixed(6),
                              Icons.east,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildLocationInfo(
                              'Accuracy',
                              '${_currentPosition!.accuracy.toStringAsFixed(0)}m',
                              Icons.my_location,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildLocationInfo(
                              'Speed',
                              '${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h',
                              Icons.speed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Google Maps Link
                      if (_googleMapsLink != null)
                        InkWell(
                          onTap: () async {
                            final uri = Uri.parse(_googleMapsLink!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.map, size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Open in Google Maps',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.open_in_new,
                                  size: 14,
                                  color: Colors.blue[400],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ] else ...[
                      Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.orange[700]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Getting your location...',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
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
  
  /// Build location info widget
  Widget _buildLocationInfo(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
