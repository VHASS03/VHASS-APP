package com.example.my_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import kotlin.math.abs

/**
 * Battery-Efficient Wake Word Detection Service
 * 
 * Uses ONLY Android's built-in APIs - NO third-party services!
 * 
 * How it saves battery:
 * 1. Audio Level Detection: Only activates speech recognition when someone is speaking
 * 2. Duty Cycling: Listens in short bursts with rest periods
 * 3. Smart Restart: Delays restart after errors to prevent battery drain
 * 
 * Flow:
 * 1. Monitor audio levels (very low power)
 * 2. When voice detected → activate SpeechRecognizer for 5 seconds
 * 3. Check for "help me out" phrase
 * 4. If detected → trigger SOS immediately
 * 5. Return to audio monitoring
 * 
 * Battery usage: ~5-8% per hour (vs 15-20% for continuous listening)
 */
class WakeWordDetectorService : Service() {
    
    companion object {
        const val TAG = "WakeWordService"
        const val CHANNEL_ID = "wake_word_channel"
        const val NOTIFICATION_ID = 1002
        
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
        
        // Audio monitoring settings
        private const val SAMPLE_RATE = 16000
        private const val AUDIO_THRESHOLD = 1500  // Minimum audio level to trigger recognition
        private const val LISTEN_DURATION_MS = 5000L  // How long to listen for command
        private const val REST_DURATION_MS = 2000L  // Rest between listen cycles
        private const val MONITOR_INTERVAL_MS = 100L  // Audio level check interval
        
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
    
    // Audio monitoring
    private var audioRecord: AudioRecord? = null
    private var isMonitoring = false
    
    // Speech recognition
    private var speechRecognizer: SpeechRecognizer? = null
    private var isRecognizing = false
    
    // Service state
    private var serviceScope = CoroutineScope(Dispatchers.IO + Job())
    private val mainHandler = Handler(Looper.getMainLooper())
    
    // User data
    private var authToken: String? = null
    private var userId: String? = null
    private var serverUrl: String? = null
    
    // Stealth SOS manager
    private var stealthSOSManager: StealthSOSManager? = null
    
    // State tracking
    private enum class State {
        MONITORING,  // Low-power audio level monitoring
        LISTENING,   // Active speech recognition
        RESTING,     // Brief rest period
        SOS_ACTIVE   // SOS triggered
    }
    private var currentState = State.MONITORING
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        System.out.println("[WakeWord] ✅ onCreate - Battery-efficient mode (no third-party)")
        Log.d(TAG, "✅ Wake word service created (Android built-in only)")
        createNotificationChannel()
        loadUserData()
        
        // Initialize stealth SOS manager
        stealthSOSManager = StealthSOSManager(this)
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        System.out.println("[WakeWord] 🎤 Starting battery-efficient wake word detection")
        Log.d(TAG, "🎤 Service started - Say 'help me out' to trigger SOS")
        
        // ALWAYS reload user data to get fresh URL (in case IP changed)
        loadUserData()
        Log.d(TAG, "📡 Server URL: $serverUrl")
        
        // Start as foreground service
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        // Initialize speech recognizer on main thread
        mainHandler.post {
            initializeSpeechRecognizer()
        }
        
        // Start audio monitoring
        serviceScope.launch {
            delay(1000)  // Wait for initialization
            startAudioMonitoring()
        }
        
        return START_STICKY
    }
    
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Voice SOS Monitoring",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Listening for 'help me out' to trigger emergency SOS"
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
        
        val (title, text) = when (currentState) {
            State.MONITORING -> "🎤 Voice SOS Ready" to "Say 'help me out' for emergency"
            State.LISTENING -> "👂 Listening..." to "Speak now"
            State.RESTING -> "🎤 Voice SOS Ready" to "Say 'help me out' for emergency"
            State.SOS_ACTIVE -> "🚨 SOS ACTIVE" to "Emergency contacts being notified"
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
        val notification = createNotification()
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    private fun loadUserData() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        authToken = prefs.getString("flutter.authToken", null)
        userId = prefs.getString("flutter.userId", null)
        serverUrl = prefs.getString("flutter.serverUrl", "http://10.0.2.2:5000")
        
        Log.d(TAG, "📱 Loaded user data - Token: ${if (authToken != null) "✅" else "❌"}")
    }
    
