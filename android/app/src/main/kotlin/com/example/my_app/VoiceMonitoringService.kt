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
import android.media.AudioManager
import android.util.Log
import android.net.Uri
import android.telephony.SmsManager
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import kotlinx.coroutines.*

/**
 * Background Voice Monitoring Service
 * 
 * Now supports two modes:
 * 1. CONTINUOUS: Old behavior - always listening (high battery drain)
 * 2. SINGLE_COMMAND: New mode - listens for one command then stops (used with wake word)
 * 
 * When used with WakeWordDetectorService, this only activates AFTER 
 * the wake word is detected, saving significant battery.
 */
class VoiceMonitoringService : Service() {
    
    companion object {
        const val TAG = "VoiceMonitoringService"
        const val CHANNEL_ID = "voice_monitoring_channel"
        const val NOTIFICATION_ID = 1001
        
        // Trigger phrases (expanded so "help me out" is recognised more easily)
        private val TRIGGER_PHRASES = listOf(
            "help me out",
            "help me",
            "helpmeout",
            "helpmout",
            "help me out please",
            "help me out now",
            "emergency",
            "sos",
            "i need help"
        )
        
        private var instance: VoiceMonitoringService? = null
        
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
        
        fun isRunning(): Boolean = instance != null
    }
    
    // Operation mode
    private enum class Mode {
        CONTINUOUS,      // Old behavior - always listening (battery drain)
        SINGLE_COMMAND   // New mode - listen for one command then stop
    }
    private var currentMode = Mode.CONTINUOUS
    private var commandTimeout: Long = 0L
    
    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private var serviceScope = CoroutineScope(Dispatchers.IO + Job())
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isStarting = false
    private var pendingRestart = false
    private var lastRestartTime = 0L
    
    // Timeout job for single command mode
    private var timeoutJob: Job? = null
    
    // Debounce: ignore repeat trigger within this window (e.g. "help me" + "help me out" in one utterance)
    private var lastTriggerTime = 0L
    private val TRIGGER_DEBOUNCE_MS = 60_000L
    
    // User data from shared preferences
    private var authToken: String? = null
    private var userId: String? = null
    private var serverUrl: String? = null
    
    // Stealth SOS Manager for hidden emergency calls
    private var stealthSOSManager: StealthSOSManager? = null
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        System.out.println("[VoiceService] ✅ onCreate called")
        Log.d(TAG, "✅ Voice monitoring service created")
        createNotificationChannel()
        loadUserData()
        
        // Initialize stealth SOS manager
        stealthSOSManager = StealthSOSManager(this)
        Log.d(TAG, "🥷 StealthSOSManager initialized")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        System.out.println("[VoiceService] 🎤 onStartCommand called")
        
        // ALWAYS reload user data to get fresh URL (in case IP changed)
        loadUserData()
        Log.d(TAG, "📡 Server URL: $serverUrl")
        
        // Check if this is single command mode (triggered by wake word)
        val mode = intent?.getStringExtra("mode")
        commandTimeout = intent?.getLongExtra("timeout", 0L) ?: 0L
        
        if (mode == "single_command") {
            currentMode = Mode.SINGLE_COMMAND
            Log.d(TAG, "🎤 Single command mode - listening for ${commandTimeout}ms")
            System.out.println("[VoiceService] 🎤 Single command mode activated")
            
            // Set timeout to stop listening
            if (commandTimeout > 0) {
                timeoutJob?.cancel()
                timeoutJob = serviceScope.launch {
                    delay(commandTimeout)
                    if (currentMode == Mode.SINGLE_COMMAND) {
                        System.out.println("[VoiceService] ⏱️ Command timeout reached")
                        withContext(Dispatchers.Main) {
                            stopSelf()
                        }
                    }
                }
            }
        } else {
            currentMode = Mode.CONTINUOUS
            Log.d(TAG, "🎤 Continuous mode - always listening (consider using wake word for battery saving)")
        }
        
        // Start as foreground service with persistent notification
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        System.out.println("[VoiceService] ✅ Foreground service started in ${currentMode} mode")
        
        // Delay initialization to ensure main looper is ready
        mainHandler.postDelayed({
            System.out.println("[VoiceService] 🔧 Initializing speech recognizer...")
            initializeSpeechRecognizer()
            mainHandler.postDelayed({
                System.out.println("[VoiceService] 🎤 Starting listening...")
                startListening()
            }, 500)
        }, 1000)
        
        // Return START_STICKY only for continuous mode
        return if (currentMode == Mode.CONTINUOUS) START_STICKY else START_NOT_STICKY
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
        
