# Minew BeaconSET Plus (`MTBeaconPlus.aar`)

This app can use the **BeaconSET Plus** SDK for miniBeaconPlus devices.

1. Download the SDK from [Minew – BeaconSET Plus Android SDK Guide](https://docs.minew.com/Android/Android_BeaconPlus_Software_Development_Kit_Guide.html#get-started).
2. Copy **`MTBeaconPlus.aar`** into this folder: `android/app/libs/MTBeaconPlus.aar`
3. **Paste** the Minew entries below into `android/app/src/main/AndroidManifest.xml` inside `<application>` (after you add the AAR — they reference SDK classes).
4. Rebuild the project. Gradle will pick up the AAR automatically.

If the AAR is **missing**, the app still builds; native Minew code is excluded until you add the file.

### AndroidManifest.xml (from [Minew guide – Prepare](https://docs.minew.com/Android/Android_BeaconPlus_Software_Development_Kit_Guide.html#prepare))

Add **inside** `<application>`:

```xml
        <service
            android:name="com.minew.beaconplus.sdk.ConnectService"
            android:exported="false" />

        <receiver
            android:name="com.minew.beaconplus.sdk.receivers.BluetoothChangedReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.bluetooth.adapter.action.STATE_CHANGED" />
            </intent-filter>
        </receiver>
```

### Docs checklist (from Minew)

- **minSdkVersion 24** (enforced automatically when `MTBeaconPlus.aar` is present).
- **Permissions** – Bluetooth + location are already in `AndroidManifest.xml`; Android 12+ uses `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT`.
- **`ConnectService`** + **`BluetoothChangedReceiver`** – add using the XML block above when you enable the SDK.
- **`MTCentralManager.getInstance(context).startService()`** – called when the Minew plugin registers (see `MinewBeaconPlusPlugin.kt`).
- **ProGuard** – rules in `android/app/proguard-rules.pro` when you enable minification.

### Flutter

Use channel **`com.example.my_app/minew_beacon_plus`** and event stream **`com.example.my_app/minew_beacon_plus/events`** (see `lib/core/services/minew_beacon_plus_channel.dart`).
