import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Talks to [MinewBeaconPlusPlugin] on Android (BeaconSET Plus / MTBeaconPlus.aar).
///
/// Matches the Minew guide: scan stage via [MTCentralManager] and advertisement
/// frames from [MTFrameHandler.getAdvFrames].
/// See: https://docs.minew.com/Android/Android_BeaconPlus_Software_Development_Kit_Guide.html#design-instructions
class MinewBeaconPlusChannel {
  MinewBeaconPlusChannel._();

  static const MethodChannel _method = MethodChannel(
    'com.example.my_app/minew_beacon_plus',
  );
  static const EventChannel _events = EventChannel(
    'com.example.my_app/minew_beacon_plus/events',
  );
  static const EventChannel _connectionEvents = EventChannel(
    'com.example.my_app/minew_beacon_plus/connection_events',
  );

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Stops BLE scan (see Minew `stopScan`).
  static Future<void> stopScan() async {
    if (!_isAndroid) return;
    await _method.invokeMethod<void>('stopScan');
  }

  /// Whether the SDK reports scanning (see Minew `isScanning`).
  static Future<bool> isScanning() async {
    if (!_isAndroid) return false;
    final v = await _method.invokeMethod<bool>('isScanning');
    return v ?? false;
  }

  /// Stop scan, clear peripheral cache, then you may start listening again (Minew pull-to-refresh flow).
  static Future<void> clearCache() async {
    if (!_isAndroid) return;
    await _method.invokeMethod<void>('clearCache');
  }

  /// Repeated lists of peripherals from [onScanedPeripheral] — each item is a `Map` with
  /// `mac`, `name`, `battery`, `rssi`, `lastUpdate`, `frames` (list of maps; iBeacon includes `uuid`, `major`, `minor`).
  static Stream<List<dynamic>> scanResults() {
    if (!_isAndroid) {
      return const Stream.empty();
    }
    return _events.receiveBroadcastStream().map(
          (e) => List<dynamic>.from(e as List),
        );
  }

  /// Listen **before** calling [connect]: connection + password flow (Minew
  /// `ConnectionStatueListener` / `PASSWORDVALIDATING`).
  ///
  /// Events are maps: `status` (e.g. `CONNECTING`, `PASSWORDVALIDATING`, `COMPLETED`), optional `error`.
  static Stream<Map<String, dynamic>> connectionStatus() {
    if (!_isAndroid) {
      return const Stream.empty();
    }
    return _connectionEvents.receiveBroadcastStream().map((e) {
      final m = e as Map;
      return m.map((k, v) => MapEntry(k.toString(), v));
    });
  }

  /// Connect to a device seen during scan. [password] must be **exactly 8** characters
  /// (letters/digits) when the beacon requires a connection password (Minew guide).
  static Future<void> connect({
    required String mac,
    String? password,
  }) async {
    if (!_isAndroid) return;
    await _method.invokeMethod<void>('connect', {
      'mac': mac,
      if (password != null) 'password': password,
    });
  }

  static Future<void> disconnect({required String mac}) async {
    if (!_isAndroid) return;
    await _method.invokeMethod<void>('disconnect', {'mac': mac});
  }
}