        val (title, text) = when (currentMode) {
            Mode.CONTINUOUS -> "🎤 Voice SOS Active" to "Say 'help me out' for emergency"
            Mode.SINGLE_COMMAND -> "👂 Listening for command" to "Say 'help me out' now"
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
                    var triggerFound = false
                    
                    matches?.forEach { text ->
                        Log.d(TAG, "🎤 Heard: '$text'")
                        if (checkForTriggerPhrase(text)) {
                            triggerFound = true
                        }
                    }
                    
                    // Handle based on mode
                    when (currentMode) {
                        Mode.CONTINUOUS -> {
                            // Continue listening after a longer gap so we don't constantly beep (and media can play between)
                            serviceScope.launch {
                                restoreMediaAudio()
                                delay(2000)
                                if (isListening) {
                                    startListening()
                                }
                            }
                        }
                        Mode.SINGLE_COMMAND -> {
                            // New behavior: Stop after processing (wake word service will restart detection)
                            if (triggerFound) {
                                // Trigger was found, SOS will be initiated
                                // WakeWordDetectorService will handle returning to wake word mode
                                Log.d(TAG, "✅ Command processed - trigger found, SOS initiated")
                            } else {
                                // No trigger found, notify WakeWordDetectorService
                                Log.d(TAG, "⚠️ No trigger phrase in speech, returning to wake word mode")
                            }
                            // Either way, stop this service
                            serviceScope.launch {
                                delay(500)
                                stopSelf()
                            }
                        }
                    }
                }
                
