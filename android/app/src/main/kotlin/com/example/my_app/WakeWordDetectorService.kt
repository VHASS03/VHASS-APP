package com.example.my_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import com.rementia.openwakeword.lib.WakeWordEngine
import com.rementia.openwakeword.lib.model.DetectionMode
import com.rementia.openwakeword.lib.model.WakeWordModel
import kotlinx.coroutines.*
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL

/**
 * Battery-Efficient, Local Emergency Voice Detection Service using openWakeWord
 *
 * Pipeline:
 * 1. openWakeWord Engine (manages AudioRecord 16kHz PCM Mono internally)
 * 2. Real-time local ONNX inference for custom wake word detection
 * 3. Emergency SOS Activation via StealthSOSManager
 */
class WakeWordDetectorService : Service() {
    
    companion object {
        const val TAG = "WakeWordService"
        const val CHANNEL_ID = "wake_word_channel"
        const val NOTIFICATION_ID = 1002
        
        private var instance: WakeWordDetectorService? = null
        
        fun startService(context: Context) {
            val intent = Intent(context, WakeWordDetectorService::class.java)
            context.startForegroundService(intent)
            Log.d(TAG, "🚀 Starting wake word detection service")
        }
        
        fun stopService(context: Context) {
            val intent = Intent(context, WakeWordDetectorService::class.java)
            context.stopService(intent)
            Log.d(TAG, "🛑 Stopping wake word detection service")
        }
        
        fun isRunning(): Boolean = instance != null
    }
    
    // Service State
    private enum class State {
        MONITORING,  // Active wake word detection
        SOS_ACTIVE   // SOS triggered
    }
    private var currentState = State.MONITORING
    
    // openWakeWord Engine & Scope
    private var wakeWordEngine: WakeWordEngine? = null
    private var isMonitoring = false
    private var monitoringJob: Job? = null
    private val serviceScope = CoroutineScope(Dispatchers.IO + Job())
    private val mainHandler = Handler(Looper.getMainLooper())
    
    // Pipeline Components
    private var stealthSOSManager: StealthSOSManager? = null
    
    // Decision State Variables
    private var lastTriggerTime = 0L
    private val TRIGGER_DEBOUNCE_MS = 60000L
    
