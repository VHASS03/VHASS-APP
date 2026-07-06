package com.example.my_app.minew

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.minew.beaconplus.sdk.MTCentralManager
import com.minew.beaconplus.sdk.MTCentralManagerListener
import com.minew.beaconplus.sdk.MTFrameHandler
import com.minew.beaconplus.sdk.MTPeripheral
import com.minew.beaconplus.sdk.enums.BluetoothState
import com.minew.beaconplus.sdk.enums.ConnectionStatus
import com.minew.beaconplus.sdk.enums.FrameType
import com.minew.beaconplus.sdk.exception.MTException
import com.minew.beaconplus.sdk.frames.IBeaconFrame
import com.minew.beaconplus.sdk.frames.MinewFrame
import com.minew.beaconplus.sdk.interfaces.ConnectionStatueListener
import com.minew.beaconplus.sdk.interfaces.GetPasswordListener
import com.minew.beaconplus.sdk.interfaces.OnBluetoothStateChangedListener
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Collections

/**
 * Flutter bridge for [Minew BeaconSET Plus Android SDK](https://docs.minew.com/Android/Android_BeaconPlus_Software_Development_Kit_Guide.html#design-instructions).
 *
 * Mirrors the guide:
 * - [MTCentralManager.getInstance] + [MTCentralManager.startService]
 * - [MTCentralManager.setBluetoothChangedListener]
 * - [MTCentralManager.startScan] / [MTCentralManager.stopScan] / [MTCentralManager.clear]
 * - [MTCentralManager.setMTCentralManagerListener] + [MTCentralManagerListener.onScanedPeripheral]
 * - [MTFrameHandler.getAdvFrames] and iBeacon via [FrameType.FrameiBeacon] / [IBeaconFrame]
 * - Connect stage: [MTCentralManager.connect] + [ConnectionStatueListener] — on
 *   [ConnectionStatus.PASSWORDVALIDATING] supply exactly **8** alphanumeric chars via
 *   [GetPasswordListener.getPassword] (see Minew guide).
 *
 * If your AAR uses different package names for frames/enums, adjust imports to match the JAR/AAR.
 */
object MinewBeaconPlusPlugin {
    private const val TAG = "MinewBeaconPlus"
    private const val METHOD_CHANNEL = "com.example.my_app/minew_beacon_plus"
    private const val EVENT_CHANNEL = "com.example.my_app/minew_beacon_plus/events"
    private const val CONNECTION_EVENT_CHANNEL = "com.example.my_app/minew_beacon_plus/connection_events"

    private val mainHandler = Handler(Looper.getMainLooper())
    /** SDK caches peripherals during scan; we mirror the latest list for connect-by-mac. */
    private val lastPeripherals = Collections.synchronizedList(mutableListOf<MTPeripheral>())
    /** Password for the next connect (Minew: length 8, digits or letters). */
    @Volatile
    private var pendingConnectPassword: String? = null

    private var connectionStatusSink: EventChannel.EventSink? = null

