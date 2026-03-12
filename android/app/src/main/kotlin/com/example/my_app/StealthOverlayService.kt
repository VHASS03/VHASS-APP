package com.example.my_app

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.*
import android.provider.Settings
import android.util.Log
import android.view.*
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

/**
 * Stealth Overlay Service - MAXIMUM SECURITY - FLOATS ON TOP OF EVERYTHING!
 * 
 * Uses TYPE_APPLICATION_OVERLAY to create a window that:
 * - Stays on top of ALL apps including phone/dialer
 * - Cannot be dismissed by pressing home/back
 * - Looks like the phone is turned off (black screen)
 * - CANNOT be cancelled without entering SECRET PIN
 * 
 * 🔐 ULTRA SECURE CANCELLATION:
 * - Attacker CANNOT cancel by tapping, volume buttons, or anything
 * - ONLY the user who knows the SECRET PIN can cancel
 * - PIN is entered by tapping corners of screen in sequence (invisible to attacker)
 * - Default PIN: Top-Left, Top-Right, Bottom-Left, Bottom-Right (4 corners)
 * 
 * Even if attacker tries random taps, they can't cancel!
 */
class StealthOverlayService : Service() {
    
    companion object {
        const val TAG = "StealthOverlayService"
        const val NOTIFICATION_ID = 2001
        const val CHANNEL_ID = "stealth_overlay_channel"
        
        const val ACTION_SHOW_OVERLAY = "com.example.my_app.SHOW_STEALTH_OVERLAY"
        const val ACTION_HIDE_OVERLAY = "com.example.my_app.HIDE_STEALTH_OVERLAY"
        const val ACTION_SHOW_COUNTDOWN = "com.example.my_app.SHOW_COUNTDOWN"
        
        const val COUNTDOWN_SECONDS = 5
        
        // Secret PIN timeout - must complete pattern within this time
        const val PIN_TIMEOUT_MS = 5000L
        
        // Screen is divided into 4 quadrants for secret PIN
        // Default PIN: TL, TR, BL, BR (corners in Z pattern)
        val SECRET_PIN = listOf("TL", "TR", "BL", "BR")
        
        private var instance: StealthOverlayService? = null
        
        fun isRunning(): Boolean = instance != null
        
        fun showOverlay(context: Context, withCountdown: Boolean = false) {
            if (!Settings.canDrawOverlays(context)) {
                Log.e(TAG, "❌ No overlay permission!")
                return
            }
            
            val intent = Intent(context, StealthOverlayService::class.java).apply {
                action = if (withCountdown) ACTION_SHOW_COUNTDOWN else ACTION_SHOW_OVERLAY
            }
            context.startForegroundService(intent)
        }
        
        fun hideOverlay(context: Context) {
            val intent = Intent(context, StealthOverlayService::class.java).apply {
                action = ACTION_HIDE_OVERLAY
            }
            context.startService(intent)
        }
    }
    
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var countdownTextView: TextView? = null
    
    private val handler = Handler(Looper.getMainLooper())
    private var vibrator: Vibrator? = null
    
    // Countdown state
    private var countdownRemaining = COUNTDOWN_SECONDS
    private var isCountdownActive = false
    private var sosCancelled = false
    
    // Secret PIN detection - tap corners in correct sequence
    private val enteredPIN = mutableListOf<String>()
    private var lastPinTapTime = 0L
    private var screenWidth = 0
    private var screenHeight = 0
    