    // Auth & Endpoints
    private var authToken: String? = null
    private var userId: String? = null
    private var serverUrl: String? = null
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "✅ WakeWordDetectorService created")
        createNotificationChannel()
        loadUserData()
        
        // Initialize Stealth SOS Manager
        stealthSOSManager = StealthSOSManager(this)
        
        // Initialize openWakeWord Engine
        try {
            val model = WakeWordModel(
                name = "help_me_out",
                modelPath = "help_me_out.onnx", // Must be placed in android/app/src/main/assets/
                threshold = 0.5f
            )
            wakeWordEngine = WakeWordEngine(
                context = this,
                models = listOf(model),
                detectionMode = DetectionMode.SINGLE_BEST,
                scope = serviceScope
            )
            Log.i(TAG, "✅ openWakeWord Engine initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to initialize openWakeWord Engine: ${e.message}")
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        loadUserData()
        
        // Start as foreground service
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        startAudioPipeline()
        
        return START_STICKY
    }
    
    private fun startAudioPipeline() {
        if (isMonitoring) return
        isMonitoring = true
        
        try {
            wakeWordEngine?.start()
            Log.d(TAG, "🎙️ openWakeWord recording started")
            
            monitoringJob = serviceScope.launch {
                wakeWordEngine?.detections?.collect { detection ->
                    val keyword = detection.model.name
                    val confidence = detection.score
                    Log.i(TAG, "🎯 WakeWord detected: '$keyword' (conf: $confidence)")
                    
                    onTriggerDetected(keyword, confidence)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start openWakeWord pipeline: ${e.message}")
            isMonitoring = false
        }
    }
    
    private fun onTriggerDetected(keyword: String, confidence: Float) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastTriggerTime < TRIGGER_DEBOUNCE_MS) {
            Log.w(TAG, "⚠️ Ignoring duplicate voice trigger (debounced)")
            return
        }
        lastTriggerTime = now
        
        Log.e(TAG, "🚨🚨🚨 EMERGENCY DETECTED: '$keyword' (conf=%.2f)".format(confidence))
        
        currentState = State.SOS_ACTIVE
        updateNotification()
        
        // Stop engine while SOS is active to avoid multiple triggers during emergency calls/SMS
        wakeWordEngine?.stop()
        
        serviceScope.launch {
            try {
                val contacts = getEmergencyContacts()
                if (contacts.isEmpty()) {
                    Log.w(TAG, "⚠️ No emergency contacts - sending regular triggers")
                    triggerHeadlessSOS(null)
                    return@launch
                }
                
                val stealthContacts = contacts.map { contact ->
                    StealthSOSManager.EmergencyContact(
                        name = contact.name,
                        phone = contact.phone,
                        countryCode = contact.countryCode,
                        priority = contact.priority
                    )
                }
                
                val locationUrl = getLocationUrl()
                
                withContext(Dispatchers.Main) {
                    try {
                        stealthSOSManager?.startStealthSOS(
                            contacts = stealthContacts,
                            locationUrl = locationUrl,
                            authToken = authToken,
                            serverUrl = serverUrl,
                            skipCountdown = true // Immediate execution for voice SOS
                        )
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Stealth SOS failed: ${e.message}. Falling back to regular.")
                        triggerHeadlessSOS(contacts)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Voice SOS trigger exception: ${e.message}")
                triggerHeadlessSOS(null)
            } finally {
                // Reset monitoring state after 30 seconds
                delay(30000)
                currentState = State.MONITORING
                updateNotification()
                
                // Restart engine
                if (isMonitoring) {
                    wakeWordEngine?.start()
                }
            }
        }
    }
    
    private fun isNetworkAvailable(): Boolean {
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }
    
    private fun loadUserData() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        authToken = prefs.getString("flutter.authToken", null)
        userId = prefs.getString("flutter.userId", null)
        serverUrl = prefs.getString("flutter.serverUrl", "http://10.0.2.2:5000")
    }
    
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Voice SOS Monitoring",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Active voice keyword spotting for emergency help signals"
            setShowBadge(false)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
    
    private fun createNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        val (title, text) = when (currentState) {
            State.MONITORING -> "🎤 Voice SOS Ready" to "Active voice-trigger monitoring (openWakeWord enabled)"
            State.SOS_ACTIVE -> "🚨 SOS ACTIVATED" to "Contacting emergency services"
        }
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    private fun updateNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, createNotification())
    }
    
    private suspend fun triggerHeadlessSOS(preFetchedContacts: List<EmergencyContact>?) = withContext(Dispatchers.IO) {
        val contacts = preFetchedContacts ?: getEmergencyContacts()
        if (contacts.isEmpty()) return@withContext
        
        triggerSOSAPI()
        
        for (contact in contacts) {
            makeEmergencyCall(contact.phone, contact.countryCode)
            sendEmergencySMS(contact.phone, contact.countryCode)
        }
    }
    
    private suspend fun getEmergencyContacts(): List<EmergencyContact> = withContext(Dispatchers.IO) {
        try {
            if (authToken == null) return@withContext emptyList()
            val url = URL("$serverUrl/api/contacts")
            val connection = url.openConnection() as HttpURLConnection
            connection.apply {
                requestMethod = "GET"
                setRequestProperty("Authorization", "Bearer $authToken")
                connectTimeout = 5000
                readTimeout = 5000
            }
            
            if (connection.responseCode == 200) {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(response)
                if (json.getBoolean("success")) {
                    val arr = json.getJSONArray("contacts")
                    val list = mutableListOf<EmergencyContact>()
                    for (i in 0 until arr.length()) {
                        val c = arr.getJSONObject(i)
                        if (!c.optBoolean("isActive", true)) continue
                        list.add(EmergencyContact(
                            name = c.getString("name"),
                            phone = c.getString("phone"),
                            countryCode = c.optString("countryCode", "IN"),
                            priority = c.getInt("priority")
                        ))
                    }
                    return@withContext list.sortedBy { it.priority }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to fetch emergency contacts: ${e.message}")
        }
        emptyList()
    }
    
    private suspend fun triggerSOSAPI() = withContext(Dispatchers.IO) {
        try {
            if (authToken == null) return@withContext
            val url = URL("$serverUrl/api/sos/trigger")
            val connection = url.openConnection() as HttpURLConnection
            connection.apply {
                requestMethod = "POST"
                setRequestProperty("Authorization", "Bearer $authToken")
                doOutput = true
            }
            Log.d(TAG, "📡 Local SOS API Response: ${connection.responseCode}")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed calling SOS API: ${e.message}")
        }
    }
    
    private fun makeEmergencyCall(phone: String, countryCode: String) {
        try {
            val formatted = formatNumber(phone, countryCode)
            val intent = Intent(Intent.ACTION_CALL).apply {
                data = android.net.Uri.parse("tel:$formatted")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Call failed: ${e.message}")
        }
    }
    
    private fun sendEmergencySMS(phone: String, countryCode: String) {
        try {
            val formatted = formatNumber(phone, countryCode)
            val message = "🚨 EMERGENCY: Automated SOS Alert. Vocal distress matching emergency keywords detected. Call me back immediately!"
            val smsManager = android.telephony.SmsManager.getDefault()
            val parts = smsManager.divideMessage(message)
            smsManager.sendMultipartTextMessage(formatted, null, parts, null, null)
        } catch (e: Exception) {
            Log.e(TAG, "❌ SMS failed: ${e.message}")
        }
    }
    
    private fun formatNumber(phone: String, countryCode: String): String {
        return when {
            phone.startsWith("+") -> phone
            countryCode == "IN" -> "+91$phone"
            else -> "+$countryCode$phone"
        }
    }
    
    private fun getLocationUrl(): String? {
        return try {
            val lm = getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
            val loc = lm.getLastKnownLocation(android.location.LocationManager.GPS_PROVIDER)
                ?: lm.getLastKnownLocation(android.location.LocationManager.NETWORK_PROVIDER)
            loc?.let { "https://maps.google.com/?q=${it.latitude},${it.longitude}" }
        } catch (e: Exception) {
            null
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        isMonitoring = false
        monitoringJob?.cancel()
        
        try {
            wakeWordEngine?.stop()
            wakeWordEngine?.release()
        } catch (e: Exception) {
            Log.w(TAG, "Error releasing wakeWordEngine: ${e.message}")
        }
        wakeWordEngine = null
        
        serviceScope.cancel()
        Log.d(TAG, "🛑 WakeWordDetectorService destroyed")
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    data class EmergencyContact(
        val name: String,
        val phone: String,
        val countryCode: String,
        val priority: Int
    )
}
