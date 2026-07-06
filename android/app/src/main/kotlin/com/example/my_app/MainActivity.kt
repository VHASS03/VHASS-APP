package com.example.my_app

import android.content.Intent
import android.net.Uri
import android.app.PendingIntent
import android.content.Context
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val DIALER_CHANNEL = "com.example.my_app/dialer"
    private val SMS_CHANNEL = "com.example.my_app/sms"
    private val VOICE_SERVICE_CHANNEL = "com.example.my_app/voice_service"
    private val WAKE_WORD_CHANNEL = "com.example.my_app/wake_word"
    private val ALARM_CHANNEL = "com.example.my_app/alarm"
    
    // Alarm service instance
    private var alarmService: AlarmService? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Dialer channel (existing)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DIALER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "makeCall" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    if (phoneNumber != null) {
                        makeCall(phoneNumber)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "openDialer" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    if (phoneNumber != null) {
                        openDialer(phoneNumber)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // SMS channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSMS" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")
                    if (phoneNumber != null && message != null) {
                        val success = sendSMS(phoneNumber, message)
                        result.success(success)
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // Voice Monitoring Service channel (continuous mode - high battery)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVoiceService" -> {
                    val authToken = call.argument<String>("authToken")
                    val userId = call.argument<String>("userId")
                    val serverUrl = call.argument<String>("serverUrl")
                    
                    // Save to shared preferences for service to access
                    if (authToken != null && userId != null && serverUrl != null) {
                        saveUserDataForService(authToken, userId, serverUrl)
                    }
                    
                    VoiceMonitoringService.startService(this)
                    result.success(true)
                }
                "stopVoiceService" -> {
                    VoiceMonitoringService.stopService(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // Wake Word Detection Service channel (battery efficient, Android built-in only)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WAKE_WORD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startWakeWordService" -> {
                    val authToken = call.argument<String>("authToken")
                    val userId = call.argument<String>("userId")
                    val serverUrl = call.argument<String>("serverUrl")
                    
                    // Save to shared preferences for service to access
                    if (authToken != null && userId != null && serverUrl != null) {
                        saveUserDataForService(authToken, userId, serverUrl)
                    }
                    
                    WakeWordDetectorService.startService(this)
                    result.success(true)
                }
                "stopWakeWordService" -> {
                    WakeWordDetectorService.stopService(this)
                    result.success(true)
                }
                "isWakeWordServiceRunning" -> {
                    result.success(WakeWordDetectorService.isRunning())
                }
                else -> result.notImplemented()
            }
        }
        
        // Alarm Service channel (for emergency SOS alerts)
        alarmService = AlarmService(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playAlarmSound" -> {
                    val duration = call.argument<Int>("duration")?.toLong() ?: 30000L
                    val vibrate = call.argument<Boolean>("vibrate") ?: true
                    
                    alarmService?.playAlarm(duration, vibrate)
                    result.success(true)
                }
                "stopAlarmSound" -> {
                    alarmService?.stopAlarm()
                    result.success(true)
                }
                "isAlarmPlaying" -> {
                    result.success(alarmService?.isAlarmPlaying() ?: false)
                }
                else -> result.notImplemented()
            }
        }

        // Minew BeaconSET Plus (optional): only registers when MTBeaconPlus.aar is in app/libs/
        tryRegisterMinewBeaconPlus(flutterEngine)
    }

    /** Loads [com.example.my_app.minew.MinewBeaconPlusPlugin] via reflection so the project builds without the vendor AAR. */
    private fun tryRegisterMinewBeaconPlus(flutterEngine: FlutterEngine) {
        try {
            val clazz = Class.forName("com.example.my_app.minew.MinewBeaconPlusPlugin")
            val m = clazz.getMethod("registerWith", FlutterEngine::class.java, Context::class.java)
            m.invoke(null, flutterEngine, this)
        } catch (_: Throwable) {
            // No AAR / class excluded — safe to ignore.
        }
    }
    
    private fun saveUserDataForService(authToken: String, userId: String, serverUrl: String) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString("flutter.authToken", authToken)
            putString("flutter.userId", userId)
            putString("flutter.serverUrl", serverUrl)
            apply()
        }
        println("✅ User data saved for background service")
    }

    private fun makeCall(phoneNumber: String) {
        try {
            // Use ACTION_CALL for immediate call (requires CALL_PHONE permission)
            val intent = Intent(Intent.ACTION_CALL).apply {
                data = Uri.parse("tel:$phoneNumber")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK // Don't wait for activity
            }
            startActivity(intent)
            println("📞 Call initiated IMMEDIATELY to: ${maskNumberForLog(phoneNumber)}")
        } catch (e: SecurityException) {
            println("❌ CALL_PHONE permission missing: ${e.message}")
            // Fallback to dialer
            openDialer(phoneNumber)
        } catch (e: Exception) {
            println("❌ Error making call: ${e.message}")
            // Fallback to dialer
            openDialer(phoneNumber)
        }
    }

    private fun openDialer(phoneNumber: String) {
        try {
            val intent = Intent(Intent.ACTION_DIAL).apply {
                data = Uri.parse("tel:$phoneNumber")
            }
            startActivity(intent)
            println("📞 Dialer opened with: ${maskNumberForLog(phoneNumber)}")
        } catch (e: Exception) {
            println("❌ Error opening dialer: ${e.message}")
        }
    }
    
    private fun sendSMS(phoneNumber: String, message: String): Boolean {
        return try {
            println("📱 Sending SMS to: ${maskNumberForLog(phoneNumber)}")
            println("   Message: $message")

            // Format phone number with country code if not already present
            val formattedNumber = if (phoneNumber.startsWith("+")) {
                phoneNumber
            } else if (phoneNumber.startsWith("91")) {
                "+$phoneNumber"  // India country code
            } else {
                "+91$phoneNumber"  // Add India country code
            }
            
            println("   Formatted: ${maskNumberForLog(formattedNumber)}")

            val smsManager: SmsManager = SmsManager.getDefault()
            
            // Split message if longer than 160 characters
            val parts = smsManager.divideMessage(message)
            val sentIntents = ArrayList<PendingIntent>()
            
            for (i in parts.indices) {
                sentIntents.add(
                    PendingIntent.getBroadcast(
                        this,
                        i,
                        Intent("SMS_SENT_ACTION"),
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    )
                )
            }

            smsManager.sendMultipartTextMessage(formattedNumber, null, parts, sentIntents, null)
            
            println("✅ SMS sent successfully via Android native SMS")
            println("   To: ${maskNumberForLog(formattedNumber)}")
            println("   Parts: ${parts.size}")
            true
        } catch (e: Exception) {
            println("❌ SMS sending failed: ${e.message}")
            println("   Error type: ${e.javaClass.simpleName}")
            false
        }
    }

    private fun maskNumberForLog(phone: String): String {
        val digits = phone.filter { it.isDigit() }
        if (digits.isEmpty()) return phone

        val local = if (digits.length > 10) digits.takeLast(10) else digits
        val cc = if (digits.length > 10) digits.dropLast(10) else "91"
        val visibleLocal = local.take(5)
        return "+$cc $visibleLocal***"
    }
}
