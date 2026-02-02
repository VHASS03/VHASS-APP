import SOS from '../models/SOS';
import EmergencyContact from '../models/EmergencyContact';
import sosService from './sosService';
import Log from '../models/Log';
import { LogType } from '../types';
import axios from 'axios';

/**
 * Voice Detection Service
 * Handles audio processing and trigger word detection
 * Uses ML model running on Python Flask for accurate detection
 */
class VoiceService {
  // ML API endpoint (running on port 5001)
  private readonly ML_API_URL = process.env.ML_API_URL || 'http://localhost:5001';
  
  // Fallback trigger phrases (used if ML model is unavailable)
  private readonly FALLBACK_TRIGGER_PHRASES = ['help me out', 'help me', 'helpmout'];
  
  // ML model confidence threshold (0-1)
  private readonly ML_CONFIDENCE_THRESHOLD = parseFloat(process.env.ML_CONFIDENCE_THRESHOLD || '0.6');
  
  // Whether to use ML model or fallback pattern matching
  private readonly USE_ML_MODEL = process.env.USE_ML_MODEL !== 'false';

  /**
   * Detect trigger phrase using ML model
   * Falls back to pattern matching if ML service is unavailable
   */
  async detectTriggerPhrase(transcribedText: string): Promise<{
    triggered: boolean;
    confidence: number;
    method: string;
  }> {
    // Try ML model first
    if (this.USE_ML_MODEL) {
      try {
        const response = await axios.post(
          `${this.ML_API_URL}/predict`,
          {
            text: transcribedText,
            threshold: this.ML_CONFIDENCE_THRESHOLD
          },
          { timeout: 5000 }
        );

        if (response.data.success && response.data.data) {
          const result = response.data.data;
          console.log(`🤖 [ML] Prediction: "${transcribedText}" → trigger=${result.is_trigger} (conf=${result.confidence})`);
          
          return {
            triggered: result.is_trigger,
            confidence: result.confidence,
            method: 'ml_model'
          };
        }
      } catch (error: any) {
        console.warn(`⚠️ ML API unavailable: ${error.message}. Using fallback pattern matching.`);
      }
    }

    // Fallback: Pattern matching
    const lowerText = transcribedText.toLowerCase().trim();
    const triggered = this.FALLBACK_TRIGGER_PHRASES.some(phrase => 
      lowerText.includes(phrase)
    );

    if (triggered) {
      console.log(`✅ [Fallback] Voice trigger detected: "${transcribedText}"`);
    } else {
      console.log(`❌ [Fallback] No trigger phrase detected: "${transcribedText}"`);
    }

    return {
      triggered,
      confidence: triggered ? 1.0 : 0.0,
      method: 'pattern_matching'
    };
  }

  /**
   * Handle voice-triggered SOS
   * Automatically triggers SOS and initiates emergency contact calls
   */
  async handleVoiceTrigger(
    userId: string,
    deviceId: string,
    transcribedText: string,
    latitude?: number,
    longitude?: number
  ): Promise<{
    success: boolean;
    message: string;
    sosId?: string;
  }> {
    try {
      console.log(`🎤 Processing voice input: "${transcribedText}"`);

      // Check if trigger phrase is present using ML model
      const detection = await this.detectTriggerPhrase(transcribedText);
      
      if (!detection.triggered) {
        return {
          success: false,
          message: 'Trigger phrase not detected. Please say "help me out" to activate SOS.',
        };
      }

      // Get emergency contacts to verify they exist
      const contacts = await EmergencyContact.find({
        userId,
        isActive: true,
      }).sort({ priority: 1 });

      if (contacts.length === 0) {
        // Log voice trigger attempt but fail gracefully
        await Log.create({
          userId,
          logType: LogType.AUTH,
          message: 'Voice trigger detected but no emergency contacts configured',
          metadata: { transcribedText },
        });

        return {
          success: false,
          message: 'No emergency contacts configured. Please add emergency contacts first.',
        };
      }

      // Trigger SOS via existing sosService
      const sosResult = await sosService.triggerSOS(
        userId,
        deviceId,
        latitude && longitude ? { latitude, longitude } : undefined
      );

      // Log successful voice trigger with ML detection details
      await Log.create({
        userId,
        logType: LogType.SOS,
        message: `Voice-triggered SOS activated: "${transcribedText}" (${detection.method}, conf: ${detection.confidence})`,
        metadata: {
          sosId: sosResult.sosId,
          transcribedText,
          detectionMethod: detection.method,
          confidence: detection.confidence,
          contactsCount: contacts.length,
          deviceId,
        },
      });

      console.log(`🚨 Voice SOS triggered for user ${userId}. SOS ID: ${sosResult.sosId}`);
      console.log(`📞 Will contact ${contacts.length} emergency contacts in order of priority`);
      console.log(`📊 Detection: ${detection.method} (confidence: ${(detection.confidence * 100).toFixed(1)}%)`);

      return {
        success: true,
        message: `SOS activated! Contacting ${contacts.length} emergency contacts.`,
        sosId: sosResult.sosId,
      };
    } catch (error: any) {
      console.error('❌ Voice trigger error:', error.message);

      // Log the error
      await Log.create({
        userId,
        logType: LogType.SOS,
        message: `Voice trigger failed: ${error.message}`,
        metadata: { transcribedText, error: error.message },
      });

      return {
        success: false,
        message: error.message || 'Failed to process voice trigger',
      };
    }
  }

  /**
   * Add new trigger phrase (for future customization)
   */
  addTriggerPhrase(phrase: string): void {
    const normalizedPhrase = phrase.toLowerCase().trim();
    if (!this.TRIGGER_PHRASES.includes(normalizedPhrase)) {
      this.TRIGGER_PHRASES.push(normalizedPhrase);
      console.log(`➕ Added new trigger phrase: "${normalizedPhrase}"`);
    }
  }

  /**
   * Get current trigger phrases
   */
  getTriggerPhrases(): string[] {
    return [...this.TRIGGER_PHRASES];
  }
}

export default new VoiceService();
