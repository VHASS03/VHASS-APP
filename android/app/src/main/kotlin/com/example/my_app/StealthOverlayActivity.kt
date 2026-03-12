package com.example.my_app

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import android.view.Gravity

/**
 * Stealth Overlay Activity - MAXIMUM SECURITY
 * 
 * Shows a completely BLACK screen that looks like the phone is off.
 * HIDES THE DIALER during active calls so attacker can't see/cut the call!
 * 
 * 🔐 ULTRA SECURE - ONLY SECRET PIN CAN CANCEL:
 * - Attacker CANNOT cancel by tapping randomly
 * - Attacker CANNOT cancel by pressing volume buttons
 * - ONLY the user who knows the SECRET PIN pattern can cancel
 * - PIN: Tap corners in sequence (TL, TR, BL, BR - Z pattern)
 * 
 * ⏱️ COUNTDOWN PROTECTION:
 * - 5 second countdown before SOS actually triggers
 * - Phone VIBRATES during countdown (attacker might not notice)
 * - NO instructions shown - attacker doesn't know how to cancel
 * 
 * 📞 DIALER HIDING:
 * - Stays on top of phone app/dialer
 * - Call continues in background (invisible!)
 * - Speakerphone enabled so contact can hear
 */
class StealthOverlayActivity : Activity() {
    
    companion object {
        const val TAG = "StealthOverlay"
        
        // Countdown before SOS triggers
        const val COUNTDOWN_SECONDS = 5
        
        // Secret PIN timeout
        const val PIN_TIMEOUT_MS = 5000L
        
        // Secret PIN: Tap corners in Z pattern
        val SECRET_PIN = listOf("TL", "TR", "BL", "BR")
        
        // Track if we're in call-hiding mode
        var isHidingDialer = false
    }
    
    private val handler = Handler(Looper.getMainLooper())
    private var vibrator: Vibrator? = null
    
    // Countdown state
    private var countdownRemaining = COUNTDOWN_SECONDS
    private var isCountdownActive = true
    private var countdownTextView: TextView? = null
    
    // Secret PIN detection
    private val enteredPIN = mutableListOf<String>()
    private var lastPinTapTime = 0L
    private var screenWidth = 0
    private var screenHeight = 0
    
    // SOS cancelled flag
    private var sosCancelled = false
    
