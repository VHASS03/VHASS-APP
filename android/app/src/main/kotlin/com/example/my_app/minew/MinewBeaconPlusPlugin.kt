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
import com.minew.beaconplus.sdk.enums.FrameType
import com.minew.beaconplus.sdk.frames.IBeaconFrame
import com.minew.beaconplus.sdk.frames.MinewFrame
import com.minew.beaconplus.sdk.interfaces.OnBluetoothStateChangedListener
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter bridge for [Minew BeaconSET Plus Android SDK](https://docs.minew.com/Android/Android_BeaconPlus_Software_Development_Kit_Guide.html#design-instructions).
 *
 * Mirrors the guide:
 * - [MTCentralManager.getInstance] + [MTCentralManager.startService]
 * - [MTCentralManager.setBluetoothChangedListener]
 * - [MTCentralManager.startScan] / [MTCentralManager.stopScan] / [MTCentralManager.clear]
 * - [MTCentralManager.setMTCentralManagerListener] + [MTCentralManagerListener.onScanedPeripheral]
 * - [MTFrameHandler.getAdvFrames] and iBeacon via [FrameType.FrameiBeacon] / [IBeaconFrame]
 *
 * If your AAR uses different package names for frames/enums, adjust imports to match the JAR/AAR.
 */
object MinewBeaconPlusPlugin {
    private const val TAG = "MinewBeaconPlus"
    private const val METHOD_CHANNEL = "com.example.my_app/minew_beacon_plus"
    private const val EVENT_CHANNEL = "com.example.my_app/minew_beacon_plus/events"

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

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                private val mainHandler = Handler(Looper.getMainLooper())
                private var sink: EventChannel.EventSink? = null

                private val scanListener =
                    object : MTCentralManagerListener {
                        override fun onScanedPeripheral(peripherals: MutableList<MTPeripheral>?) {
                            if (peripherals == null) return
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
                    mtCentral.setMTCentralManagerListener(scanListener)
                    mtCentral.startScan()
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
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
}
