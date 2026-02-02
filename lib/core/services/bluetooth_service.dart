import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:permission_handler/permission_handler.dart';

/// Service to manage Bluetooth connectivity for safety devices
class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  fb.BluetoothDevice? _connectedDevice;
  fb.BluetoothCharacteristic? _sosCharacteristic;

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
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
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

      // Start scanning
      await fb.FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );

      // Listen to scan results
      fb.FlutterBluePlus.scanResults.listen((results) {
        // Filter for safety devices (you can customize the filter)
        final filteredResults = results.where((result) {
          final name = result.device.platformName.toLowerCase();
          // Add your device name patterns here
          return name.isNotEmpty &&
              (name.contains('vhass') ||
                  name.contains('safety') ||
                  name.contains('sos') ||
                  name.contains('button'));
        }).toList();

        _scanResultsController.add(filteredResults);
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await fb.FlutterBluePlus.stopScan();
  }

  /// Connect to a Bluetooth device
  Future<void> connectToDevice(fb.BluetoothDevice device) async {
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

      // Listen to connection state changes
      device.connectionState.listen((state) {
        _connectionStateController.add(state);
        if (state == fb.BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _sosCharacteristic = null;
        }
      });

      // Discover services and characteristics
      await _discoverServices(device);
    } catch (e) {
      _connectedDevice = null;
      rethrow;
    }
  }

  /// Discover services and find SOS trigger characteristic
  Future<void> _discoverServices(fb.BluetoothDevice device) async {
    try {
      List<fb.BluetoothService> services = await device.discoverServices();

      // Look for the SOS trigger characteristic
      // This is a placeholder - replace with your device's actual service/characteristic UUIDs
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          // Check if this characteristic can notify (for button press)
          if (characteristic.properties.notify ||
              characteristic.properties.indicate) {
            _sosCharacteristic = characteristic;

            // Subscribe to notifications
            await characteristic.setNotifyValue(true);

            // Listen for SOS trigger
            characteristic.lastValueStream.listen((value) {
              if (value.isNotEmpty) {
                _handleSOSTrigger(value);
              }
            });
          }
        }
      }
    } catch (e) {
      // Service discovery failed
    }
  }

  /// Handle SOS trigger from Bluetooth device
  void _handleSOSTrigger(List<int> value) {
    // This is where you'd trigger the SOS alert
    // You can emit this through a stream or callback
    // For example: if (value[0] == 1) { triggerSOS(); }
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
    disconnectDevice();
  }
}
