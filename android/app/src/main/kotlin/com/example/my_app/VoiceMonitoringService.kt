package com.example.my_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.NotificationCompat
import android.util.Log
import android.net.Uri
import android.telephony.SmsManager
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.*

/**
 * Background Voice Monitoring Service
 * Continuously listens for "help me out" phrase even when app is closed
 * Automatically triggers SOS mode without showing UI
 */
class VoiceMonitoringService : Service() {
    
    companion object {
        const val TAG = "VoiceMonitoringService"
        const val CHANNEL_ID = "voice_monitoring_channel"
        const val NOTIFICATION_ID = 1001
        
        // Trigger phrases
        private val TRIGGER_PHRASES = listOf(
            "help me out",
            "help me",
            "emergency",
            "sos"
        )
        
        fun startService(context: Context) {
            val intent = Intent(context, VoiceMonitoringService::class.java)
            context.startForegroundService(intent)
            Log.d(TAG, "🚀 Starting voice monitoring service")
        }
        
        fun stopService(context: Context) {
            val intent = Intent(context, VoiceMonitoringService::class.java)
            context.stopService(intent)
            Log.d(TAG, "🛑 Stopping voice monitoring service")
        }
    }
    
    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private var serviceScope = CoroutineScope(Dispatchers.IO + Job())
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isStarting = false
    private var pendingRestart = false
    private var lastRestartTime = 0L
    
    // User data from shared preferences
    private var authToken: String? = null
    private var userId: String? = null
    private var serverUrl: String? = null
    
