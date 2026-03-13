import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:permission_handler/permission_handler.dart';
import 'sos_service.dart';

/// Callback type for SOS trigger events
typedef SOSTriggeredCallback = void Function();

/// Service to manage Bluetooth connectivity for safety devices
class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  fb.BluetoothDevice? _connectedDevice;
  // ignore: unused_field - kept for future SOS characteristic identification
  fb.BluetoothCharacteristic? _sosCharacteristic;
  
  /// Callback to be triggered when SOS button is pressed on connected device
  SOSTriggeredCallback? onSOSTriggered;
  
  /// Stream controller for SOS trigger events
  final StreamController<bool> _sosTriggeredController =
      StreamController<bool>.broadcast();
  
  /// Stream for SOS trigger events - listen to this to react to SOS button presses
  Stream<bool> get sosTriggered => _sosTriggeredController.stream;

  final StreamController<List<fb.ScanResult>> _scanResultsController =
      StreamController<List<fb.ScanResult>>.broadcast();
  final StreamController<fb.BluetoothConnectionState>
  _connectionStateController =
      StreamController<fb.BluetoothConnectionState>.broadcast();

  Stream<List<fb.ScanResult>> get scanResults => _scanResultsController.stream;
  Stream<fb.BluetoothConnectionState> get connectionState =>
      _connectionStateController.stream;

  fb.BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;

  /// Last disconnect reason (set when device disconnects; e.g. "REMOTE_USER_TERMINATED_CONNECTION")
  String? get lastDisconnectReason => _lastDisconnectReason;
  String? _lastDisconnectReason;

  /// Check and request Bluetooth permissions
  Future<bool> checkPermissions() async {
    if (await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted) {
      return true;
    }

    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location, // Required for Bluetooth scanning on Android
    ].request();

    return statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true;
  }

  /// Check if Bluetooth is turned on
  Future<bool> isBluetoothOn() async {
    try {
      return await fb.FlutterBluePlus.isOn;
    } catch (e) {
      return false;
    }
  }

  /// Turn on Bluetooth (Android only)
  Future<void> turnOnBluetooth() async {
    try {
      await fb.FlutterBluePlus.turnOn();
    } catch (e) {
      // On iOS, this will throw - user must enable manually
      throw Exception('Please enable Bluetooth in Settings');
    }
  }

  /// Start scanning for nearby Bluetooth devices
  /// Now scans ALL devices - no filtering applied
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
    bool showAllDevices = true,
  }) async {
    try {
      // Check permissions first
      if (!await checkPermissions()) {
        throw Exception('Bluetooth permissions not granted');
      }

      // Check if Bluetooth is on
      if (!await isBluetoothOn()) {
        throw Exception('Bluetooth is turned off');
      }

      // Stop any ongoing scan
      await fb.FlutterBluePlus.stopScan();

      print('🔍 Starting Bluetooth scan for ${showAllDevices ? "ALL" : "filtered"} devices...');

      // Start scanning
      await fb.FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );

      // Listen to scan results - show ALL devices (including those with no name)
      fb.FlutterBluePlus.scanResults.listen((results) {
        List<fb.ScanResult> deviceResults;
        
        if (showAllDevices) {
          // Show ALL devices - do not filter by name (many BLE devices don't advertise name)
          final byId = <String, fb.ScanResult>{};
          for (final r in results) {
            final id = r.device.remoteId.toString();
            // Keep the result with strongest signal per device
            if (!byId.containsKey(id) || (r.rssi > (byId[id]!.rssi))) {
              byId[id] = r;
            }
          }
          deviceResults = byId.values.toList();
          // Sort by signal strength (strongest first)
          deviceResults.sort((a, b) => b.rssi.compareTo(a.rssi));
          
          print('📱 Found ${deviceResults.length} BLE/Bluetooth devices');
        } else {
          // Legacy filtered mode - only safety devices
          deviceResults = results.where((result) {
            final name = result.device.platformName.toLowerCase();
            final advName = result.advertisementData.advName.toLowerCase();
            return (name.isNotEmpty || advName.isNotEmpty) &&
                (name.contains('vhass') ||
                    name.contains('safety') ||
                    name.contains('sos') ||
                    name.contains('button') ||
                    advName.contains('vhass') ||
                    advName.contains('safety') ||
                    advName.contains('sos') ||
                    advName.contains('button'));
          }).toList();
        }

        _scanResultsController.add(deviceResults);
      });
    } catch (e) {
      print('❌ Bluetooth scan error: $e');
      rethrow;
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await fb.FlutterBluePlus.stopScan();
  }

  /// Connect to a Bluetooth device.
  /// [pin] Optional PIN/passkey for devices that require pairing (e.g. "0000", "1234").
  /// If a system pairing dialog appears, enter the PIN there; we do not call createBond()
  /// here because many BLE devices reject it and then disconnect.
  Future<void> connectToDevice(fb.BluetoothDevice device, {String? pin}) async {
    try {
      // Disconnect from any existing device
      if (_connectedDevice != null) {
        await disconnectDevice();
      }

      // Connect to the new device
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _connectedDevice = device;

      // Do NOT call createBond(pin) here - many BLE devices don't support it or reject it
      // and then disconnect (REMOTE_USER_TERMINATED). User should enter PIN in the system
      // pairing dialog when it appears.

      // Listen to connection state changes
      device.connectionState.listen((state) {
        _connectionStateController.add(state);
        if (state == fb.BluetoothConnectionState.disconnected) {
          final reason = device.disconnectReason;
          if (reason != null) {
            _lastDisconnectReason = '${reason.description} (${reason.code})';
            print('📴 [Bluetooth] Device disconnected: ${reason.code} - ${reason.description}');
          } else {
            _lastDisconnectReason = null;
          }
          _connectedDevice = null;
          _sosCharacteristic = null;
        }
      });

      // Short delay so the device can stabilize after connection (reduces disconnect on some peripherals)
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Discover services and characteristics
      await _discoverServices(device);
    } catch (e) {
      _connectedDevice = null;
      rethrow;
    }
  }

  /// Discover services and find SOS trigger characteristic.
  /// Only subscribes to custom (vendor) notify/indicate characteristics to avoid
  /// triggering disconnects on devices that dislike subscription to standard GATT chars (e.g. 0x2a05).
  Future<void> _discoverServices(fb.BluetoothDevice device) async {
    try {
      print('🔍 [Bluetooth] Discovering services for ${device.platformName}...');
      List<fb.BluetoothService> services = await device.discoverServices();
      
      print('📋 [Bluetooth] Found ${services.length} services');

      // Bluetooth SIG base UUID suffix - standard characteristics use this; skip them to avoid device disconnecting.
      // Plugin may return full UUID (....-00805f9b34fb) or short form (2a05, 00002a05) - treat all as standard.
      const bluetoothSigSuffix = '-0000-1000-8000-00805f9b34fb';
      final shortStandardUuid = RegExp(r'^[0-9a-f]{4}$'); // e.g. 2a05, 1800
      final shortStandardUuid8 = RegExp(r'^[0-9a-f]{8}$'); // e.g. 00002a05
      final fullStandardUuid = RegExp(r'^[0-9a-f]{8}-0000-1000-8000-00805f9b34fb$');
      int subscribedCount = 0;
      
      bool isStandardCharacteristic(String s) {
        final lower = s.toLowerCase().trim();
        return lower.endsWith(bluetoothSigSuffix) ||
            shortStandardUuid.hasMatch(lower) ||
            shortStandardUuid8.hasMatch(lower) ||
            fullStandardUuid.hasMatch(lower);
      }
      
      for (var service in services) {
        print('  📦 Service: ${service.uuid}');
        
        for (var characteristic in service.characteristics) {
          final uuidStr = characteristic.uuid.toString();
          final isStandardUuid = isStandardCharacteristic(uuidStr);
          
          print('    📝 Characteristic: ${characteristic.uuid}'
              '${isStandardUuid ? " (standard, skip subscribe)" : ""}');
          print('       Properties: notify=${characteristic.properties.notify}, '
                'indicate=${characteristic.properties.indicate}, '
                'read=${characteristic.properties.read}');
          
          // Only subscribe to custom (vendor) notify/indicate characteristics.
          if ((characteristic.properties.notify || characteristic.properties.indicate) &&
              !isStandardUuid) {
            try {
              _sosCharacteristic = characteristic;

              await characteristic.setNotifyValue(true);
              subscribedCount++;
              
              print('       ✅ Subscribed to notifications');

              characteristic.lastValueStream.listen((value) {
                print('🔔 [Bluetooth] Received data from characteristic: $value');
                if (value.isNotEmpty) {
                  _handleSOSTrigger(value);
                }
              });
            } catch (e) {
              print('       ⚠️ Failed to subscribe: $e');
            }
          }
        }
      }
      
      print('✅ [Bluetooth] Service discovery complete. Subscribed to $subscribedCount characteristics.');
      
      // Request connection priority AFTER subscribing (some devices disconnect if we change params too early)
      if (Platform.isAndroid && subscribedCount > 0) {
        try {
          await device.requestConnectionPriority(
            connectionPriorityRequest: fb.ConnectionPriority.high,
          );
          print('📶 [Bluetooth] Connection priority set to high');
        } catch (e) {
          print('⚠️ [Bluetooth] Could not set connection priority: $e');
        }
      }
      
      if (subscribedCount == 0) {
        print('⚠️ [Bluetooth] Warning: No notifiable custom characteristics found. '
              'SOS button may not work with this device.');
      }
    } catch (e) {
      print('❌ [Bluetooth] Service discovery failed: $e');
    }
  }

  /// Handle SOS trigger from Bluetooth device
  /// This is called when the connected device sends a notification (button press)
  void _handleSOSTrigger(List<int> value) async {
    print('🚨 [Bluetooth] SOS trigger received from device! Value: $value');
    
    // Most SOS buttons send a non-empty value or specific byte when pressed
    // Common patterns: [1], [0x01], or any non-zero first byte
    bool shouldTrigger = false;
    
    if (value.isNotEmpty) {
      // Trigger on any non-zero value or any data received
      // Different devices may send different values
      shouldTrigger = true;
      print('🚨 [Bluetooth] Button press detected - triggering SOS!');
    }
    
    if (shouldTrigger) {
      // Emit event through stream
      _sosTriggeredController.add(true);
      
      // Call the callback if set
      if (onSOSTriggered != null) {
        onSOSTriggered!();
      }
      
      // Directly trigger SOS using the SOS service
      try {
        print('🚨 [Bluetooth] Calling SOSService.triggerSOS()...');
        final result = await SOSService.triggerSOS();
        
        if (result.success) {
          print('✅ [Bluetooth] SOS triggered successfully via Bluetooth device');
        } else {
          print('❌ [Bluetooth] SOS trigger failed: ${result.message}');
        }
      } catch (e) {
        print('❌ [Bluetooth] Error triggering SOS: $e');
      }
    }
  }

  /// Disconnect from current device
  Future<void> disconnectDevice() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        // Already disconnected
      }
      _connectedDevice = null;
      _sosCharacteristic = null;
    }
  }

  /// Get list of previously paired/bonded devices
  Future<List<fb.BluetoothDevice>> getBondedDevices() async {
    try {
      return await fb.FlutterBluePlus.bondedDevices;
    } catch (e) {
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    _scanResultsController.close();
    _connectionStateController.close();
    _sosTriggeredController.close();
    disconnectDevice();
  }
  
  /// Set the callback for SOS trigger events
  void setSOSCallback(SOSTriggeredCallback callback) {
    onSOSTriggered = callback;
    print('✅ [Bluetooth] SOS callback registered');
  }
  
  /// Test SOS trigger (for debugging)
  void testSOSTrigger() {
    print('🧪 [Bluetooth] Testing SOS trigger...');
    _handleSOSTrigger([1]);
  }
}