    @JvmStatic
    fun registerWith(flutterEngine: FlutterEngine, context: Context) {
        val app = context.applicationContext
        val mtCentral = MTCentralManager.getInstance(app)

        // Guide: call startService after app starts so connection-stage APIs work.
        mtCentral.startService()

        mtCentral.setBluetoothChangedListener(
            object : OnBluetoothStateChangedListener {
                override fun onStateChanged(state: BluetoothState?) {
                    Log.d(TAG, "Bluetooth state: $state (SDK works when Bluetooth is powered on)")
                }
            },
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            handleMethodCall(mtCentral, call, result)
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CONNECTION_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    connectionStatusSink = events
                }

                override fun onCancel(arguments: Any?) {
                    connectionStatusSink = null
                }
            },
        )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                private var sink: EventChannel.EventSink? = null

                private val scanListener =
                    object : MTCentralManagerListener {
                        override fun onScanedPeripheral(peripherals: MutableList<MTPeripheral>?) {
                            if (peripherals == null) return
                            lastPeripherals.clear()
                            lastPeripherals.addAll(peripherals)
                            val out = ArrayList<Map<String, Any?>>()
                            for (p in peripherals) {
                                val fh: MTFrameHandler = p.mMTFrameHandler
                                val framesOut = ArrayList<Map<String, Any?>>()
                                val advFrames: ArrayList<MinewFrame>? = fh.advFrames
                                if (advFrames != null) {
                                    for (minewFrame in advFrames) {
                                        if (minewFrame.frameType == FrameType.FrameiBeacon) {
                                            val ib = minewFrame as IBeaconFrame
                                            framesOut.add(
                                                mapOf(
                                                    "frameType" to "iBeacon",
                                                    "uuid" to ib.uuid,
                                                    "major" to ib.major,
                                                    "minor" to ib.minor,
                                                ),
                                            )
                                        } else {
                                            framesOut.add(
                                                mapOf(
                                                    "frameType" to minewFrame.frameType.name,
                                                ),
                                            )
                                        }
                                    }
                                }
                                out.add(
                                    mapOf(
                                        "mac" to fh.mac,
                                        "name" to fh.name,
                                        "battery" to fh.battery,
                                        "rssi" to fh.rssi,
                                        "lastUpdate" to fh.lastUpdate,
                                        "frames" to framesOut,
                                    ),
                                )
                            }
                            mainHandler.post {
                                sink?.success(out)
                            }
                        }
                    }

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sink = events
                    // Official sample order: startScan() then setMTCentralManagerListener(...)
                    // https://docs.minew.com/Android/Android_BeaconPlus_Software_Development_Kit_Guide.html#scan-devices
                    mtCentral.startScan()
                    mtCentral.setMTCentralManagerListener(scanListener)
                }

                override fun onCancel(arguments: Any?) {
                    mtCentral.stopScan()
                    sink = null
                }
            },
        )
    }

    private fun handleMethodCall(mtCentral: MTCentralManager, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "stopScan" -> {
                mtCentral.stopScan()
                result.success(true)
            }
            "isScanning" -> {
                result.success(mtCentral.isScanning)
            }
            "clearCache" -> {
                // Guide: stop scanning before clear, then you may startScan again.
                mtCentral.stopScan()
                mtCentral.clear()
                lastPeripherals.clear()
                result.success(true)
            }
            "connect" -> {
                val mac = call.argument<String>("mac")
                val password = call.argument<String>("password")
                if (mac.isNullOrBlank()) {
                    result.error("bad_args", "mac is required", null)
                    return
                }
                val peripheral =
                    lastPeripherals.find { p ->
                        p.mMTFrameHandler?.mac?.equals(mac, ignoreCase = true) == true
                    }
                if (peripheral == null) {
                    result.error(
                        "not_found",
                        "No scanned device with this mac. Scan first, then connect.",
                        null,
                    )
                    return
                }
                // Scan + connect simultaneously often drops the link; stop scan first (doc pull-to-refresh uses stop before clear).
                if (mtCentral.isScanning) {
                    mtCentral.stopScan()
                }
                pendingConnectPassword = password
                val connectionListener =
                    object : ConnectionStatueListener {
                        // Guide runs this whole callback on the UI thread (runOnUiThread) including getPassword().
                        // https://docs.minew.com/Android/Android_BeaconPlus_Software_Development_Kit_Guide.html#connect-to-device
                        override fun onUpdateConnectionStatus(
                            status: ConnectionStatus?,
                            getPasswordListener: GetPasswordListener?,
                        ) {
                            mainHandler.post {
                                connectionStatusSink?.success(
                                    mapOf(
                                        "status" to (status?.name ?: "unknown"),
                                    ),
                                )
                                if (status == ConnectionStatus.PASSWORDVALIDATING) {
                                    val pw = pendingConnectPassword
                                    if (pw != null && pw.length == 8) {
                                        getPasswordListener?.getPassword(pw)
                                    } else {
                                        Log.e(
                                            TAG,
                                            "PASSWORDVALIDATING: provide exactly 8-char password (connect mac + password).",
                                        )
                                        connectionStatusSink?.success(
                                            mapOf(
                                                "status" to "PASSWORDVALIDATING",
                                                "error" to "Missing or invalid password (must be 8 characters).",
                                            ),
                                        )
                                    }
                                }
                            }
                        }

                        override fun onError(exception: MTException?) {
                            mainHandler.post {
                                connectionStatusSink?.error(
                                    "mt_error",
                                    exception?.message ?: "connection error",
                                    null,
                                )
                            }
                        }
                    }
                // Defer connect slightly after stopScan — avoid blocking main thread (no Thread.sleep).
                mainHandler.postDelayed(
                    {
                        mtCentral.connect(peripheral, connectionListener)
                    },
                    150,
                )
                result.success(true)
            }
            "disconnect" -> {
                val mac = call.argument<String>("mac")
                if (mac.isNullOrBlank()) {
                    result.error("bad_args", "mac is required", null)
                    return
                }
                val peripheral =
                    lastPeripherals.find { p ->
                        p.mMTFrameHandler?.mac?.equals(mac, ignoreCase = true) == true
                    }
                if (peripheral == null) {
                    result.error("not_found", "No device with this mac in cache.", null)
                    return
                }
                mtCentral.disconnect(peripheral)
                pendingConnectPassword = null
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

}
