package com.example.my_app

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.AlphaAnimation
import android.view.animation.Animation
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.TextView
import android.util.Log

/**
 * Fake Shutdown Activity
 * 
 * When attacker tries to turn off the phone:
 * 1. Shows realistic "Shutting down..." animation
 * 2. Progress bar fills up
 * 3. Screen fades to black
 * 4. Phone APPEARS to be off
 * 5. BUT SOS continues running in background!
 * 
 * Features:
 * - Intercepts power button
 * - Shows manufacturer-style shutdown animation
 * - Blocks all user interaction
 * - Phone stays secretly active
 * - SOS calls/SMS continue
 */
class FakeShutdownActivity : Activity() {
    
    companion object {
        const val TAG = "FakeShutdown"
        
        // Duration of fake shutdown animation
        const val SHUTDOWN_ANIMATION_MS = 3000L
        
        // After "shutdown", show black screen
        const val POST_SHUTDOWN_BLACK_SCREEN = true
    }
    
    private val handler = Handler(Looper.getMainLooper())
    private var vibrator: Vibrator? = null
    private var isShutdownComplete = false
    
    private val closeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.example.my_app.CLOSE_FAKE_SHUTDOWN") {
                finish()
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "🔌 FAKE SHUTDOWN initiated - SOS will continue!")
        
        // Initialize vibrator
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        
        setupWindow()
        showShutdownAnimation()
        
        // Register receiver
        registerReceiver(
            closeReceiver,
            IntentFilter("com.example.my_app.CLOSE_FAKE_SHUTDOWN"),
            RECEIVER_NOT_EXPORTED
        )
    }
    
    private fun setupWindow() {
        window.apply {
            // Full screen
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
            
            // Prevent screenshots
            addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            
            statusBarColor = Color.BLACK
            navigationBarColor = Color.BLACK
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
    }
    
    private fun showShutdownAnimation() {
        // Create shutdown UI
        val rootLayout = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
        }
        
        // "Shutting down..." text
        val shutdownText = TextView(this).apply {
            text = "Shutting down..."
            setTextColor(Color.WHITE)
            textSize = 18f
            gravity = Gravity.CENTER
        }
        
        val textParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
            bottomMargin = 100
        }
        rootLayout.addView(shutdownText, textParams)
        
        // Progress indicator (circular)
        val progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleLarge).apply {
            isIndeterminate = true
            // Tint to white for dark theme
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                indeterminateTintList = android.content.res.ColorStateList.valueOf(Color.WHITE)
            }
        }
        
        val progressParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
            topMargin = 50
        }
        rootLayout.addView(progressBar, progressParams)
        
        // Manufacturer logo placeholder (circle)
        val logoView = View(this).apply {
            val drawable = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.DKGRAY)
            }
            background = drawable
        }
        
        val logoParams = FrameLayout.LayoutParams(80, 80).apply {
            gravity = Gravity.CENTER
            bottomMargin = 250
        }
        rootLayout.addView(logoView, logoParams)
        
        setContentView(rootLayout)
        
        // Vibrate like real shutdown
        vibrateShutdown()
        
        // After animation, show "off" screen
        handler.postDelayed({
            showOffScreen(rootLayout, shutdownText, progressBar, logoView)
        }, SHUTDOWN_ANIMATION_MS)
    }
    
    private fun showOffScreen(
        rootLayout: FrameLayout,
        shutdownText: TextView,
        progressBar: ProgressBar,
        logoView: View
    ) {
        isShutdownComplete = true
        
        // Fade out animation
        val fadeOut = AlphaAnimation(1f, 0f).apply {
            duration = 500
            fillAfter = true
        }
        
        shutdownText.startAnimation(fadeOut)
        progressBar.startAnimation(fadeOut)
        logoView.startAnimation(fadeOut)
        
        handler.postDelayed({
            // Remove all views, show pure black
            rootLayout.removeAllViews()
            rootLayout.setBackgroundColor(Color.BLACK)
            
            // Add invisible touch blocker
            rootLayout.setOnTouchListener { _, _ -> true }
            
            Log.d(TAG, "📴 Phone appears OFF - but SOS is still running!")
            
        }, 500)
    }
    
    private fun vibrateShutdown() {
        try {
            // Single short vibration like real shutdown
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(100)
            }
        } catch (e: Exception) {
            // Ignore
        }
    }
    
    // Block ALL key presses to prevent "waking" the fake-off phone
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        Log.d(TAG, "🔒 Key press blocked: $keyCode (phone appears off)")
        
        // If shutdown is complete, block everything
        if (isShutdownComplete) {
            // Power button - do nothing (phone appears off)
            // Volume buttons - do nothing
            // Back button - do nothing
            return true  // Consume all events
        }
        
        return true  // Block during animation too
    }
    
    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        return true  // Block all key releases
    }
    
    override fun onKeyLongPress(keyCode: Int, event: KeyEvent?): Boolean {
        return true  // Block long presses
    }
    
    override fun onBackPressed() {
        // Block back button
        Log.d(TAG, "🔒 Back button blocked")
    }
    
    override fun onPause() {
        super.onPause()
        // If activity loses focus, restart it to maintain "off" appearance
        if (isShutdownComplete && !isFinishing) {
            handler.postDelayed({
                val intent = Intent(this, FakeShutdownActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_NO_ANIMATION
                }
                startActivity(intent)
            }, 100)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(closeReceiver)
        } catch (e: Exception) {
            // Ignore
        }
        Log.d(TAG, "📴 Fake shutdown activity destroyed")
    }
}

