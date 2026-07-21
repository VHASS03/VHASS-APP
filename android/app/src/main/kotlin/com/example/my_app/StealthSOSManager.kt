package com.example.my_app
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.telecom.TelecomManager
import android.telephony.SmsManager
import android.util.Log
import android.view.WindowManager
import kotlinx.coroutines.*

/**
 * Stealth SOS Manager with CANCELLATION SUPPORT
 * 
 * Handles emergency SOS in a way that's invisible to attackers,
 * but allows the legitimate user to cancel if accidentally triggered.
 * 
 * ⏱️ COUNTDOWN PROTECTION:
 * - 5 second countdown before SOS actually triggers
 * - User can cancel during countdown by tapping screen
 * - After countdown: triple-tap or volume up x3 to cancel
 * 
 * 🥷 STEALTH FEATURES:
 * 1. SCREEN HIDING - Black screen, looks like phone is off
 * 2. SILENT OPERATION - Muted for attacker, speakerphone for contact
 * 3. AUTO-REDIAL - If call is cut, retries up to 3 times
 * 4. BACKGROUND SMS - Location sent silently
 */
class StealthSOSManager(private val context: Context) {
    
    companion object {
        const val TAG = "StealthSOS"
        
        // How many times to retry calling if cut
        const val MAX_CALL_RETRIES = 3
        const val CALL_RETRY_DELAY_MS = 5000L
        
        // How long to wait before assuming call was cut
        const val CALL_CUT_DETECTION_MS = 3000L
        
        // Static instance for direct access from overlay service
        private var instance: StealthSOSManager? = null
        
        /**
         * Cancel the current SOS from anywhere (called by overlay service)
         */
        fun cancelCurrentSOS() {
            instance?.let {
                Log.d(TAG, "🛑 Static cancelSOS called")
                it.cancelSOS()
            } ?: Log.w(TAG, "No StealthSOSManager instance to cancel")
        }
        
        /**
         * Confirm and execute the SOS (called by overlay service after countdown)
         */
        fun confirmAndExecuteSOS() {
            instance?.let {
                Log.d(TAG, "✅ Static confirmSOS called - EXECUTING SOS NOW!")
                it.isWaitingForConfirmation = false
                it.executeSOS()
            } ?: Log.w(TAG, "No StealthSOSManager instance to confirm")
        }
        
        /**
         * Check if SOS is currently active
         */
        fun isActive(): Boolean = instance?.isStealthActive ?: false
    }
    
    init {
        instance = this
    }
    
    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(Dispatchers.IO + Job())
    
    // Cancellation state
    private var isCancelled = false
    private var isWaitingForConfirmation = false
    
    // Pending SOS data (stored until countdown confirms)
    private var pendingContacts: List<EmergencyContact>? = null
    private var pendingLocationUrl: String? = null
    private var pendingAuthToken: String? = null
    private var pendingServerUrl: String? = null
    
