import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:permission_handler/permission_handler.dart';
import 'sos_service.dart';

/// Callback type for SOS trigger events
typedef SOSTriggeredCallback = void Function();

/// Service to manage Bluetooth connectivity for safety devices
///
/// Note: This uses **FlutterBluePlus**, not the Minew native SDK. Minew beacons need
/// `MinewBeaconPlusChannel` + `MTBeaconPlus.aar` per the Minew Android guide.
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

  /// Must cancel when starting a new scan or stopping — avoids duplicate listeners and BLE churn.
  StreamSubscription<List<fb.ScanResult>>? _flutterScanSubscription;

  /// One subscription per connected device — cancel before reconnecting.
  StreamSubscription<fb.BluetoothConnectionState>? _deviceConnectionSubscription;

  /// Prevents overlapping connects (double-tap / dialog + list) — causes "already connected" + double discover.
  bool _connectInFlight = false;

  /// Notify value stream subs — cancel on disconnect so we don't stack listeners.
  final List<StreamSubscription<List<int>>> _notifySubscriptions = [];

  /// Characteristics we already attached SOS listener to (avoid duplicates after re-discover).
  final Set<String> _subscribedNotifyKeys = {};

  Stream<List<fb.ScanResult>> get scanResults => _scanResultsController.stream;
  Stream<fb.BluetoothConnectionState> get connectionState =>
      _connectionStateController.stream;

  fb.BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;

  /// Last disconnect reason (set when device disconnects; e.g. "REMOTE_USER_TERMINATED_CONNECTION")
  String? get lastDisconnectReason => _lastDisconnectReason;
  String? _lastDisconnectReason;

  /// If true, requests high connection priority after notify subscribe (helps some phones;
  /// **many** cheap BLE devices disconnect on this — default false).
  static bool requestHighConnectionPriority = false;

  /// Pause after [discoverServices] before writing CCC (notify). Your log shows disconnect
  /// right after `onConnectionUpdated(... timeout=400)` following notify — many firmwares
  /// need the link stable before subscriptions (Realme/Oppo stacks are aggressive here).
  static Duration stabilizationDelayBeforeNotify = const Duration(milliseconds: 1800);

  /// If true, ask Android for **balanced** connection params after connect (before discover).
  /// **Default false:** VHASS safety watch + Realme/Oppo often get `timeout=400` then `REMOTE_USER`
  /// after balanced + notify. Set **true** if another peripheral needs a nudge for stable discovery.
  static bool requestBalancedConnectionPriority = false;

  /// GATT **read** before `setNotifyValue` on vendor characteristics.
  /// **Default true:** VHASS watch often sends an **empty** first notify without a prior read,
  /// and a **filled** 16-byte frame after read. Set **false** if read+CCC causes earlier disconnect.
  static bool readCharacteristicBeforeVendorNotify = true;

  /// After subscribing to vendor notify(s), request **low-power** connection priority (Android only).
  /// **Default false:** logs showed `interval=90` after this call, then stack moved to `interval=38 timeout=400`
  /// and the watch still issued `REMOTE_USER` — the extra param negotiation may worsen drops. Set **true** to A/B.
  static bool requestLowConnectionPriorityAfterVendorNotify = false;

  /// Set false only to test whether **notify** is what triggers REMOTE_USER_TERMINATED on your hardware.
  static bool enableVendorNotifySubscription = true;

  /// After enabling notify, firmware often pushes a **state/telemetry** blob immediately — not a button press.
  static Duration bleSosPostSubscribeGrace = const Duration(seconds: 3);

  /// Only treat notifies with length **≤** this as possible SOS. (Your device sends **16-byte** telemetry on
  /// `7f280002`; that must not call `/sos/trigger`. Increase if your hardware uses longer button packets.)
  static int bleSosMaxNotifyPayloadLength = 8;

  /// Minimum time between BLE-driven `SOSService.triggerSOS()` calls (reduces 409 / link stress).
  static Duration bleSosMinTriggerInterval = const Duration(seconds: 45);

  DateTime? _bleSosIgnoreUntil;
  DateTime? _lastBleSosTriggerTime;

  // --- Session diagnostics (REMOTE_USER / disconnect “reason” evidence) ---
  DateTime? _diagGattUpAt;
  DateTime? _diagDiscoverCompleteAt;
  DateTime? _diagFirstVendorCccAt;
  /// Every `lastValueStream` emission (including **empty** payload after CCC).
  int _diagNotifyCallbackCount = 0;
  /// Subset with `value.isNotEmpty` (SOS / telemetry logic).
  int _diagNotifyNonEmptyCount = 0;
  DateTime? _diagLastNotifyAt;

  /// Baseline for detecting **changed** long vendor frames (e.g. button alters 16-byte blob).
  List<int>? _lastLongVendorNotifyPayload;

  void _resetBleDiagnosticsSession() {
    _diagGattUpAt = null;
    _diagDiscoverCompleteAt = null;
    _diagFirstVendorCccAt = null;
    _diagNotifyCallbackCount = 0;
    _diagNotifyNonEmptyCount = 0;
    _diagLastNotifyAt = null;
    _lastLongVendorNotifyPayload = null;
  }

  void _logIfLongVendorPayloadChanged(List<int> value) {
    if (value.length <= bleSosMaxNotifyPayloadLength) {
      return;
    }
    final prev = _lastLongVendorNotifyPayload;
    if (prev != null && !listEquals(prev, value)) {
      print(
        '🔘 [Bluetooth] Long vendor notify payload **changed** (${value.length} bytes) — '
        'if timing matches a button press, the event may be inside this frame (not a short packet).',
      );
    }
    _lastLongVendorNotifyPayload = List<int>.from(value);
  }

  void _recordVendorNotify({required bool nonEmpty}) {
    _diagNotifyCallbackCount++;
    _diagLastNotifyAt = DateTime.now();
    if (nonEmpty) {
      _diagNotifyNonEmptyCount++;
    }
  }

  /// Pure summary for logs and [inferRemoteDisconnectLikelihood] tests.
  static String inferRemoteDisconnectLikelihood({
    required int notifyCallbackCount,
    required int nonEmptyNotifyCount,
    required int? msConnected,
    required int? msSinceFirstVendorCcc,
    required bool vendorNotifyEnabled,
    required bool reachedVendorCcc,
  }) {
    if (!vendorNotifyEnabled) {
      return 'Vendor notify disabled in app — if disconnect persists, cause is not CCC on vendor char.';
    }
    if (!reachedVendorCcc) {
      return 'Never reached vendor notify CCC — disconnect during discover, params, or pre-subscribe delay.';
    }
    if (notifyCallbackCount >= 1 &&
        msSinceFirstVendorCcc != null &&
        msSinceFirstVendorCcc < 8000) {
      if (nonEmptyNotifyCount == 0) {
        return 'Strong pattern: disconnect soon after CCC; first notify(s) were **empty**. '
            'Try readCharacteristicBeforeVendorNotify=true — your watch often sends a filled 16-byte frame after an initial read.';
      }
      return 'Strong pattern: link dropped within a few seconds of first vendor notify — peripheral/stack likely closes after CCC or first packet (firmware or supervision timeout).';
    }
    if (notifyCallbackCount == 0) {
      return 'CCC done but no notify callbacks before drop — immediate post-CCC disconnect or stream not firing.';
    }
    if (msConnected != null && msConnected > 15000 && notifyCallbackCount >= 1) {
      return 'Held connection longer with notifies — drop may be idle timeout, user action, or later param update.';
    }
    return 'See logcat onConnectionUpdated lines before disconnect; try enableVendorNotifySubscription=false to A/B.';
  }

  void _printBleDisconnectDiagnostics(int? reasonCode, String? reasonDesc) {
    final now = DateTime.now();
    final up = _diagGattUpAt;
    final msConnected = up != null ? now.difference(up).inMilliseconds : null;
    final ccc = _diagFirstVendorCccAt;
    final msSinceCcc =
        ccc != null ? now.difference(ccc).inMilliseconds : null;
    final disc = _diagDiscoverCompleteAt;
    final msSinceDiscover =
        disc != null ? now.difference(disc).inMilliseconds : null;
    final reachedCcc = ccc != null;
    final note = inferRemoteDisconnectLikelihood(
      notifyCallbackCount: _diagNotifyCallbackCount,
      nonEmptyNotifyCount: _diagNotifyNonEmptyCount,
      msConnected: msConnected,
      msSinceFirstVendorCcc: msSinceCcc,
      vendorNotifyEnabled: enableVendorNotifySubscription,
      reachedVendorCcc: reachedCcc,
    );
    debugPrint('');
    debugPrint(
      '🔬 [Bluetooth][DISCONNECT_DIAG] code=$reasonCode desc=$reasonDesc',
    );
    debugPrint(
      '   timing: connected≈${msConnected ?? "?"}ms | '
      'discoverDone→drop≈${msSinceDiscover ?? "?"}ms | '
      'firstVendorCcc→drop≈${msSinceCcc ?? "?"}ms | '
      'notifyCallbacks=$_diagNotifyCallbackCount nonEmpty=$_diagNotifyNonEmptyCount',
    );
    if (_diagLastNotifyAt != null) {
      debugPrint(
        '   lastNotify: ${_diagLastNotifyAt} (${now.difference(_diagLastNotifyAt!).inMilliseconds}ms ago)',
      );
    }
    debugPrint(
      '   flags: balanced=$requestBalancedConnectionPriority '
      'readBeforeNotify=$readCharacteristicBeforeVendorNotify '
      'vendorNotify=$enableVendorNotifySubscription '
      'lowAfterNotify=$requestLowConnectionPriorityAfterVendorNotify',
    );
    debugPrint('   read: $note');
    debugPrint(
      '   note: GATT is down after this — button presses will not log until you reconnect.',
    );
    debugPrint('');
  }

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

      // Stop any ongoing scan and drop previous listener (prevents N duplicate listeners).
      await _flutterScanSubscription?.cancel();
      _flutterScanSubscription = null;
      await fb.FlutterBluePlus.stopScan();

      print('🔍 Starting Bluetooth scan for ${showAllDevices ? "ALL" : "filtered"} devices...');

      // Start scanning
      await fb.FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );

      // Listen to scan results - show ALL devices (including those with no name)
      _flutterScanSubscription = fb.FlutterBluePlus.scanResults.listen((results) {
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
    await _flutterScanSubscription?.cancel();
    _flutterScanSubscription = null;
    await fb.FlutterBluePlus.stopScan();
  }

  /// Connect to a Bluetooth device.
  /// [pin] Optional PIN/passkey for devices that require pairing (e.g. "0000", "1234").
  /// If a system pairing dialog appears, enter the PIN there; we do not call createBond()
  /// here because many BLE devices reject it and then disconnect.
  Future<void> connectToDevice(fb.BluetoothDevice device, {String? pin}) async {
    if (_connectInFlight) {
      print('⚠️ [Bluetooth] connect ignored — another connect is in progress');
      return;
    }

    // Log showed: second connect while link up → "already connected" + full discover again → device drops (0x13).
    if (_connectedDevice?.remoteId == device.remoteId && device.isConnected) {
      print(
        'ℹ️ [Bluetooth] Already connected to ${device.remoteId}, skipping duplicate connect/discover.',
      );
      return;
    }

    _connectInFlight = true;
    try {
      // Disconnect a different peripheral, or clean up stale state
      if (_connectedDevice != null &&
          _connectedDevice!.remoteId != device.remoteId) {
        await disconnectDevice();
      } else if (_connectedDevice != null &&
          _connectedDevice!.remoteId == device.remoteId &&
          !device.isConnected) {
        await disconnectDevice();
      }

      // Orphan GATT: FBP says connected but we lost our reference — close before reconnecting.
      if (device.isConnected &&
          (_connectedDevice == null ||
              _connectedDevice!.remoteId != device.remoteId)) {
        try {
          await device.disconnect();
          await Future<void>.delayed(const Duration(milliseconds: 300));
        } catch (_) {}
      }

      // Critical: scanning and connecting at the same time often causes immediate disconnects
      // on Android (radio contention). Always stop scan before GATT connect.
      await stopScan();
      await Future<void>.delayed(const Duration(milliseconds: 250));

      // After REMOTE_USER disconnect we don't run [disconnectDevice], so keys/subs stay stale.
      // Next discover then logs "Already handling notify … skip" and never attaches listeners
      // to the new GATT session — clear before every new connect.
      await _cancelNotifySubscriptionsAndResetSosGating();
      _resetBleDiagnosticsSession();

      // mtu: null skips automatic requestMtu (reduces chatter; log showed MTU then link updates).
      // 35s matches FBP default — log had connection timeout at 20s on a slow peripheral.
      await device.connect(
        timeout: const Duration(seconds: 35),
        autoConnect: false,
        mtu: null,
      );

      _connectedDevice = device;
      _diagGattUpAt = DateTime.now();

      // Do NOT call createBond(pin) here - many BLE devices don't support it or reject it
      // and then disconnect (REMOTE_USER_TERMINATED). User should enter PIN in the system
      // pairing dialog when it appears.

      // Single listener — duplicate connectionState listeners stack on every reconnect and confuse state.
      await _deviceConnectionSubscription?.cancel();
      _deviceConnectionSubscription = device.connectionState.listen((state) {
        _connectionStateController.add(state);
        if (state == fb.BluetoothConnectionState.disconnected) {
          final reason = device.disconnectReason;
          if (reason != null) {
            _lastDisconnectReason = '${reason.description} (${reason.code})';
            print('📴 [Bluetooth] Device disconnected: ${reason.code} - ${reason.description}');
            _printBleDisconnectDiagnostics(reason.code, reason.description);
          } else {
            _lastDisconnectReason = null;
            _printBleDisconnectDiagnostics(null, null);
          }
          _connectedDevice = null;
          _sosCharacteristic = null;
          _resetBleDiagnosticsSession();
          // Same cleanup as pre-connect — do not await inside stream callback.
          unawaited(_cancelNotifySubscriptionsAndResetSosGating());
        }
      });

      // Let the link stabilize before service discovery (many peripherals drop if discovery is too early)
      await Future<void>.delayed(const Duration(milliseconds: 600));

      if (requestBalancedConnectionPriority && Platform.isAndroid) {
        try {
          await device.requestConnectionPriority(
            connectionPriorityRequest: fb.ConnectionPriority.balanced,
          );
          print('📶 [Bluetooth] Connection priority: balanced (before GATT discover)');
        } catch (e) {
          print('⚠️ [Bluetooth] requestConnectionPriority(balanced): $e');
        }
      }

      // Discover services and characteristics
      await _discoverServices(device);
    } catch (e) {
      await _deviceConnectionSubscription?.cancel();
      _deviceConnectionSubscription = null;
      try {
        await device.disconnect();
      } catch (_) {}
      _connectedDevice = null;
      _sosCharacteristic = null;
      rethrow;
    } finally {
      _connectInFlight = false;
    }
  }

  /// Discover services and find SOS trigger characteristic.
  /// Only subscribes to custom (vendor) notify/indicate characteristics to avoid
  /// triggering disconnects on devices that dislike subscription to standard GATT chars (e.g. 0x2a05).
  ///
  /// **Critical:** FlutterBluePlus defaults to [subscribeToServicesChanged] = true, which enables
  /// indications on **0x2A05 (Service Changed)**. Many safety / Minew-style firmwares respond with
  /// **REMOTE_USER_TERMINATED_CONNECTION** immediately after — your log showed exactly that sequence.
  Future<void> _discoverServices(fb.BluetoothDevice device) async {
    try {
      print('🔍 [Bluetooth] Discovering services for ${device.platformName}...');
      final List<fb.BluetoothService> services = await device.discoverServices(
        subscribeToServicesChanged: false,
      );
      
      print('📋 [Bluetooth] Found ${services.length} services');

      if (stabilizationDelayBeforeNotify > Duration.zero &&
          enableVendorNotifySubscription) {
        print(
          '⏳ [Bluetooth] Waiting ${stabilizationDelayBeforeNotify.inMilliseconds}ms before enabling notify (link settle)...',
        );
        await Future<void>.delayed(stabilizationDelayBeforeNotify);
      }

      // Bluetooth SIG base UUID suffix - standard characteristics use this; skip them to avoid device disconnecting.
      // Plugin may return full UUID (....-00805f9b34fb) or short form (2a05, 00002a05) - treat all as standard.
      const bluetoothSigSuffix = '-0000-1000-8000-00805f9b34fb';
      final shortStandardUuid = RegExp(r'^[0-9a-f]{4}$'); // e.g. 2a05, 1800
      final shortStandardUuid8 = RegExp(r'^[0-9a-f]{8}$'); // e.g. 00002a05
      final fullStandardUuid = RegExp(r'^[0-9a-f]{8}-0000-1000-8000-00805f9b34fb$');
      int subscribedCount = 0;
      int newlySubscribedThisDiscover = 0;
      
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
            if (!enableVendorNotifySubscription) {
              print(
                '       ⏭️ enableVendorNotifySubscription=false — skipping notify (diagnostic)',
              );
              continue;
            }
            final notifyKey =
                '${service.uuid.str}_${characteristic.uuid.str}';
            try {
              _sosCharacteristic = characteristic;

              if (_subscribedNotifyKeys.contains(notifyKey)) {
                print('       ⏭️ Already handling notify for $notifyKey, skip');
                subscribedCount++;
                continue;
              }

              // Some firmwares expect an initial read before CCC write; others disconnect on read+notify burst.
              if (readCharacteristicBeforeVendorNotify && characteristic.properties.read) {
                try {
                  await characteristic.read();
                  await Future<void>.delayed(const Duration(milliseconds: 120));
                } catch (e) {
                  print('       ⚠️ Pre-notify read skipped: $e');
                }
              } else if (!readCharacteristicBeforeVendorNotify &&
                  characteristic.properties.read) {
                print(
                  '       ⏭️ readCharacteristicBeforeVendorNotify=false — skipping pre-notify read',
                );
              }

              if (characteristic.isNotifying) {
                print('       ⏭️ Characteristic already notifying (no CCC rewrite)');
              } else {
                await characteristic.setNotifyValue(true);
              }
              _diagFirstVendorCccAt ??= DateTime.now();
              subscribedCount++;

              print('       ✅ Subscribed to notifications');

              final sub = characteristic.lastValueStream.listen((value) {
                print('🔔 [Bluetooth] Received data from characteristic: $value');
                _recordVendorNotify(nonEmpty: value.isNotEmpty);
                if (value.isEmpty) {
                  print(
                    '   ℹ️ Empty notify after CCC (still counts as peripheral activity). '
                    'If you need payload on first fire, use readCharacteristicBeforeVendorNotify=true.',
                  );
                  return;
                }
                _logIfLongVendorPayloadChanged(value);
                _handleSOSTrigger(value);
              });
              _notifySubscriptions.add(sub);
              _subscribedNotifyKeys.add(notifyKey);
              newlySubscribedThisDiscover++;
            } catch (e) {
              print('       ⚠️ Failed to subscribe: $e');
            }
            // Back-to-back ATT operations can overflow small stacks — brief pause between notifies.
            await Future<void>.delayed(const Duration(milliseconds: 80));
          }
        }
      }

      _diagDiscoverCompleteAt = DateTime.now();
      print('✅ [Bluetooth] Service discovery complete. Subscribed to $subscribedCount characteristics.');

      if (newlySubscribedThisDiscover > 0 &&
          requestLowConnectionPriorityAfterVendorNotify &&
          Platform.isAndroid) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        try {
          await device.requestConnectionPriority(
            connectionPriorityRequest: fb.ConnectionPriority.lowPower,
          );
          print(
            '📶 [Bluetooth] Connection priority: lowPower (after vendor notify — diagnostic for REMOTE_USER drops)',
          );
        } catch (e) {
          print('⚠️ [Bluetooth] requestConnectionPriority(low) after notify: $e');
        }
      }

      if (newlySubscribedThisDiscover > 0 && bleSosPostSubscribeGrace > Duration.zero) {
        _bleSosIgnoreUntil = DateTime.now().add(bleSosPostSubscribeGrace);
        print(
          '⏳ [Bluetooth] BLE SOS gating: ignoring button-like notifies until '
          '${_bleSosIgnoreUntil} (${bleSosPostSubscribeGrace.inSeconds}s post-subscribe grace)',
        );
      }

      if (requestHighConnectionPriority &&
          Platform.isAndroid &&
          subscribedCount > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
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
  /// This is called when the connected device sends a notification (possible button press).
  ///
  /// [forceBypassFilters] — only for [testSOSTrigger]; real notifies must pass grace, length, and debounce.
  void _handleSOSTrigger(List<int> value, {bool forceBypassFilters = false}) async {
    print('🔔 [Bluetooth] Notify payload from device: $value (len=${value.length})');

    if (!forceBypassFilters) {
      final until = _bleSosIgnoreUntil;
      if (until != null && DateTime.now().isBefore(until)) {
        print(
          '⏭️ [Bluetooth] Ignoring notify during post-subscribe grace (until $until)',
        );
        return;
      }
      if (value.length > bleSosMaxNotifyPayloadLength) {
        print(
          '⏭️ [Bluetooth] Payload len ${value.length} > max $bleSosMaxNotifyPayloadLength '
          '(telemetry; SOS API not called)',
        );
        return;
      }
      final last = _lastBleSosTriggerTime;
      if (last != null &&
          DateTime.now().difference(last) < bleSosMinTriggerInterval) {
        print(
          '⏭️ [Bluetooth] SOS debounced (${bleSosMinTriggerInterval.inSeconds}s min interval)',
        );
        return;
      }
    }

    bool shouldTrigger = value.isNotEmpty;
    if (shouldTrigger) {
      print('🚨 [Bluetooth] Short notify treated as possible button — triggering SOS flow');
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
          _lastBleSosTriggerTime = DateTime.now();
          print('✅ [Bluetooth] SOS triggered successfully via Bluetooth device');
        } else {
          final msg = (result.message ?? '').toLowerCase();
          if (msg.contains('already active')) {
            _lastBleSosTriggerTime = DateTime.now();
            print(
              'ℹ️ [Bluetooth] SOS already active on server — no new trigger needed (${result.message})',
            );
          } else {
            print('❌ [Bluetooth] SOS trigger failed: ${result.message}');
          }
        }
      } catch (e) {
        print('❌ [Bluetooth] Error triggering SOS: $e');
      }
    }
  }

  /// Cancels vendor notify streams and clears dedupe keys / SOS gating (required after GATT loss).
  Future<void> _cancelNotifySubscriptionsAndResetSosGating() async {
    if (_notifySubscriptions.isEmpty &&
        _subscribedNotifyKeys.isEmpty &&
        _bleSosIgnoreUntil == null &&
        _lastBleSosTriggerTime == null) {
      return;
    }
    final copy = List<StreamSubscription<List<int>>>.from(_notifySubscriptions);
    _notifySubscriptions.clear();
    for (final sub in copy) {
      try {
        await sub.cancel();
      } catch (_) {}
    }
    _subscribedNotifyKeys.clear();
    _bleSosIgnoreUntil = null;
    _lastBleSosTriggerTime = null;
  }

  /// Disconnect from current device
  Future<void> disconnectDevice() async {
    await _deviceConnectionSubscription?.cancel();
    _deviceConnectionSubscription = null;
    await _cancelNotifySubscriptionsAndResetSosGating();
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
    _flutterScanSubscription?.cancel();
    _flutterScanSubscription = null;
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
    _handleSOSTrigger([1], forceBypassFilters: true);
  }
}
