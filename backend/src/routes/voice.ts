import { Router, Request, Response } from 'express';
import { body, validationResult } from 'express-validator';
import voiceService from '../services/voiceService';
import { authenticate } from '../middleware/auth';

const router = Router();

/**
 * POST /api/voice/trigger
 * Send voice input (transcribed text) to trigger SOS
 * 
 * Expected flow:
 * 1. App records audio
 * 2. App sends transcribed text (from device speech-to-text or server-side)
 * 3. Server detects "help me out" phrase
 * 4. If detected: automatically triggers SOS and notifies emergency contacts
 * 
 * Request body:
 * {
 *   "text": "help me out, I'm in an emergency",
 *   "latitude": 28.6139,
 *   "longitude": 77.2090,
 *   "confidence": 0.95
 * }
 */
router.post(
  '/trigger',
  authenticate,
  [
    body('text')
      .notEmpty().withMessage('Text is required')
      .isString().withMessage('Text must be a string')
      .isLength({ min: 3, max: 500 }).withMessage('Text must be between 3 and 500 characters'),
    body('latitude')
      .optional()
      .isFloat({ min: -90, max: 90 }).withMessage('Invalid latitude'),
    body('longitude')
      .optional()
      .isFloat({ min: -180, max: 180 }).withMessage('Invalid longitude'),
    body('confidence')
      .optional()
      .isFloat({ min: 0, max: 1 }).withMessage('Confidence must be between 0 and 1'),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { text, latitude, longitude, confidence } = req.body;
      const { userId, deviceId } = req.user!;

      console.log(`🎤 [Voice] Received from ${userId}: "${text}" (confidence: ${confidence || 'N/A'})`);

      // Process voice input and check for trigger phrase
      const result = await voiceService.handleVoiceTrigger(
        userId,
        deviceId,
        text,
        latitude,
        longitude
      );

      if (result.success) {
        res.status(201).json({
          success: true,
          message: result.message,
          sosId: result.sosId,
          triggered: true,
        });
      } else {
        res.status(400).json({
          success: false,
          message: result.message,
          triggered: false,
        });
      }
    } catch (error: any) {
      console.error('❌ Voice trigger error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to process voice input',
        error: process.env.NODE_ENV === 'development' ? error.message : undefined,
      });
    }
  }
);

/**
 * GET /api/voice/health
 * Check voice service status and get trigger phrases
 */
router.get('/health', authenticate, (req: Request, res: Response): void => {
  try {
    const triggers = voiceService.getTriggerPhrases();
    res.json({
      success: true,
      message: 'Voice service is healthy',
      triggerPhrases: triggers,
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      message: 'Voice service error',
      error: error.message,
    });
  }
});

export default router;