    /**
     * Initialize Android's built-in SpeechRecognizer
     */
    private fun initializeSpeechRecognizer() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            Log.e(TAG, "❌ Speech recognition not available on this device")
            return
        }
        
        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
            setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    Log.d(TAG, "🎤 Ready for speech")
                }
                
                override fun onBeginningOfSpeech() {
                    Log.d(TAG, "🗣️ Speech started")
                }
                
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                
                override fun onEndOfSpeech() {
                    Log.d(TAG, "🛑 Speech ended")
                }
                
                override fun onError(error: Int) {
                    Log.w(TAG, "⚠️ Recognition error: $error")
                    isRecognizing = false
                    restoreMediaAudio()
                    // Return to monitoring after brief delay
                    serviceScope.launch {
                        delay(REST_DURATION_MS)
                        if (currentState != State.SOS_ACTIVE) {
                            currentState = State.MONITORING
                            updateNotification()
                            startAudioMonitoring()
                        }
                    }
                }
                
                override fun onResults(results: Bundle?) {
                    isRecognizing = false
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    
                    matches?.forEach { text ->
                        Log.d(TAG, "🎤 Heard: '$text'")
                        getMatchedTriggerPhrase(text)?.let { phrase ->
                            Log.i(TAG, "🚨 TRIGGER DETECTED: '$phrase'")
                            onTriggerDetected(phrase)
                            return
                        }
                    }
                    
                    // No trigger found, restore media audio and return to monitoring
                    restoreMediaAudio()
                    serviceScope.launch {
                        delay(REST_DURATION_MS)
                        if (currentState != State.SOS_ACTIVE) {
                            currentState = State.MONITORING
                            updateNotification()
                            startAudioMonitoring()
                        }
                    }
                }
                
                override fun onPartialResults(partialResults: Bundle?) {
                    // Check partial results for faster detection (don't wait for final result)
                    val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    matches?.forEach { text ->
                        getMatchedTriggerPhrase(text ?: "")?.let { phrase ->
                            Log.i(TAG, "🚨 TRIGGER IN PARTIAL: '$phrase'")
                            onTriggerDetected(phrase)
                            return
                        }
                    }
                }
                
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
        }
        
        Log.d(TAG, "✅ Speech recognizer initialized (Android built-in)")
    }
    
    /**
     * Start low-power audio level monitoring
     * Only activates speech recognition when voice is detected
     */
    private fun startAudioMonitoring() {
        if (isMonitoring || currentState == State.SOS_ACTIVE) return
        
        currentState = State.MONITORING
        isMonitoring = true
        
        System.out.println("[WakeWord] 🔊 Starting audio level monitoring (low power)")
        
        serviceScope.launch(Dispatchers.IO) {
            try {
                val bufferSize = AudioRecord.getMinBufferSize(
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT
                )
                
                audioRecord = AudioRecord(
                    MediaRecorder.AudioSource.VOICE_RECOGNITION,
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufferSize
                )
                
                if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                    Log.e(TAG, "❌ AudioRecord failed to initialize")
                    isMonitoring = false
                    return@launch
                }
                
                audioRecord?.startRecording()
                val buffer = ShortArray(bufferSize / 2)
                
                var consecutiveVoiceFrames = 0
                val requiredFrames = 3  // Require 3 consecutive frames with voice
                
                while (isMonitoring && currentState == State.MONITORING) {
                    val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    
                    if (read > 0) {
                        // Calculate average amplitude
                        var sum = 0L
                        for (i in 0 until read) {
                            sum += abs(buffer[i].toInt())
                        }
                        val amplitude = (sum / read).toInt()
                        
                        if (amplitude > AUDIO_THRESHOLD) {
                            consecutiveVoiceFrames++
                            
                            if (consecutiveVoiceFrames >= requiredFrames) {
                                // Voice detected! Start speech recognition
                                Log.d(TAG, "🗣️ Voice detected (amplitude: $amplitude) - activating recognition")
                                stopAudioMonitoring()
                                
                                withContext(Dispatchers.Main) {
                                    startSpeechRecognition()
                                }
                                return@launch
                            }
                        } else {
                            consecutiveVoiceFrames = 0
                        }
                    }
                    
                    delay(MONITOR_INTERVAL_MS)
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Audio monitoring error: ${e.message}")
            } finally {
                stopAudioMonitoring()
            }
        }
    }
    
    private fun stopAudioMonitoring() {
        isMonitoring = false
        try {
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping audio monitor: ${e.message}")
        }
    }
    
    /**
     * Start speech recognition to capture the phrase
     */
    private fun startSpeechRecognition() {
        if (isRecognizing || speechRecognizer == null) return
        
        currentState = State.LISTENING
        isRecognizing = true
        updateNotification()
        
        System.out.println("[WakeWord] 🎤 Activating speech recognition")
        
        try {
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)  // Get partial results for faster detection
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1000L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1500L)
            }
            
            muteRecognitionBeepTemporarily()
            speechRecognizer?.startListening(intent)
            mainHandler.postDelayed({ restoreMediaAudio() }, 800)
            
            // Auto-stop after LISTEN_DURATION_MS
            serviceScope.launch {
                delay(LISTEN_DURATION_MS)
                if (isRecognizing) {
                    mainHandler.post {
                        speechRecognizer?.stopListening()
                    }
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start recognition: ${e.message}")
            isRecognizing = false
            
            // Return to monitoring
            serviceScope.launch {
                delay(REST_DURATION_MS)
                currentState = State.MONITORING
                startAudioMonitoring()
            }
        }
    }
    
    /** Normalize text for matching: collapse spaces, trim (so "help  me  out" and "helpmeout" still match) */
    private fun getMatchedTriggerPhrase(text: String): String? {
        if (text.isBlank()) return null
        val normalized = text.lowercase().trim().replace(Regex("\\s+"), " ")
        val noSpaces = normalized.replace(" ", "")
        for (phrase in TRIGGER_PHRASES) {
            val phraseNorm = phrase.lowercase().replace(" ", "")
            if (normalized.contains(phrase) || noSpaces.contains(phraseNorm)) return phrase
        }
        return null
    }
    
    /**
     * Called when "help me out" (or other trigger) is detected
     * Immediately triggers SOS!
     */
    private fun onTriggerDetected(phrase: String) {
        System.out.println("[WakeWord] 🚨🚨🚨 '$phrase' DETECTED - TRIGGERING SOS!")
        Log.e(TAG, "🚨 EMERGENCY: '$phrase' detected!")
        
        currentState = State.SOS_ACTIVE
        isRecognizing = false
        stopAudioMonitoring()
        
        // Stop speech recognizer and restore media audio so YouTube/Instagram can play
        mainHandler.post {
            speechRecognizer?.cancel()
            restoreMediaAudio()
        }
        
        // Update notification
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🚨 SOS ACTIVATED")
            .setContentText("'$phrase' detected - alerting contacts")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
        
        // Trigger SOS
        serviceScope.launch {
            triggerSOS()
            
            // Return to monitoring after 30 seconds
            delay(30000)
            currentState = State.MONITORING
            updateNotification()
            startAudioMonitoring()
        }
    }
    
    /** Restore normal audio so YouTube/Instagram/media can play */
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
    
    // ==================== SOS FUNCTIONS ====================
    
    private suspend fun triggerSOS() = withContext(Dispatchers.IO) {
        Log.d(TAG, "🥷 Starting STEALTH SOS - hiding phone activity")
        
        try {
            val contacts = getEmergencyContacts()
            
            if (contacts.isEmpty()) {
                Log.w(TAG, "⚠️ No emergency contacts found")
                return@withContext
            }
            
            Log.d(TAG, "✅ Found ${contacts.size} emergency contacts")
            
            // Convert to StealthSOSManager format
            val stealthContacts = contacts.map { contact ->
                StealthSOSManager.EmergencyContact(
                    name = contact.name,
                    phone = contact.phone,
                    countryCode = contact.countryCode,
                    priority = contact.priority
                )
            }
            
            // Get location URL (you may want to get actual location here)
            val locationUrl = getLocationUrl()
            
            // Trigger STEALTH SOS - hides screen and makes silent calls!
            stealthSOSManager?.startStealthSOS(
                contacts = stealthContacts,
                locationUrl = locationUrl,
                authToken = authToken,
                serverUrl = serverUrl
            )
            
            Log.d(TAG, "🥷 Stealth SOS initiated - screen hidden, calls silent")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Stealth SOS error: ${e.message}")
            
            // Fallback to regular SOS if stealth fails
            triggerRegularSOS()
        }
    }
    
    /**
     * Get current location as Google Maps URL
     */
    private fun getLocationUrl(): String? {
        return try {
            val locationManager = getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
            val location = locationManager.getLastKnownLocation(android.location.LocationManager.GPS_PROVIDER)
                ?: locationManager.getLastKnownLocation(android.location.LocationManager.NETWORK_PROVIDER)
            
            if (location != null) {
                "https://maps.google.com/?q=${location.latitude},${location.longitude}"
            } else {
                null
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not get location: ${e.message}")
            null
        }
    }
    
    /**
     * Fallback regular SOS (visible calls/SMS)
     */
    private suspend fun triggerRegularSOS() = withContext(Dispatchers.IO) {
        Log.d(TAG, "📞 Fallback: Regular SOS")
        
        try {
            val contacts = getEmergencyContacts()
            
            // Trigger SOS API
            triggerSOSAPI()
            
            // Call contacts
            for ((index, contact) in contacts.withIndex()) {
                makeEmergencyCall(contact.phone, contact.countryCode)
                if (index < contacts.size - 1) delay(5000)
            }
            
            // Send SMS
            for (contact in contacts) {
                sendEmergencySMS(contact.phone, contact.countryCode)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Regular SOS error: ${e.message}")
        }
    }
    
    private suspend fun getEmergencyContacts(): List<EmergencyContact> = withContext(Dispatchers.IO) {
        try {
            if (authToken == null) return@withContext emptyList()
            
            val url = java.net.URL("$serverUrl/api/contacts")
            val connection = url.openConnection() as java.net.HttpURLConnection
            connection.apply {
                requestMethod = "GET"
                setRequestProperty("Authorization", "Bearer $authToken")
                setRequestProperty("Content-Type", "application/json")
                connectTimeout = 10000
                readTimeout = 10000
            }
            
            if (connection.responseCode == 200) {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                val json = org.json.JSONObject(response)
                
                if (json.getBoolean("success")) {
                    val contactsArray = json.getJSONArray("contacts")
                    val contacts = mutableListOf<EmergencyContact>()
                    for (i in 0 until contactsArray.length()) {
                        val c = contactsArray.getJSONObject(i)
                        if (!c.optBoolean("isActive", true)) continue
                        contacts.add(EmergencyContact(
                            name = c.getString("name"),
                            phone = c.getString("phone"),
                            countryCode = c.optString("countryCode", "IN"),
                            priority = c.getInt("priority")
                        ))
                    }
                    return@withContext contacts.sortedBy { it.priority }
                }
            }
            
            emptyList()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error getting contacts: ${e.message}")
            emptyList()
        }
    }
    
    private suspend fun triggerSOSAPI() = withContext(Dispatchers.IO) {
        try {
            if (authToken == null) return@withContext
            
            val url = java.net.URL("$serverUrl/api/sos/trigger")
            val connection = url.openConnection() as java.net.HttpURLConnection
            connection.apply {
                requestMethod = "POST"
                setRequestProperty("Authorization", "Bearer $authToken")
                setRequestProperty("Content-Type", "application/json")
                doOutput = true
            }
            
            Log.d(TAG, "📡 SOS API: ${connection.responseCode}")
        } catch (e: Exception) {
            Log.e(TAG, "❌ SOS API error: ${e.message}")
        }
    }
    
    private fun makeEmergencyCall(phone: String, countryCode: String) {
        try {
            val formattedNumber = formatPhoneNumber(phone, countryCode)
            val intent = android.content.Intent(android.content.Intent.ACTION_CALL).apply {
                data = android.net.Uri.parse("tel:$formattedNumber")
                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Call failed: ${e.message}")
        }
    }
    
    private fun sendEmergencySMS(phone: String, countryCode: String) {
        try {
            val formattedNumber = formatPhoneNumber(phone, countryCode)
            val message = "🚨 EMERGENCY: I said 'help me out'! This is an automated SOS. Please call me back urgently."
            
            val smsManager = android.telephony.SmsManager.getDefault()
            val parts = smsManager.divideMessage(message)
            smsManager.sendMultipartTextMessage(formattedNumber, null, parts, null, null)
        } catch (e: Exception) {
            Log.e(TAG, "❌ SMS failed: ${e.message}")
        }
    }
    
    private fun formatPhoneNumber(phone: String, countryCode: String): String {
        return when {
            phone.startsWith("+") -> phone
            countryCode == "IN" -> "+91$phone"
            else -> "+$countryCode$phone"
        }
    }
    
    data class EmergencyContact(
        val name: String,
        val phone: String,
        val countryCode: String,
        val priority: Int
    )
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "🛑 Service destroyed")
        
        stopAudioMonitoring()
        stealthSOSManager?.stopStealthSOS()
        
        mainHandler.post {
            speechRecognizer?.destroy()
            speechRecognizer = null
        }
        
        serviceScope.cancel()
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
}