    override fun onCreate() {
        super.onCreate()
        System.out.println("[VoiceService] ✅ onCreate called")
        Log.d(TAG, "✅ Voice monitoring service created")
        createNotificationChannel()
        loadUserData()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        System.out.println("[VoiceService] 🎤 onStartCommand called")
        Log.d(TAG, "🎤 Service started - Beginning voice monitoring")
        
        // Start as foreground service with persistent notification
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        System.out.println("[VoiceService] ✅ Foreground service started")
        
        // Delay initialization to ensure main looper is ready
        mainHandler.postDelayed({
            System.out.println("[VoiceService] 🔧 Initializing speech recognizer...")
            initializeSpeechRecognizer()
            mainHandler.postDelayed({
                System.out.println("[VoiceService] 🎤 Starting listening...")
                startListening()
            }, 500)
        }, 1000)
        
        // Return START_STICKY to restart service if killed
        return START_STICKY
    }
    
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Voice SOS Monitoring",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Continuously monitoring for emergency voice commands"
            setShowBadge(false)
        }
        
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannel(channel)
    }
    
    private fun createNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🎤 Voice SOS Active")
            .setContentText("Say 'help me out' for emergency")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    private fun loadUserData() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        authToken = prefs.getString("flutter.authToken", null)
        userId = prefs.getString("flutter.userId", null)
        serverUrl = prefs.getString("flutter.serverUrl", "http://10.0.2.2:5000")
        
        Log.d(TAG, "📱 Loaded user data - Token: ${if (authToken != null) "✅" else "❌"}")
    }
    
    private fun initializeSpeechRecognizer() {
        mainHandler.post {
            System.out.println("[VoiceService] 🔧 initializeSpeechRecognizer - checking availability...")
            if (!SpeechRecognizer.isRecognitionAvailable(this)) {
                System.out.println("[VoiceService] ❌ Speech recognition NOT available")
                Log.e(TAG, "❌ Speech recognition not available")
                return@post
            }
            
            System.out.println("[VoiceService] ✅ Speech recognition IS available")
            
            // Clean up any previous recognizer before creating new one
            speechRecognizer?.destroy()
            speechRecognizer = null
            pendingRestart = false
            isStarting = false

            System.out.println("[VoiceService] 🏗️ Creating SpeechRecognizer...")
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
                setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    Log.d(TAG, "🎤 Ready for speech")
                }
                
                override fun onBeginningOfSpeech() {
                    Log.d(TAG, "🗣️ Speech started")
                }
                
                override fun onRmsChanged(rmsdB: Float) {
                    // Volume level changed
                }
                
                override fun onBufferReceived(buffer: ByteArray?) {}
                
                override fun onEndOfSpeech() {
                    Log.d(TAG, "🛑 Speech ended")
                }
                
                override fun onError(error: Int) {
                    Log.w(TAG, "⚠️ Speech error: $error")
                    handleSpeechError(error)
                }
                
                override fun onResults(results: Bundle?) {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    matches?.forEach { text ->
                        Log.d(TAG, "🎤 Heard: '$text'")
                        checkForTriggerPhrase(text)
                    }
                    
                    // Continue listening
                    serviceScope.launch {
                        delay(500)
                        if (isListening) {
                            startListening()
                        }
                    }
                }
                
                override fun onPartialResults(partialResults: Bundle?) {}
                
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
            }
            
            System.out.println("[VoiceService] ✅ Speech recognizer initialized successfully")
            Log.d(TAG, "✅ Speech recognizer initialized")
        }
    }
    
    private fun startListening() {
        System.out.println("[VoiceService] 🎤 startListening called, recognizer=${speechRecognizer != null}, isListening=$isListening, isStarting=$isStarting")
        if (speechRecognizer == null) {
            // If recognizer not yet ready, initialize and retry shortly
            initializeSpeechRecognizer()
            serviceScope.launch {
                delay(300)
                if (isListening) {
                    startListening()
                }
            }
            return
        }
        if (!isListening) {
            isListening = true
        }
        if (isStarting) {
            return
        }
        isStarting = true
        
        // Must run on main thread
        mainHandler.post {
            try {
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                }
                
                speechRecognizer?.startListening(intent)
                Log.d(TAG, "🎤 Listening started...")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to start listening: ${e.message}")
            } finally {
                isStarting = false
            }
        }
    }
    
    private fun stopListening() {
        if (!isListening && speechRecognizer == null) return
        isListening = false
        // Must run on main thread
        mainHandler.post {
            speechRecognizer?.cancel()
            speechRecognizer?.stopListening()
            Log.d(TAG, "🛑 Listening stopped")
        }
    }
    
    private fun checkForTriggerPhrase(text: String) {
        val lowerText = text.lowercase()
        
        for (phrase in TRIGGER_PHRASES) {
            if (lowerText.contains(phrase)) {
                Log.w(TAG, "🚨 TRIGGER DETECTED: '$phrase' in '$text'")
                onTriggerDetected()
                return
            }
        }
    }
    
    /**
     * Called when trigger phrase is detected
     * Automatically initiates SOS without showing UI
     */
    private fun onTriggerDetected() {
        Log.e(TAG, "🚨🚨🚨 EMERGENCY TRIGGER DETECTED - Initiating headless SOS")
        
        // Update notification to show SOS is active
        updateNotificationToSOSActive()
        
        // Trigger SOS in background
        serviceScope.launch {
            try {
                triggerHeadlessSOS()
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error triggering headless SOS: ${e.message}")
            }
        }
    }

    /**
     * Handle speech errors with debounced restart to avoid binder flood
     */
    private fun handleSpeechError(error: Int) {
        // Typical busy/no match codes: 5=BUSY, 7=NO_MATCH
        val now = SystemClock.elapsedRealtime()
        val minGapMs = 3500L
        if (pendingRestart) return
        if (now - lastRestartTime < minGapMs) {
            // Too soon to restart; wait and try once
            pendingRestart = true
            val wait = minGapMs - (now - lastRestartTime)
            serviceScope.launch {
                delay(wait)
                pendingRestart = false
                handleSpeechError(error)
            }
            return
        }

        pendingRestart = true
        isListening = false
        mainHandler.post {
            speechRecognizer?.cancel()
            speechRecognizer?.stopListening()
        }
        serviceScope.launch {
            delay(1200)
            // Recreate recognizer to clear BUSY state
            mainHandler.post {
                speechRecognizer?.destroy()
                speechRecognizer = null
            }
            delay(200)
            initializeSpeechRecognizer()
            delay(400)
            isListening = true
            startListening()
            lastRestartTime = SystemClock.elapsedRealtime()
            pendingRestart = false
        }
    }
    
    private fun updateNotificationToSOSActive() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🚨 SOS ACTIVE")
            .setContentText("Emergency contacts being notified")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    /**
     * Trigger SOS without showing any UI
     * Calls contacts and sends SMS in background
     */
    private suspend fun triggerHeadlessSOS() = withContext(Dispatchers.IO) {
        Log.d(TAG, "📞 Starting headless SOS trigger")
        
        // 1. Get emergency contacts
        val contacts = getEmergencyContacts()
        
        if (contacts.isEmpty()) {
            Log.w(TAG, "⚠️ No emergency contacts found")
            return@withContext
        }
        
        Log.d(TAG, "✅ Found ${contacts.size} emergency contacts")
        
        // 2. Trigger SOS API
        triggerSOSAPI()
        
        // 3. Call contacts sequentially
        for ((index, contact) in contacts.withIndex()) {
            Log.d(TAG, "📞 Calling contact ${index + 1}: ${contact.name}")
            makeEmergencyCall(contact.phone, contact.countryCode)
            
            // Wait 5 seconds before next call
            if (index < contacts.size - 1) {
                delay(5000)
            }
        }
        
        // 4. Send SMS to all contacts
        for (contact in contacts) {
            Log.d(TAG, "📱 Sending SMS to: ${contact.name}")
            sendEmergencySMS(contact.phone, contact.countryCode)
        }
        
        Log.d(TAG, "✅ Headless SOS completed - Contacts notified")
    }
    
    private suspend fun getEmergencyContacts(): List<EmergencyContact> = withContext(Dispatchers.IO) {
        try {
            if (authToken == null) {
                Log.e(TAG, "❌ No auth token available")
                return@withContext emptyList()
            }
            
            val url = URL("$serverUrl/api/contacts")
            val connection = url.openConnection() as HttpURLConnection
            connection.apply {
                requestMethod = "GET"
                setRequestProperty("Authorization", "Bearer $authToken")
                setRequestProperty("Content-Type", "application/json")
                connectTimeout = 10000
                readTimeout = 10000
            }
            
            val responseCode = connection.responseCode
            if (responseCode == 200) {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(response)
                
                if (json.getBoolean("success")) {
                    // Fix: API returns "contacts" field, not "data"
                    val contactsArray = json.getJSONArray("contacts")
                    val contacts = mutableListOf<EmergencyContact>()
                    
                    for (i in 0 until contactsArray.length()) {
                        val contactJson = contactsArray.getJSONObject(i)
                        contacts.add(
                            EmergencyContact(
                                name = contactJson.getString("name"),
                                phone = contactJson.getString("phone"),
                                countryCode = contactJson.optString("countryCode", "IN"),
                                priority = contactJson.getInt("priority")
                            )
                        )
                    }
                    
                    contacts.sortBy { it.priority }
                    return@withContext contacts
                }
            }
            
            Log.e(TAG, "❌ Failed to get contacts: $responseCode")
            return@withContext emptyList()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error getting contacts: ${e.message}")
            return@withContext emptyList()
        }
    }
    
    private suspend fun triggerSOSAPI() = withContext(Dispatchers.IO) {
        try {
            if (authToken == null) {
                Log.e(TAG, "❌ No auth token for SOS API")
                return@withContext
            }
            
            val url = URL("$serverUrl/api/sos/trigger")
            val connection = url.openConnection() as HttpURLConnection
            connection.apply {
                requestMethod = "POST"
                setRequestProperty("Authorization", "Bearer $authToken")
                setRequestProperty("Content-Type", "application/json")
                doOutput = true
            }
            
            val responseCode = connection.responseCode
            Log.d(TAG, "📡 SOS API response: $responseCode")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error triggering SOS API: ${e.message}")
        }
    }
    
    private fun makeEmergencyCall(phone: String, countryCode: String) {
        try {
            val formattedNumber = if (phone.startsWith("+")) {
                phone
            } else if (countryCode == "IN") {
                "+91$phone"
            } else {
                "+$countryCode$phone"
            }
            
            val intent = Intent(Intent.ACTION_CALL).apply {
                data = Uri.parse("tel:$formattedNumber")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            
            startActivity(intent)
            Log.d(TAG, "📞 Call initiated to: ${maskNumberForLog(formattedNumber)}")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to make call: ${e.message}")
        }
    }
    
    private fun sendEmergencySMS(phone: String, countryCode: String) {
        try {
            val formattedNumber = if (phone.startsWith("+")) {
                phone
            } else if (countryCode == "IN") {
                "+91$phone"
            } else {
                "+$countryCode$phone"
            }
            
            val message = "🚨 EMERGENCY: I need immediate help! This is an automated SOS alert. Please call me back urgently."
            
            val smsManager = SmsManager.getDefault()
            val parts = smsManager.divideMessage(message)
            smsManager.sendMultipartTextMessage(formattedNumber, null, parts, null, null)
            
            Log.d(TAG, "📱 SMS sent to: ${maskNumberForLog(formattedNumber)}")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to send SMS: ${e.message}")
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
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "🛑 Service destroyed")
        stopListening()
        mainHandler.post {
            speechRecognizer?.destroy()
            speechRecognizer = null
        }
        serviceScope.cancel()
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    /**
     * Emergency contact data class
     */
    data class EmergencyContact(
        val name: String,
        val phone: String,
        val countryCode: String,
        val priority: Int
    )
}
