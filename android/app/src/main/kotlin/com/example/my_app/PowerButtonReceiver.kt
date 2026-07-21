package com.example.my_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Power Button Receiver
 * 
 * Detects when screen is turned off (power button pressed)
 * and launches fake shutdown if SOS is active.
 * 
 * This prevents attackers from actually turning off the phone!
 */
class PowerButtonReceiver : BroadcastReceiver() {
    
    companion object {
        const val TAG = "PowerButtonReceiver"
        
        // Track if SOS stealth mode is active
        var isStealthModeActive = false
        
        // Track rapid power button presses
        private var lastPowerPressTime = 0L
        private var powerPressCount = 0
        private const val RAPID_PRESS_WINDOW_MS = 2000L
        private const val PRESSES_FOR_FAKE_SHUTDOWN = 1  // Single press triggers fake shutdown
    }
    
    private val handler = Handler(Looper.getMainLooper())
    
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        
        when (intent.action) {
            Intent.ACTION_SCREEN_OFF -> {
                Log.d(TAG, "📴 Screen OFF detected")
                
                if (isStealthModeActive) {
                    Log.d(TAG, "🔒 SOS active - intercepting power off!")
                    handlePowerButtonDuringSOS(context)
                }
            }
            
            Intent.ACTION_SCREEN_ON -> {
                Log.d(TAG, "📱 Screen ON detected")
                
                if (isStealthModeActive) {
                    // If SOS is active and screen turns on, show stealth overlay
                    Log.d(TAG, "🔒 SOS active - maintaining stealth overlay")
                    launchStealthOverlay(context)
                }
            }
        }
    }
    
    private fun handlePowerButtonDuringSOS(context: Context) {
        val currentTime = System.currentTimeMillis()
        
        // Check if this is a rapid press
        if (currentTime - lastPowerPressTime > RAPID_PRESS_WINDOW_MS) {
            powerPressCount = 0
        }
        
        powerPressCount++
        lastPowerPressTime = currentTime
        
        Log.d(TAG, "⚡ Power button press #$powerPressCount during SOS")
        
        if (powerPressCount >= PRESSES_FOR_FAKE_SHUTDOWN) {
            // Attacker is trying to turn off phone - show fake shutdown!
            Log.d(TAG, "🎭 Launching FAKE SHUTDOWN - phone will appear off but SOS continues!")
            launchFakeShutdown(context)
            powerPressCount = 0
        } else {
            // Just show stealth overlay again
            handler.postDelayed({
                launchStealthOverlay(context)
            }, 100)
        }
    }
    
    private fun launchFakeShutdown(context: Context) {
        val intent = Intent(context, FakeShutdownActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_NO_HISTORY or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION
        }
        context.startActivity(intent)
    }
    
    private fun launchStealthOverlay(context: Context) {
        val intent = Intent(context, StealthOverlayActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_NO_HISTORY or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
        }
        context.startActivity(intent)
    }
}