    private val closeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.example.my_app.CLOSE_STEALTH_OVERLAY") {
                finish()
            }
        }
    }
    
    // Track if we should skip countdown (when hiding dialer)
    private var skipCountdown = false
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check if we're being launched to hide dialer
        handleIntent(intent)
        
        // Initialize vibrator
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        
        // Make activity full screen and secure
        setupWindow()
        
        // Create layout with hidden countdown
        val rootLayout = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
        }
        
        // Get screen dimensions for quadrant detection
        val displayMetrics = resources.displayMetrics
        screenWidth = displayMetrics.widthPixels
        screenHeight = displayMetrics.heightPixels
        
        // Add tiny countdown text (barely visible - gray on black) - NO INSTRUCTIONS!
        countdownTextView = TextView(this).apply {
            setTextColor(Color.DKGRAY)  // Very dark gray - hard to see
            textSize = 8f  // Even tinier text
            gravity = Gravity.CENTER
            text = if (isHidingDialer) "" else "$countdownRemaining"  // Just number, no instructions
        }
        
        val params = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            bottomMargin = 50
        }
        
        rootLayout.addView(countdownTextView, params)
        
        // Handle touches - secret PIN detection (tap corners in sequence)
        rootLayout.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_DOWN) {
                handleSecretPinTap(event.x, event.y)
            }
            true
        }
        
        setContentView(rootLayout)
        
        // Register receiver to close overlay
        registerReceiver(
            closeReceiver,
            IntentFilter("com.example.my_app.CLOSE_STEALTH_OVERLAY"),
            RECEIVER_NOT_EXPORTED
        )
        
        // Start countdown only if not hiding dialer
        if (!skipCountdown && !isHidingDialer) {
            startCountdown()
            println("[StealthOverlay] 🖤 Black screen activated - ${COUNTDOWN_SECONDS}s countdown started")
            println("[StealthOverlay] 💡 Triple tap or Volume Up x3 to cancel")
        } else {
            // Already in SOS mode, just show black screen
            isCountdownActive = false
            countdownTextView?.text = ""
            println("[StealthOverlay] 🖤 Black screen covering dialer - call hidden!")
        }
    }
    
    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        intent?.let { handleIntent(it) }
        
        // Make sure we stay on top
        setupWindow()
    }
    
    private fun handleIntent(intent: Intent?) {
        val hideDialer = intent?.getBooleanExtra("hideDialer", false) ?: false
        val isCallActive = intent?.getBooleanExtra("isCallActive", false) ?: false
        
        if (hideDialer || isCallActive) {
            isHidingDialer = true
            skipCountdown = true
            isCountdownActive = false
            println("[StealthOverlay] 📞 Hiding dialer - call continues in background!")
        }
    }
    
    /**
     * Start the countdown before SOS triggers
     * User must use SECRET PIN to cancel - NO instructions shown!
     */
    private fun startCountdown() {
        isCountdownActive = true
        countdownRemaining = COUNTDOWN_SECONDS
        
        // Vibrate to alert user (2 short pulses)
        vibratePattern(longArrayOf(0, 200, 100, 200))
        
        handler.post(object : Runnable {
            override fun run() {
                if (sosCancelled) return
                
                if (countdownRemaining > 0) {
                    // Just show number - NO INSTRUCTIONS (attacker doesn't know how to cancel!)
                    countdownTextView?.text = "$countdownRemaining"
                    
                    // Single vibration pulse each second
                    vibratePulse()
                    
                    countdownRemaining--
                    handler.postDelayed(this, 1000)
                } else {
                    // Countdown finished - trigger SOS!
                    isCountdownActive = false
                    countdownTextView?.text = ""  // Screen goes completely black
                    
                    // Long vibration to confirm SOS is triggering
                    vibratePattern(longArrayOf(0, 500))
                    
                    // DIRECTLY call StealthSOSManager to execute SOS (more reliable than broadcast)
                    StealthSOSManager.confirmAndExecuteSOS()
                    
                    // Also send broadcast as fallback
                    sendBroadcast(Intent("com.example.my_app.CONFIRM_SOS"))
                    
                    println("[StealthOverlay] 🚨 Countdown finished - SOS CONFIRMED - CALLS STARTING NOW!")
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
        
        println("[StealthOverlay] 🔐 PIN tap: $quadrant (entered: ${enteredPIN.joinToString("-")})")
        
        // Check if PIN matches
        if (enteredPIN.size >= SECRET_PIN.size) {
            if (checkPIN()) {
                println("[StealthOverlay] ✅ SECRET PIN CORRECT - Cancelling SOS")
                cancelSOS("Secret PIN")
            } else {
                // Wrong PIN - reset and DON'T give any feedback to attacker
                println("[StealthOverlay] ❌ Wrong PIN - no feedback")
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
        val lastEntries = enteredPIN.takeLast(SECRET_PIN.size)
        return lastEntries == SECRET_PIN
    }
    
    /**
     * Volume buttons NO LONGER cancel - blocked for security
     */
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // Block all key events - attacker can't use buttons to cancel
        return true
    }
    
    /**
     * Cancel the SOS
     */
    private fun cancelSOS(method: String) {
        if (sosCancelled) return
        
        sosCancelled = true
        isCountdownActive = false
        
        println("[StealthOverlay] ✅ SOS CANCELLED via: $method")
        
        // Vibrate confirmation pattern (3 short pulses)
        vibratePattern(longArrayOf(0, 100, 100, 100, 100, 100))
        
        // Show brief cancellation message
        countdownTextView?.apply {
            setTextColor(Color.GREEN)
            textSize = 14f
            text = "✓ Cancelled"
        }
        
        // DIRECTLY call the StealthSOSManager to cancel (more reliable than broadcast)
        StealthSOSManager.cancelCurrentSOS()
        
        // Also send broadcast as fallback
        sendBroadcast(Intent("com.example.my_app.CANCEL_SOS"))
        
        // Close overlay after brief delay
        handler.postDelayed({
            finish()
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
        } catch (e: Exception) {
            // Ignore vibration errors
        }
    }
    
    private fun vibratePattern(pattern: LongArray) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, -1)
            }
        } catch (e: Exception) {
            // Ignore vibration errors
        }
    }
    
    private fun setupWindow() {
        window.apply {
            // Full screen immersive
            decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN
            )
            
            // Show on lock screen
            addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                or WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
            
            // Prevent screenshots (security)
            addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            
            // Set status bar and navigation bar black
            statusBarColor = Color.BLACK
            navigationBarColor = Color.BLACK
        }
        
        // For newer Android versions
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
    }
    
    override fun onBackPressed() {
        // Disable back button - overlay can only be closed by broadcast
        // This prevents attacker from closing the black screen
    }
    
    override fun onPause() {
        super.onPause()
        // If activity is paused (e.g., phone call UI), restart it IMMEDIATELY
        // This ensures the black screen comes back and hides the dialer
        if (!isFinishing && !sosCancelled) {
            // Immediate restart to cover dialer
            handler.postDelayed({
                if (!isFinishing && !sosCancelled) {
                    val intent = Intent(this, StealthOverlayActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                                Intent.FLAG_ACTIVITY_NO_ANIMATION
                        putExtra("hideDialer", true)
                        putExtra("isCallActive", isHidingDialer)
                    }
                    startActivity(intent)
                }
            }, 100)  // 100ms delay - very fast!
        }
    }
    
    override fun onStop() {
        super.onStop()
        // Even more aggressive - also restart on stop
        if (!isFinishing && !sosCancelled && isHidingDialer) {
            handler.postDelayed({
                if (!isFinishing && !sosCancelled) {
                    val intent = Intent(this, StealthOverlayActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                        putExtra("hideDialer", true)
                        putExtra("isCallActive", true)
                    }
                    startActivity(intent)
                }
            }, 50)  // Even faster!
        }
    }
    
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        // If we lose focus (dialer coming to front), get it back!
        if (!hasFocus && !isFinishing && !sosCancelled && isHidingDialer) {
            handler.postDelayed({
                if (!isFinishing && !sosCancelled) {
                    val intent = Intent(this, StealthOverlayActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                        putExtra("hideDialer", true)
                    }
                    startActivity(intent)
                }
            }, 200)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(closeReceiver)
        } catch (e: Exception) {
            // Receiver may not be registered
        }
        println("[StealthOverlay] 🖤 Black screen closed")
    }
}

