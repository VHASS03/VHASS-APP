import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothService;
import '../../core/services/bluetooth_service.dart';

class SafetyDeviceScreen extends StatefulWidget {
  const SafetyDeviceScreen({super.key});
   
  @override
  State<SafetyDeviceScreen> createState() => _SafetyDeviceScreenState();
}

class _SafetyDeviceScreenState extends State<SafetyDeviceScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  bool _isScanning = false;
  bool _isBluetoothOn = false; // Used for UI state management
  List<ScanResult> _scanResults = [];
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    // Check if Bluetooth is on
    _isBluetoothOn = await _bluetoothService.isBluetoothOn();
    if (mounted) setState(() {});

    // Listen to scan results
    _bluetoothService.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results;
        });
      }
    });

    // Listen to connection state
    _bluetoothService.connectionState.listen((state) {
      if (mounted) {
        final wasConnected = _connectionState == BluetoothConnectionState.connected;
        setState(() {
          _connectionState = state;
        });
        // Show message when device disconnects unexpectedly (remote ended connection)
        if (wasConnected && state == BluetoothConnectionState.disconnected) {
          final reason = _bluetoothService.lastDisconnectReason;
          final msg = reason != null
              ? 'Device disconnected: ${reason.contains('REMOTE_USER') ? 'device ended the connection' : reason}'
              : 'Device disconnected';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Reconnect',
                textColor: Colors.white,
                onPressed: _startScan,
              ),
            ),
          );
        }
      }
    });

    // Check for existing connection
    if (_bluetoothService.isConnected) {
      setState(() {
        _connectionState = BluetoothConnectionState.connected;
      });
    }
  }

  Future<void> _startScan() async {
    try {
      setState(() => _isScanning = true);
      await _bluetoothService.startScan(timeout: const Duration(seconds: 20));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Scanning auto-stops after timeout
      Future.delayed(const Duration(seconds: 20), () {
        if (mounted) setState(() => _isScanning = false);
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device, {String? pin}) async {
    if (pin != null && pin.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If a pairing dialog appears, enter the same PIN there (numbers or letters, e.g. 0000 or ABC12).',
          ),
          duration: Duration(seconds: 4),
          backgroundColor: Color(0xFF9146FF),
        ),
      );
    }
    try {
      await _bluetoothService.connectToDevice(device, pin: pin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connected to ${device.platformName.isNotEmpty ? device.platformName : "device"}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to connect: ${e.toString().replaceAll(RegExp(r'^Exception:?\s*'), '')}',
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _showConnectDialog(device, device.platformName.isNotEmpty ? device.platformName : 'Unknown Device'),
            ),
          ),
        );
      }
    }
  }

  void _showConnectDialog(BluetoothDevice device, String deviceName) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connect to device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deviceName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Does this device require a PIN or passkey to pair?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _connectToDevice(device);
            },
            child: const Text('Connect'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showPinDialog(device, deviceName);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF9146FF)),
            child: const Text('Connect with PIN'),
          ),
        ],
      ),
    );
  }

  void _showPinDialog(BluetoothDevice device, String deviceName) {
    final pinController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter pairing PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deviceName,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.visiblePassword,
              maxLength: 16,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'PIN / Passkey',
                hintText: 'e.g. 0000, 1234, or ABC12',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final pin = pinController.text.trim();
              Navigator.pop(ctx);
              _connectToDevice(device, pin: pin.isNotEmpty ? pin : null);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF9146FF)),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnectDevice() async {
    await _bluetoothService.disconnectDevice();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device disconnected'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _bluetoothService.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: theme.cardColor,
              shape: const CircleBorder(),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Safety Device",
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              _connectionState == BluetoothConnectionState.connected
                  ? "Connected"
                  : "Not connected",
              style: TextStyle(
                color: _connectionState == BluetoothConnectionState.connected
                    ? Colors.green
                    : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          if (_bluetoothService.isConnected)
            IconButton(
              icon: const Icon(Icons.bluetooth_connected, color: Colors.green),
              onPressed: _disconnectDevice,
            ),
        ],
      ),
      body: Column(
        children: [
          // Bluetooth Off Warning
          if (!_isBluetoothOn)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_disabled, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'BLE/Bluetooth is off. Please enable it to scan for devices.',
                      style: TextStyle(color: Colors.orange[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          
          // Info Banner about SOS Button
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF9146FF).withOpacity(0.1),
                  const Color(0xFF6A1B9A).withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF9146FF).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9146FF).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emergency,
                    color: Color(0xFF9146FF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SOS Button Device',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Connect a BLE or Bluetooth SOS button. When pressed, it will automatically trigger emergency alerts.',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Connected Device Banner
          if (_bluetoothService.isConnected)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Device Connected",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _bluetoothService.connectedDevice?.platformName ??
                              'Unknown',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _disconnectDevice,
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
            ),

          // Scan Button
          if (!_bluetoothService.isConnected)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startScan,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.bluetooth_searching),
                  label: Text(_isScanning ? 'Scanning...' : 'Scan for BLE/Bluetooth Devices'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9146FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

          // Device List
          Expanded(
            child: _scanResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth,
                          size: 80,
                          color: Colors.grey.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning
                              ? 'Searching for BLE/Bluetooth devices...'
                              : 'No BLE/Bluetooth devices found\nTap "Scan" to search',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _scanResults.length,
                    itemBuilder: (context, index) {
                      final result = _scanResults[index];
                      final device = result.device;
                      final rssi = result.rssi;
                      final advName = result.advertisementData.advName;
                      
                      // Get the best available name
                      final deviceName = device.platformName.isNotEmpty 
                          ? device.platformName 
                          : (advName.isNotEmpty ? advName : 'Unknown Device');
                      
                      // Check if this looks like an SOS device
                      final nameLower = deviceName.toLowerCase();
                      final isSosDevice = nameLower.contains('sos') ||
                          nameLower.contains('button') ||
                          nameLower.contains('safety') ||
                          nameLower.contains('panic') ||
                          nameLower.contains('emergency');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isSosDevice 
                            ? const Color(0xFF9146FF).withOpacity(0.1)
                            : null,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSosDevice
                                ? const Color(0xFF9146FF).withOpacity(0.3)
                                : const Color(0xFF9146FF).withOpacity(0.2),
                            child: Icon(
                              isSosDevice ? Icons.emergency : Icons.bluetooth,
                              color: isSosDevice 
                                  ? Colors.red 
                                  : const Color(0xFF9146FF),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  deviceName,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isSosDevice)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'SOS',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.remoteId.toString(),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.signal_cellular_alt,
                                    size: 12,
                                    color: _getSignalColor(rssi),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Signal: $rssi dBm',
                                    style: TextStyle(
                                      color: _getSignalColor(rssi),
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (isSosDevice) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.verified,
                                      size: 12,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 2),
                                    const Text(
                                      'Recommended',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _showConnectDialog(device, device.platformName.isNotEmpty ? device.platformName : (result.advertisementData.advName.isNotEmpty ? result.advertisementData.advName : 'Unknown Device')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSosDevice 
                                  ? Colors.red 
                                  : const Color(0xFF9146FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Connect'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getSignalColor(int rssi) {
    if (rssi > -60) return Colors.green;
    if (rssi > -80) return Colors.orange;
    return Colors.red;
  }
}