    private val closeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "com.example.my_app.CLOSE_STEALTH_OVERLAY" -> {
                    removeOverlay()
                    stopSelf()
                }
                // Volume buttons NO LONGER cancel - attacker can't use them!
            }
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vm.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        
        createNotificationChannel()
        
        // Register receivers (volume buttons removed - not secure enough)
        val filter = IntentFilter().apply {
            addAction("com.example.my_app.CLOSE_STEALTH_OVERLAY")
        }
        registerReceiver(closeReceiver, filter, RECEIVER_NOT_EXPORTED)
        
        Log.d(TAG, "✅ Stealth overlay service created")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        when (intent?.action) {
            ACTION_SHOW_COUNTDOWN -> {
                showOverlayWithCountdown()
            }
            ACTION_SHOW_OVERLAY -> {
                showOverlayOnly()
            }
            ACTION_HIDE_OVERLAY -> {
                removeOverlay()
                stopSelf()
            }
        }
        
        return START_STICKY
    }
    
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Stealth Mode",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Active during emergency stealth mode"
            setShowBadge(false)
        }
        
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
    
    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Safety Mode Active")
            .setContentText("Tap notification to cancel")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
    
    /**
     * Show black overlay with countdown (for initial SOS trigger)
     */
    private fun showOverlayWithCountdown() {
        if (overlayView != null) return
        
        sosCancelled = false
        isCountdownActive = true
        countdownRemaining = COUNTDOWN_SECONDS
        
        createOverlayView(showCountdown = true)
        addOverlayToWindow()
        startCountdown()
        
        Log.d(TAG, "🖤 Stealth overlay with countdown started")
    }
    
    /**
     * Show black overlay only (for hiding dialer during call)
     */
    private fun showOverlayOnly() {
        if (overlayView != null) {
            // Already showing, just make sure it's on top
            return
        }
        
        sosCancelled = false
        isCountdownActive = false
        
        createOverlayView(showCountdown = false)
        addOverlayToWindow()
        
        Log.d(TAG, "🖤 Stealth overlay hiding dialer!")
    }
    
    private fun createOverlayView(showCountdown: Boolean) {
        // Get screen dimensions for quadrant detection
        val displayMetrics = resources.displayMetrics
        screenWidth = displayMetrics.widthPixels
        screenHeight = displayMetrics.heightPixels
        
        val rootLayout = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
            
            // Handle touches - detect which quadrant was tapped
            setOnTouchListener { _, event ->
                if (event.action == MotionEvent.ACTION_DOWN) {
                    handleSecretPinTap(event.x, event.y)
                }
                true
            }
        }
        
        // Add countdown text if needed (barely visible)
        if (showCountdown) {
            countdownTextView = TextView(this).apply {
                setTextColor(Color.DKGRAY)  // Very dark - almost invisible
                textSize = 8f  // Tiny
                gravity = Gravity.CENTER
                text = "$countdownRemaining"  // Just the number, no instructions
            }
            
            val params = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
                bottomMargin = 50
            }
            
            rootLayout.addView(countdownTextView, params)
        }
        
        overlayView = rootLayout
    }
    
    private fun addOverlayToWindow() {
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            PixelFormat.OPAQUE
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
        }
        
        try {
            windowManager?.addView(overlayView, params)
            Log.d(TAG, "✅ Overlay added to window - ON TOP OF EVERYTHING!")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to add overlay: ${e.message}")
        }
    }
    
    private fun removeOverlay() {
        try {
            overlayView?.let {
                windowManager?.removeView(it)
                overlayView = null
            }
            Log.d(TAG, "🖤 Overlay removed")
        } catch (e: Exception) {
            Log.e(TAG, "Error removing overlay: ${e.message}")
        }
    }
    
    private fun startCountdown() {
        // Subtle vibration - user knows SOS is starting
        vibratePattern(longArrayOf(0, 200, 100, 200))
        
        handler.post(object : Runnable {
            override fun run() {
                if (sosCancelled || !isCountdownActive) return
                
                if (countdownRemaining > 0) {
                    // Just show countdown number - NO instructions!
                    // Attacker doesn't know how to cancel
                    countdownTextView?.text = "$countdownRemaining"
                    vibratePulse()
                    countdownRemaining--
                    handler.postDelayed(this, 1000)
                } else {
                    // Countdown finished - confirm SOS
                    isCountdownActive = false
                    countdownTextView?.text = ""  // Screen goes completely black
                    vibratePattern(longArrayOf(0, 500))
                    
                    // DIRECTLY call StealthSOSManager to execute SOS (more reliable than broadcast)
                    StealthSOSManager.confirmAndExecuteSOS()
                    
                    // Also send broadcast as fallback
                    sendBroadcast(Intent("com.example.my_app.CONFIRM_SOS"))
                    Log.d(TAG, "🚨 Countdown finished - SOS CONFIRMED - CALLS STARTING NOW!")
                }
            }
        })
    }
    
    /**
     * Handle secret PIN tap - user must tap corners in correct sequence
     * Screen is divided into 4 quadrants:
     * TL | TR
     * -------
     * BL | BR
     * 
     * Default PIN: TL, TR, BL, BR (Z pattern)
     * Attacker has no idea this is how to cancel!
     */
    private fun handleSecretPinTap(x: Float, y: Float) {
        val currentTime = System.currentTimeMillis()
        
        // Reset PIN if timeout exceeded
        if (currentTime - lastPinTapTime > PIN_TIMEOUT_MS) {
            enteredPIN.clear()
        }
        lastPinTapTime = currentTime
        
        // Determine which quadrant was tapped
        val quadrant = getQuadrant(x, y)
        enteredPIN.add(quadrant)
        
        // Very subtle vibration (attacker might not notice)
        vibratePulse()
        
        Log.d(TAG, "🔐 PIN tap: $quadrant (entered: ${enteredPIN.joinToString("-")})")
        
        // Check if PIN matches
        if (enteredPIN.size >= SECRET_PIN.size) {
            if (checkPIN()) {
                Log.d(TAG, "✅ SECRET PIN CORRECT - Cancelling SOS")
                cancelSOS("Secret PIN")
            } else {
                // Wrong PIN - reset and DON'T give any feedback
                Log.d(TAG, "❌ Wrong PIN - no feedback to attacker")
                enteredPIN.clear()
            }
        }
    }
    
    /**
     * Determine which quadrant of the screen was tapped
     */
    private fun getQuadrant(x: Float, y: Float): String {
        val isLeft = x < screenWidth / 2
        val isTop = y < screenHeight / 2
        
        return when {
            isTop && isLeft -> "TL"
            isTop && !isLeft -> "TR"
            !isTop && isLeft -> "BL"
            else -> "BR"
        }
    }
    
    /**
     * Check if entered PIN matches secret PIN
     */
    private fun checkPIN(): Boolean {
        if (enteredPIN.size < SECRET_PIN.size) return false
        
        // Check last N entries against PIN
        val lastEntries = enteredPIN.takeLast(SECRET_PIN.size)
        return lastEntries == SECRET_PIN
    }
    
    private fun cancelSOS(method: String) {
        if (sosCancelled) return
        
        sosCancelled = true
        isCountdownActive = false
        
        Log.d(TAG, "✅ SOS CANCELLED via: $method")
        
        vibratePattern(longArrayOf(0, 100, 100, 100, 100, 100))
        
        countdownTextView?.apply {
            setTextColor(Color.GREEN)
            textSize = 14f
            text = "✓ Cancelled"
        }
        
        // DIRECTLY call the StealthSOSManager to cancel (more reliable than broadcast)
        StealthSOSManager.cancelCurrentSOS()
        
        // Also send broadcast as fallback
        sendBroadcast(Intent("com.example.my_app.CANCEL_SOS"))
        
        handler.postDelayed({
            removeOverlay()
            stopSelf()
        }, 1500)
    }
    
    private fun vibratePulse() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(100)
            }
        } catch (e: Exception) {}
    }
    
    private fun vibratePattern(pattern: LongArray) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, -1)
            }
        } catch (e: Exception) {}
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        removeOverlay()
        try {
            unregisterReceiver(closeReceiver)
        } catch (e: Exception) {}
        Log.d(TAG, "🛑 Stealth overlay service destroyed")
    }
}