                override fun onPartialResults(partialResults: Bundle?) {
                    // Detect trigger from partial results so we don't have to wait for final result
                    val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    matches?.forEach { text ->
                        if (text.isNotBlank() && checkForTriggerPhrase(text)) {
                            Log.d(TAG, "🎤 Trigger from partial: '$text'")
                        }
                    }
                }
                
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
                muteRecognitionBeepTemporarily()
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 8)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                }
                
                speechRecognizer?.startListening(intent)
                Log.d(TAG, "🎤 Listening started...")
                // Restore media mode shortly after starting so YouTube/Instagram can keep playing while we listen
                mainHandler.postDelayed({ restoreMediaAudio() }, 800)
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
            restoreMediaAudio()
            Log.d(TAG, "🛑 Listening stopped")
        }
    }
    
    /** Restore normal audio so YouTube/Instagram/media can play (voice listening takes over otherwise) */
    private fun restoreMediaAudio() {
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            am?.mode = AudioManager.MODE_NORMAL
        } catch (e: Exception) {
            Log.w(TAG, "Could not restore audio mode: ${e.message}")
        }
    }
    
    /** Mute only notification/system for the recognition beep - do NOT mute STREAM_MUSIC so YouTube/Instagram keep playing */
    private fun muteRecognitionBeepTemporarily() {
        val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        try {
            @Suppress("DEPRECATION")
            am.setStreamMute(AudioManager.STREAM_NOTIFICATION, true)
            @Suppress("DEPRECATION")
            am.setStreamMute(AudioManager.STREAM_SYSTEM, true)
            mainHandler.postDelayed({
                try {
                    @Suppress("DEPRECATION")
                    am.setStreamMute(AudioManager.STREAM_NOTIFICATION, false)
                    @Suppress("DEPRECATION")
                    am.setStreamMute(AudioManager.STREAM_SYSTEM, false)
                } catch (e: Exception) { }
            }, 500)
        } catch (e: Exception) {
            Log.w(TAG, "Could not mute recognition beep: ${e.message}")
        }
    }
    
    /** Normalize text for matching: collapse spaces, trim, lowercase (so "help  me  out" still matches) */
    private fun normalizeForTrigger(text: String): String {
        return text.lowercase().trim().replace(Regex("\\s+"), " ")
    }
    
    private fun checkForTriggerPhrase(text: String): Boolean {
        val normalized = normalizeForTrigger(text)
        val noSpaces = normalized.replace(" ", "") // "help me out" -> "helpmeout" for recognizer that drops spaces
        
        for (phrase in TRIGGER_PHRASES) {
            val phraseNorm = phrase.lowercase().replace(" ", "")
            if (normalized.contains(phrase) || noSpaces.contains(phraseNorm)) {
                Log.w(TAG, "🚨 TRIGGER DETECTED: '$phrase' in '$text'")
                onTriggerDetected()
                return true
            }
        }
        return false
    }
    
    /**
     * Called when trigger phrase is detected
     * Uses StealthSOSManager to hide dialer and make silent calls
     */
    private fun onTriggerDetected() {
        val now = SystemClock.elapsedRealtime()
        if (now - lastTriggerTime < TRIGGER_DEBOUNCE_MS) {
            Log.w(TAG, "⚠️ Ignoring duplicate trigger (debounced) - SOS already initiated")
            return
        }
        lastTriggerTime = now
        
        Log.e(TAG, "🚨🚨🚨 EMERGENCY TRIGGER DETECTED - Initiating STEALTH SOS")
        
        // Update notification to show SOS is active
        updateNotificationToSOSActive()
        
        // Use StealthSOSManager for hidden SOS (dialer won't be visible!)
        serviceScope.launch {
            try {
                // Get emergency contacts once (avoid duplicate fetch in fallback)
                val contacts = getEmergencyContacts()
                
                if (contacts.isEmpty()) {
                    Log.w(TAG, "⚠️ No emergency contacts - falling back to old method")
                    triggerHeadlessSOS(preFetchedContacts = contacts)
                    return@launch
                }
                
                // Convert to StealthSOSManager format
                val stealthContacts = contacts.map { contact ->
                    StealthSOSManager.EmergencyContact(
                        name = contact.name,
                        phone = contact.phone,
                        countryCode = contact.countryCode,
                        priority = contact.priority
                    )
                }
                
                // Get location URL
                val locationUrl = getLocationUrl()
                
                Log.d(TAG, "🥷 Starting STEALTH SOS with ${stealthContacts.size} contacts")
                Log.d(TAG, "   📍 Location: ${locationUrl ?: "Not available"}")
                
                // Start stealth SOS - this will:
                // 1. Show BLACK SCREEN overlay (hides everything!)
                // 2. Make silent calls IMMEDIATELY (skip countdown for voice triggers)
                // 3. Send SMS with location
                // 4. Auto-redial if call is cut
                withContext(Dispatchers.Main) {
                    try {
                        stealthSOSManager?.startStealthSOS(
                            contacts = stealthContacts,
                            locationUrl = locationUrl,
                            authToken = authToken,
                            serverUrl = serverUrl,
                            skipCountdown = true  // Voice triggers execute immediately!
                        )
                        Log.d(TAG, "✅ Stealth SOS started successfully")
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Error starting stealth SOS: ${e.message}", e)
                        // Fallback to headless SOS (reuse already-fetched contacts)
                        Log.w(TAG, "⚠️ Falling back to headless SOS method")
                        triggerHeadlessSOS(preFetchedContacts = contacts)
                    }
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error triggering stealth SOS: ${e.message}", e)
                // Fallback to old method (fetch contacts once here; headless won't re-fetch if we pass null and it will fetch)
                triggerHeadlessSOS(preFetchedContacts = null)
            }
        }
    }
    
    /**
     * Get current location as Google Maps URL
     */
    private suspend fun getLocationUrl(): String? = withContext(Dispatchers.IO) {
        try {
            val locationManager = getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
            
            // Try GPS first, then network
            val location = try {
                locationManager.getLastKnownLocation(android.location.LocationManager.GPS_PROVIDER)
            } catch (e: SecurityException) {
                null
            } ?: try {
                locationManager.getLastKnownLocation(android.location.LocationManager.NETWORK_PROVIDER)
            } catch (e: SecurityException) {
                null
            }
            
            if (location != null) {
                val mapUrl = "https://maps.google.com/?q=${location.latitude},${location.longitude}"
                Log.d(TAG, "📍 Got location: $mapUrl")
                mapUrl
            } else {
                Log.w(TAG, "📍 No location available - GPS may be off")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "📍 Error getting location: ${e.message}")
            null
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
            restoreMediaAudio()
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
     * Calls contacts and sends SMS in background.
     * @param preFetchedContacts If non-null, use this list and do not fetch again (avoids duplicate timeouts).
     */
    private suspend fun triggerHeadlessSOS(preFetchedContacts: List<EmergencyContact>? = null) = withContext(Dispatchers.IO) {
        Log.d(TAG, "📞 Starting headless SOS trigger")
        
        // Use pre-fetched list when provided to avoid duplicate API call and timeout
        val contacts = preFetchedContacts ?: getEmergencyContacts()
        
        if (contacts.isEmpty()) {
            Log.w(TAG, "⚠️ No emergency contacts found")
            return@withContext
        }
        
        Log.d(TAG, "✅ Found ${contacts.size} emergency contacts")
        
        // 2. Trigger SOS API
        triggerSOSAPI()
        
        // 3. Call contacts one after another with no delay
        for ((index, contact) in contacts.withIndex()) {
            Log.d(TAG, "📞 Calling contact ${index + 1}: ${contact.name}")
            makeEmergencyCall(contact.phone, contact.countryCode)
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
                connectTimeout = 15000
                readTimeout = 15000
            }
            
            val responseCode = connection.responseCode
            if (responseCode == 200) {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(response)
                
                if (json.getBoolean("success")) {
                    val contactsArray = json.getJSONArray("contacts")
                    val contacts = mutableListOf<EmergencyContact>()
                    for (i in 0 until contactsArray.length()) {
                        val contactJson = contactsArray.getJSONObject(i)
                        val isActive = contactJson.optBoolean("isActive", true)
                        if (!isActive) continue
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
        } catch (e: SocketTimeoutException) {
            Log.e(TAG, "❌ Error getting contacts: timeout (server slow or unreachable)")
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
        instance = null
        Log.d(TAG, "🛑 Service destroyed")
        stopListening()
        timeoutJob?.cancel()
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
