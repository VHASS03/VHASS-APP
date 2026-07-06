# Minew BeaconSET Plus (`MTBeaconPlus.aar`)

This app can use the **BeaconSET Plus** SDK for miniBeaconPlus devices.

1. Download the SDK from [Minew – BeaconSET Plus Android SDK Guide](https://docs.minew.com/Android/Android_BeaconPlus_Software_Development_Kit_Guide.html#get-started).
2. Copy **`MTBeaconPlus.aar`** into this folder: `android/app/libs/MTBeaconPlus.aar`
3. Rebuild the project. Gradle will pick up the AAR automatically.

`ConnectService` + **`BluetoothChangedReceiver`** are already declared in `AndroidManifest.xml` (per [Minew – Prepare](https://docs.minew.com/Android/Android_BeaconPlus_Software_Development_Kit_Guide.html#prepare)). If you **never** use Minew, remove that block from the manifest so the app does not reference SDK classes.

If the AAR is **missing**, the app still builds; native Minew code is excluded until you add the file.

### Docs checklist (from Minew)

- **minSdkVersion 24** (enforced automatically when `MTBeaconPlus.aar` is present).
- **Permissions** – Bluetooth + location are already in `AndroidManifest.xml`; Android 12+ uses `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT`.
- **`ConnectService`** + **`BluetoothChangedReceiver`** – registered in `AndroidManifest.xml`.
- **`MTCentralManager.getInstance(context).startService()`** – called when the Minew plugin registers (see `MinewBeaconPlusPlugin.kt`).
- **ProGuard** – rules in `android/app/proguard-rules.pro` when you enable minification.

### Connection password (Minew guide — *Connect to device*)

Many beacons ask for a **connection password** during pairing. The SDK calls **`PASSWORDVALIDATING`**; you must respond with **`getPasswordListener.getPassword(...)`** using a string of **exactly 8** characters (letters or digits). Wrong length can break device firmware (per Minew).

In this app:

1. Start scan (`scanResults()` stream).
2. Subscribe to **`connectionStatus()`** on `MinewBeaconPlusChannel`.
3. Call **`connect(mac: '...', password: 'your8char')`** — if the device requires a password, native code supplies it when `PASSWORDVALIDATING` fires.

**App login** (Syava AI) uses **phone + OTP only** — there is no separate account password on the login screen. “Password verification” for **Minew** means the **beacon’s 8-character connection password**, not OTP.

### Flutter

Use **`MinewBeaconPlusChannel`**: `scanResults`, `connectionStatus`, `connect`, `disconnect` (see `lib/core/services/minew_beacon_plus_channel.dart`).
