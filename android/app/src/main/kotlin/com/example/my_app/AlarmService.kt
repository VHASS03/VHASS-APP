package com.example.my_app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * Alarm Service
 * 
 * Plays LOUD alarm sound that:
 * 1. Overrides silent/vibrate mode
 * 2. Plays at maximum volume
 * 3. Vibrates continuously
 * 4. Keeps playing until explicitly stopped
 * 
 * Used for emergency SOS alerts to contacts
 */
class AlarmService(private val context: Context) {
    
    companion object {
        const val TAG = "AlarmService"
    }
    
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var originalVolume: Int = 0
    private var originalRingerMode: Int = AudioManager.RINGER_MODE_NORMAL
    private val handler = Handler(Looper.getMainLooper())
    private var isPlaying = false
    
    /**
     * Play emergency alarm sound
     * @param durationMs How long to play (0 = until stopped)
     * @param vibrate Whether to also vibrate
     */
    fun playAlarm(durationMs: Long = 30000, vibrate: Boolean = true) {
        if (isPlaying) {
            Log.d(TAG, "Alarm already playing")
            return
        }
        
        isPlaying = true
        Log.d(TAG, "🔊 Starting emergency alarm (${durationMs}ms)")
        
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            // Save original settings
            originalVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            originalRingerMode = audioManager.ringerMode
            
            // Set to maximum volume and override silent mode
            audioManager.setStreamVolume(
                AudioManager.STREAM_ALARM,
                audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                0
            )
            
            // Get alarm sound
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            
            // Create and configure MediaPlayer
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(context, alarmUri)
                isLooping = true  // Keep playing until stopped
                prepare()
                start()
            }
            
            Log.d(TAG, "🔊 Alarm sound started")
            
            // Start vibration
            if (vibrate) {
                startVibration()
            }
            
            // Auto-stop after duration (if specified)
            if (durationMs > 0) {
                handler.postDelayed({
                    stopAlarm()
                }, durationMs)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error playing alarm: ${e.message}")
            isPlaying = false
        }
    }
    
    /**
     * Start continuous vibration pattern
     */
    private fun startVibration() {
        try {
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            
            // Long continuous vibration pattern: vibrate 1s, pause 0.5s, repeat
            val pattern = longArrayOf(0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0)) // 0 = repeat from index 0
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
            
            Log.d(TAG, "📳 Vibration started")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error starting vibration: ${e.message}")
        }
    }
    
    /**
     * Stop the alarm and restore settings
     */
    fun stopAlarm() {
        if (!isPlaying) return
        
        Log.d(TAG, "🔇 Stopping alarm")
        
        try {
            // Stop media player
            mediaPlayer?.apply {
                if (isPlaying) {
                    stop()
                }
                release()
            }
            mediaPlayer = null
            
            // Stop vibration
            vibrator?.cancel()
            vibrator = null
            
            // Restore original volume
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, originalVolume, 0)
            
            isPlaying = false
            Log.d(TAG, "✅ Alarm stopped")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping alarm: ${e.message}")
        }
    }
    
    /**
     * Check if alarm is currently playing
     */
    fun isAlarmPlaying(): Boolean = isPlaying
}

