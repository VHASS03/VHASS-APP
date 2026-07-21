import 'package:flutter_test/flutter_test.dart';
import 'package:VHASS/core/services/bluetooth_service.dart';

void main() {
  group('BluetoothService.inferRemoteDisconnectLikelihood', () {
    test('vendor notify off → not CCC', () {
      expect(
        BluetoothService.inferRemoteDisconnectLikelihood(
          notifyCallbackCount: 0,
          nonEmptyNotifyCount: 0,
          msConnected: 100,
          msSinceFirstVendorCcc: null,
          vendorNotifyEnabled: false,
          reachedVendorCcc: false,
        ),
        contains('Vendor notify disabled'),
      );
    });

    test('never CCC → discover/link phase', () {
      expect(
        BluetoothService.inferRemoteDisconnectLikelihood(
          notifyCallbackCount: 0,
          nonEmptyNotifyCount: 0,
          msConnected: 2000,
          msSinceFirstVendorCcc: null,
          vendorNotifyEnabled: true,
          reachedVendorCcc: false,
        ),
        contains('Never reached vendor notify CCC'),
      );
    });

    test('first non-empty notify then quick drop → firmware pattern', () {
      expect(
        BluetoothService.inferRemoteDisconnectLikelihood(
          notifyCallbackCount: 1,
          nonEmptyNotifyCount: 1,
          msConnected: 5000,
          msSinceFirstVendorCcc: 500,
          vendorNotifyEnabled: true,
          reachedVendorCcc: true,
        ),
        contains('Strong pattern'),
      );
    });

    test('CCC but zero notify callbacks', () {
      expect(
        BluetoothService.inferRemoteDisconnectLikelihood(
          notifyCallbackCount: 0,
          nonEmptyNotifyCount: 0,
          msConnected: 3000,
          msSinceFirstVendorCcc: 100,
          vendorNotifyEnabled: true,
          reachedVendorCcc: true,
        ),
        contains('no notify callbacks'),
      );
    });

    test('quick drop after empty-only notify → suggest pre-read', () {
      expect(
        BluetoothService.inferRemoteDisconnectLikelihood(
          notifyCallbackCount: 2,
          nonEmptyNotifyCount: 0,
          msConnected: 5000,
          msSinceFirstVendorCcc: 500,
          vendorNotifyEnabled: true,
          reachedVendorCcc: true,
        ),
        contains('empty'),
      );
    });
  });
}
