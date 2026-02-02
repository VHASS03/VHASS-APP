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
        
        // Voice Monitoring Service channel (new)
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
            val intent = Intent(Intent.ACTION_CALL).apply {
                data = Uri.parse("tel:$phoneNumber")
            }
            startActivity(intent)
            println("📞 Call initiated to: ${maskNumberForLog(phoneNumber)}")
        } catch (e: Exception) {
            println("❌ Error making call: ${e.message}")
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