    // Broadcast receivers for confirm/cancel
    private val confirmReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.example.my_app.CONFIRM_SOS") {
                Log.d(TAG, "✅ SOS CONFIRMED - triggering emergency!")
                isWaitingForConfirmation = false
                executeSOS()
            }
        }
    }
    
    private val cancelReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.example.my_app.CANCEL_SOS") {
                Log.d(TAG, "❌ SOS CANCELLED by user")
                cancelSOS()
            }
        }
    }
    
    private var wakeLock: PowerManager.WakeLock? = null
    private var originalBrightness: Int = 255
    private var originalBrightnessMode: Int = Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
    
    private var isStealthActive = false
    private var currentCallRetries = 0
    
    // Power button receiver for fake shutdown
    private var powerButtonReceiver: PowerButtonReceiver? = null
    
    /**
     * Start stealth SOS - shows countdown then triggers silent emergency
     * User can cancel during countdown or after via secret gestures
     * 
     * @param skipCountdown If true, execute immediately without countdown (for voice triggers)
     */
    fun startStealthSOS(
        contacts: List<EmergencyContact>,
        locationUrl: String?,
        authToken: String?,
        serverUrl: String?,
        skipCountdown: Boolean = false
    ) {
        // For voice triggers (skipCountdown=true), ALWAYS execute calls even if SOS is active
        if (skipCountdown && isStealthActive) {
            Log.w(TAG, "⚠️ Voice trigger detected - SOS already active, resetting and executing calls")
            // Reset state to ensure clean execution
            resetSOSState()
            // Now proceed with normal flow below
        }
        
        // If SOS is already active and waiting for confirmation, force execute it
        if (isStealthActive && isWaitingForConfirmation) {
            Log.w(TAG, "Stealth SOS already active but waiting - forcing immediate execution")
            isWaitingForConfirmation = false
            // Update contacts in case they changed
            pendingContacts = contacts
            pendingLocationUrl = locationUrl
            pendingAuthToken = authToken
            pendingServerUrl = serverUrl
            scope.launch {
                executeSOS()
            }
            return
        }
        
        // If SOS is already executing (not waiting), still allow voice triggers to make calls
        if (isStealthActive && !isWaitingForConfirmation && !skipCountdown) {
            Log.w(TAG, "Stealth SOS already executing - skipping duplicate trigger")
            return
        }
        
        isStealthActive = true
        isCancelled = false
        isWaitingForConfirmation = !skipCountdown  // Skip waiting if skipCountdown is true
        
        // Store pending SOS data
        pendingContacts = contacts
        pendingLocationUrl = locationUrl
        pendingAuthToken = authToken
        pendingServerUrl = serverUrl
        
        if (skipCountdown) {
            Log.d(TAG, "🥷 STEALTH SOS INITIATED - EXECUTING IMMEDIATELY (voice trigger)")
        } else {
            Log.d(TAG, "🥷 STEALTH SOS INITIATED - waiting for countdown confirmation")
            Log.d(TAG, "   User can cancel by: tap during countdown, triple-tap after, or volume up x3")
        }
        
        // Register broadcast receivers
        context.registerReceiver(
            confirmReceiver,
            IntentFilter("com.example.my_app.CONFIRM_SOS"),
            Context.RECEIVER_NOT_EXPORTED
        )
        context.registerReceiver(
            cancelReceiver,
            IntentFilter("com.example.my_app.CANCEL_SOS"),
            Context.RECEIVER_NOT_EXPORTED
        )
        
        // Register power button receiver for fake shutdown
        registerPowerButtonReceiver()
        PowerButtonReceiver.isStealthModeActive = true
        Log.d(TAG, "🔒 Power button interception enabled - fake shutdown ready")
        
        scope.launch {
            try {
                // 1. Acquire wake lock to keep running
                acquireWakeLock()
                
                // 2. Dim screen to minimum (looks like phone is off)
                dimScreen()
                
                if (skipCountdown) {
                    // For voice triggers: execute immediately without countdown
                    Log.d(TAG, "🚨 Voice trigger - executing SOS immediately")
                    executeSOS()
                } else {
                    // 3. Launch stealth overlay (black screen with countdown)
                    // The overlay will send CONFIRM_SOS or CANCEL_SOS broadcast
                    launchStealthOverlay()
                    // Wait for confirmation or cancellation (handled by broadcast receivers)
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Stealth SOS error: ${e.message}")
            }
        }
    }
    
    /**
     * Reset SOS state (useful when SOS gets stuck)
     */
    fun resetSOSState() {
        Log.d(TAG, "🔄 Resetting SOS state")
        isStealthActive = false
        isWaitingForConfirmation = false
        isCancelled = false
        currentCallRetries = 0
    }
    
    /**
     * Execute the actual SOS after countdown confirms
     */
    private fun executeSOS() {
        Log.d(TAG, "🚨 executeSOS() called - isCancelled=$isCancelled, contacts=${pendingContacts?.size ?: 0}")
        
        if (isCancelled) {
            Log.d(TAG, "SOS execution skipped - was cancelled")
            return
        }
        
        val contacts = pendingContacts ?: run {
            Log.e(TAG, "❌ Cannot execute SOS - no contacts available")
            return
        }
        
        // Try to get location if not provided
        var locationUrl = pendingLocationUrl ?: getLocationUrl()
        val authToken = pendingAuthToken
        val serverUrl = pendingServerUrl
        
        Log.d(TAG, "🚨 EXECUTING STEALTH SOS")
        Log.d(TAG, "   📞 Calling ${contacts.size} contacts")
        Log.d(TAG, "   📍 Location: ${locationUrl ?: "Unavailable"}")
        
        scope.launch {
            try {
                // 1. Mute ringer and media (silent operation)
                muteAudio()
                
                // 2. Send silent SMS to all contacts first (most reliable)
                sendStealthSMS(contacts, locationUrl)
                
                // 3. Trigger server SOS API
                if (authToken != null && serverUrl != null) {
                    triggerServerSOS(authToken, serverUrl, locationUrl)
                }
                
                // 4. Make stealth calls IMMEDIATELY to all contacts
                // For voice triggers, call all contacts at once (not sequentially)
                Log.d(TAG, "📞 Initiating calls to ${contacts.size} contacts immediately")
                for ((index, contact) in contacts.withIndex()) {
                    if (isCancelled) {
                        Log.d(TAG, "SOS cancelled - stopping calls")
                        break
                    }
                    Log.d(TAG, "📞 Calling contact ${index + 1}/${contacts.size}: ${contact.name}")
                    
                    // Launch call immediately (don't wait for previous call)
                    scope.launch {
                        makeStealthCall(contact)
                    }
                    
                    // Small delay between launching calls to avoid Android blocking
                    if (index < contacts.size - 1) {
                        delay(500)  // 500ms delay between launching calls
                    }
                }
                
                Log.d(TAG, "✅ All SOS call intents launched")
                
            } catch (e: Exception) {
                Log.e(TAG, "Stealth SOS execution error: ${e.message}", e)
            }
        }
    }
    
    /**
     * Cancel the SOS (called when user uses secret gesture)
     */
    fun cancelSOS() {
        isCancelled = true
        isWaitingForConfirmation = false
        isStealthActive = false  // IMPORTANT: Reset this flag!
        currentCallRetries = 0
        
        Log.d(TAG, "🛑 SOS Cancelled - cleaning up and resetting state")
        
        // Unregister receivers
        try {
            context.unregisterReceiver(confirmReceiver)
            context.unregisterReceiver(cancelReceiver)
        } catch (e: Exception) {
            // Receivers may not be registered
        }
        
        // Unregister power button receiver
        unregisterPowerButtonReceiver()
        
        // Close fake shutdown if active
        closeFakeShutdown()
        
        // Restore screen and audio
        scope.launch {
            restoreScreen()
            restoreAudio()
            releaseWakeLock()
        }
        
        // Clear pending data
        pendingContacts = null
        pendingLocationUrl = null
        pendingAuthToken = null
        pendingServerUrl = null
    }
    
    /**
     * Stop stealth mode and restore normal operation
     */
    fun stopStealthSOS() {
        if (!isStealthActive) return
        
        isStealthActive = false
        isCancelled = true
        Log.d(TAG, "🛑 Stealth SOS stopped")
        
        // Unregister receivers
        try {
            context.unregisterReceiver(confirmReceiver)
            context.unregisterReceiver(cancelReceiver)
        } catch (e: Exception) {
            // Receivers may not be registered
        }
        
        // Unregister power button receiver
        unregisterPowerButtonReceiver()
        
        // Close fake shutdown if active
        closeFakeShutdown()
        
        scope.launch {
            restoreScreen()
            restoreAudio()
            releaseWakeLock()
            closeStealthOverlay()
        }
    }
    
    private fun closeFakeShutdown() {
        mainHandler.post {
            context.sendBroadcast(Intent("com.example.my_app.CLOSE_FAKE_SHUTDOWN"))
        }
    }
    
    // ==================== POWER BUTTON INTERCEPTION ====================
    
    private fun registerPowerButtonReceiver() {
        try {
            powerButtonReceiver = PowerButtonReceiver()
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_SCREEN_ON)
            }
            context.registerReceiver(powerButtonReceiver, filter)
            Log.d(TAG, "📴 Power button receiver registered")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register power button receiver: ${e.message}")
        }
    }
    
    private fun unregisterPowerButtonReceiver() {
        try {
            powerButtonReceiver?.let {
                context.unregisterReceiver(it)
                powerButtonReceiver = null
            }
            PowerButtonReceiver.isStealthModeActive = false
            Log.d(TAG, "📴 Power button receiver unregistered")
        } catch (e: Exception) {
            // Receiver may not be registered
        }
    }
    
    /**
     * Launch fake shutdown screen (phone appears to turn off)
     */
    fun launchFakeShutdown() {
        mainHandler.post {
            try {
                val intent = Intent(context, FakeShutdownActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_NO_HISTORY or
                            Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                }
                context.startActivity(intent)
                Log.d(TAG, "🎭 Fake shutdown launched - phone appears off!")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to launch fake shutdown: ${e.message}")
            }
        }
    }
    
    // ==================== SCREEN HIDING ====================
    
    private fun dimScreen() {
        try {
            val contentResolver = context.contentResolver
            
            // Save original brightness
            originalBrightness = Settings.System.getInt(
                contentResolver,
                Settings.System.SCREEN_BRIGHTNESS,
                255
            )
            originalBrightnessMode = Settings.System.getInt(
                contentResolver,
                Settings.System.SCREEN_BRIGHTNESS_MODE,
                Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
            )
            
            // Set to manual mode and minimum brightness
            if (Settings.System.canWrite(context)) {
                Settings.System.putInt(
                    contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS_MODE,
                    Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
                )
                Settings.System.putInt(
                    contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS,
                    0  // Minimum brightness
                )
                Log.d(TAG, "📱 Screen dimmed to minimum")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not dim screen: ${e.message}")
        }
    }
    
    private fun restoreScreen() {
        try {
            if (Settings.System.canWrite(context)) {
                val contentResolver = context.contentResolver
                Settings.System.putInt(
                    contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS_MODE,
                    originalBrightnessMode
                )
                Settings.System.putInt(
                    contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS,
                    originalBrightness
                )
                Log.d(TAG, "📱 Screen brightness restored")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not restore screen: ${e.message}")
        }
    }
    
    private fun launchStealthOverlay() {
        mainHandler.post {
            try {
                // Use the new overlay SERVICE that floats on top of everything!
                StealthOverlayService.showOverlay(context, withCountdown = true)
                Log.d(TAG, "🖤 Stealth overlay service launched - FLOATS ON TOP OF DIALER!")
            } catch (e: Exception) {
                Log.w(TAG, "Could not launch stealth overlay: ${e.message}")
                // Fallback to activity if service fails
                try {
                    val intent = Intent(context, StealthOverlayActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_NO_HISTORY or
                                Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                    }
                    context.startActivity(intent)
                } catch (e2: Exception) {
                    Log.e(TAG, "Fallback overlay also failed: ${e2.message}")
                }
            }
        }
    }
    
    private fun closeStealthOverlay() {
        mainHandler.post {
            // Close the overlay service
            StealthOverlayService.hideOverlay(context)
            // Also send broadcast for activity-based overlay (fallback)
            val intent = Intent("com.example.my_app.CLOSE_STEALTH_OVERLAY")
            context.sendBroadcast(intent)
        }
    }
    
    // ==================== AUDIO CONTROL ====================
    
    private fun muteAudio() {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            // Mute ringer
            audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
            
            // Mute media volume
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, 0, 0)
            audioManager.setStreamVolume(AudioManager.STREAM_RING, 0, 0)
            audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, 0, 0)
            
            Log.d(TAG, "🔇 Audio muted")
        } catch (e: Exception) {
            Log.w(TAG, "Could not mute audio: ${e.message}")
        }
    }
    
    private fun restoreAudio() {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
            Log.d(TAG, "🔊 Audio restored")
        } catch (e: Exception) {
            Log.w(TAG, "Could not restore audio: ${e.message}")
        }
    }
    
    // ==================== STEALTH SMS ====================
    
    private suspend fun sendStealthSMS(contacts: List<EmergencyContact>, locationUrl: String?) {
        withContext(Dispatchers.IO) {
            for (contact in contacts) {
                try {
                    val formattedNumber = formatPhoneNumber(contact.phone, contact.countryCode)
                    
                    // Build stealth message WITH MAP LINK
                    val message = buildString {
                        append("🚨🚨 EMERGENCY SOS ALERT 🚨🚨\n\n")
                        append("I said 'help me out' - I may be in DANGER!\n\n")
                        
                        // ALWAYS include map link if available
                        if (locationUrl != null) {
                            append("📍 MY LOCATION (tap to open):\n")
                            append("$locationUrl\n\n")
                        } else {
                            append("📍 Location: Getting GPS...\n\n")
                        }
                        
                        append("⚠️ IMPORTANT:\n")
                        append("• CALL ME NOW\n")
                        append("• Keep listening even if no answer\n")
                        append("• Phone is in stealth mode (screen black)\n")
                        append("• If call cuts = I may be in immediate danger!\n\n")
                        append("If no response, call 112 immediately!")
                    }
                    
                    val smsManager = SmsManager.getDefault()
                    val parts = smsManager.divideMessage(message)
                    
                    // Send silently (no sent/delivered intents = no notifications)
                    smsManager.sendMultipartTextMessage(
                        formattedNumber,
                        null,
                        parts,
                        null,  // No sent intents
                        null   // No delivered intents
                    )
                    
                    Log.d(TAG, "📱 Stealth SMS with MAP LINK sent to: ${contact.name}")
                    if (locationUrl != null) {
                        Log.d(TAG, "   📍 Map: $locationUrl")
                    }
                    
                    delay(500)  // Small delay between SMS
                    
                } catch (e: Exception) {
                    Log.e(TAG, "SMS error for ${contact.name}: ${e.message}")
                }
            }
        }
    }
    
    /**
     * Send location update SMS to all contacts
     * Called periodically during active SOS to keep contacts updated
     */
    suspend fun sendLocationUpdateSMS(contacts: List<EmergencyContact>, locationUrl: String) {
        withContext(Dispatchers.IO) {
            for (contact in contacts) {
                try {
                    val formattedNumber = formatPhoneNumber(contact.phone, contact.countryCode)
                    
                    val message = buildString {
                        append("📍 LOCATION UPDATE\n\n")
                        append("New location:\n")
                        append("$locationUrl\n\n")
                        append("SOS still active - stay alert!")
                    }
                    
                    val smsManager = SmsManager.getDefault()
                    smsManager.sendTextMessage(formattedNumber, null, message, null, null)
                    
                    Log.d(TAG, "📍 Location update SMS sent to: ${contact.name}")
                    
                } catch (e: Exception) {
                    Log.e(TAG, "Location SMS error for ${contact.name}: ${e.message}")
                }
            }
        }
    }
    
    // ==================== STEALTH CALLS ====================
    
    private suspend fun makeStealthCall(contact: EmergencyContact) {
        try {
            val formattedNumber = formatPhoneNumber(contact.phone, contact.countryCode)
            
            Log.d(TAG, "📞 Stealth call to: ${contact.name}")
            Log.d(TAG, "   📱 Phone number: $formattedNumber")
            
            // Make call with minimal UI - execute on main thread immediately
            mainHandler.post {
                try {
                    Log.d(TAG, "🚀 Launching call intent for ${contact.name}")
                    
                    // Check if CALL_PHONE permission is granted
                    val hasPermission = androidx.core.content.ContextCompat.checkSelfPermission(
                        context,
                        android.Manifest.permission.CALL_PHONE
                    ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    
                    if (hasPermission) {
                        val callIntent = Intent(Intent.ACTION_CALL).apply {
                            data = Uri.parse("tel:$formattedNumber")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                    Intent.FLAG_ACTIVITY_NO_HISTORY or
                                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                        }
                        context.startActivity(callIntent)
                        Log.d(TAG, "✅ Call intent launched successfully for ${contact.name}")
                    } else {
                        Log.e(TAG, "❌ CALL_PHONE permission NOT granted!")
                        Log.e(TAG, "   Falling back to DIAL intent")
                        // Try fallback to DIAL
                        val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                            data = Uri.parse("tel:$formattedNumber")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        context.startActivity(dialIntent)
                        Log.w(TAG, "⚠️ DIAL intent opened (user must press call button)")
                    }
                    
                    // IMMEDIATELY bring stealth overlay back to hide dialer!
                    // This is the key - we cover the call screen right away
                    Handler(Looper.getMainLooper()).postDelayed({
                        bringStealthOverlayToFront()
                    }, 500)  // 500ms delay to let call start
                    
                    // After call connects, enable speakerphone
                    Handler(Looper.getMainLooper()).postDelayed({
                        enableSpeakerphone()
                        // Bring overlay to front again after speakerphone
                        bringStealthOverlayToFront()
                    }, 2000)
                    
                    // Keep bringing overlay to front periodically during call
                    startOverlayKeepalive()
                    
                } catch (e: SecurityException) {
                    Log.e(TAG, "❌ SecurityException starting call: ${e.message}")
                    Log.e(TAG, "   Missing CALL_PHONE permission!")
                    e.printStackTrace()
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Call intent error: ${e.message}", e)
                    e.printStackTrace()
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Stealth call error for ${contact.name}: ${e.message}", e)
        }
    }
    
    private var overlayKeepaliveJob: kotlinx.coroutines.Job? = null
    
    /**
     * Keep bringing the stealth overlay to front to hide dialer
     */
    private fun startOverlayKeepalive() {
        overlayKeepaliveJob?.cancel()
        overlayKeepaliveJob = scope.launch {
            while (isStealthActive && !isCancelled) {
                mainHandler.post { bringStealthOverlayToFront() }
                delay(1000)  // Every 1 second
            }
        }
    }
    
    private fun stopOverlayKeepalive() {
        overlayKeepaliveJob?.cancel()
        overlayKeepaliveJob = null
    }
    
    /**
     * Bring stealth overlay to front (hides dialer/call screen)
     * Uses TYPE_APPLICATION_OVERLAY service which stays on top of EVERYTHING!
     */
    private fun bringStealthOverlayToFront() {
        try {
            // The service-based overlay automatically stays on top of the dialer
            // Just ensure it's running
            if (!StealthOverlayService.isRunning()) {
                StealthOverlayService.showOverlay(context, withCountdown = false)
                Log.d(TAG, "🖤 Restarted overlay service to hide dialer")
            }
            // The TYPE_APPLICATION_OVERLAY window is already on top - no action needed!
        } catch (e: Exception) {
            Log.e(TAG, "Failed to ensure overlay is on top: ${e.message}")
        }
    }
    
    private fun enableSpeakerphone() {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.mode = AudioManager.MODE_IN_CALL
            audioManager.isSpeakerphoneOn = true
            
            // Set call volume to max so contact can hear everything
            audioManager.setStreamVolume(
                AudioManager.STREAM_VOICE_CALL,
                audioManager.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL),
                0
            )
            
            Log.d(TAG, "🔊 Speakerphone enabled - contact can hear surroundings")
        } catch (e: Exception) {
            Log.w(TAG, "Could not enable speakerphone: ${e.message}")
        }
    }
    
    private fun isCallActive(): Boolean {
        return try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.mode == AudioManager.MODE_IN_CALL || 
            audioManager.mode == AudioManager.MODE_IN_COMMUNICATION
        } catch (e: Exception) {
            false
        }
    }
    
    // ==================== SERVER SOS ====================
    
    private suspend fun triggerServerSOS(authToken: String, serverUrl: String, locationUrl: String?) {
        withContext(Dispatchers.IO) {
            try {
                val url = java.net.URL("$serverUrl/api/sos/trigger")
                val connection = url.openConnection() as java.net.HttpURLConnection
                connection.apply {
                    requestMethod = "POST"
                    setRequestProperty("Authorization", "Bearer $authToken")
                    setRequestProperty("Content-Type", "application/json")
                    doOutput = true
                    connectTimeout = 10000
                    readTimeout = 10000
                }
                
                // Send location in body if available
                if (locationUrl != null) {
                    val body = """{"location": "$locationUrl", "stealth": true}"""
                    connection.outputStream.write(body.toByteArray())
                }
                
                val responseCode = connection.responseCode
                Log.d(TAG, "📡 Server SOS triggered: $responseCode")
                
            } catch (e: Exception) {
                Log.e(TAG, "Server SOS error: ${e.message}")
            }
        }
    }
    
    // ==================== UTILITIES ====================
    
    private fun acquireWakeLock() {
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "VHASS:StealthSOS"
            )
            wakeLock?.acquire(30 * 60 * 1000L)  // 30 minutes max
            Log.d(TAG, "🔒 Wake lock acquired")
        } catch (e: Exception) {
            Log.w(TAG, "Could not acquire wake lock: ${e.message}")
        }
    }
    
    private fun releaseWakeLock() {
        try {
            wakeLock?.release()
            wakeLock = null
            Log.d(TAG, "🔓 Wake lock released")
        } catch (e: Exception) {
            Log.w(TAG, "Could not release wake lock: ${e.message}")
        }
    }
    
    private fun formatPhoneNumber(phone: String, countryCode: String): String {
        return when {
            phone.startsWith("+") -> phone
            countryCode == "IN" -> "+91$phone"
            else -> "+$countryCode$phone"
        }
    }
    
    /**
     * Get current location as Google Maps URL
     */
    private fun getLocationUrl(): String? {
        return try {
            val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
            
            // Try GPS first, then network
            val location = try {
                locationManager.getLastKnownLocation(android.location.LocationManager.GPS_PROVIDER)
            } catch (e: SecurityException) {
                Log.w(TAG, "📍 GPS permission denied")
                null
            } ?: try {
                locationManager.getLastKnownLocation(android.location.LocationManager.NETWORK_PROVIDER)
            } catch (e: SecurityException) {
                Log.w(TAG, "📍 Network location permission denied")
                null
            }
            
            if (location != null) {
                val mapUrl = "https://maps.google.com/?q=${location.latitude},${location.longitude}"
                Log.d(TAG, "📍 Got location: $mapUrl")
                mapUrl
            } else {
                Log.w(TAG, "📍 No location available - GPS may be off or no recent location")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "📍 Error getting location: ${e.message}")
            null
        }
    }
    
    data class EmergencyContact(
        val name: String,
        val phone: String,
        val countryCode: String,
        val priority: Int
    )
}

