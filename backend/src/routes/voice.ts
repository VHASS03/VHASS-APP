import { Router, Request, Response } from 'express';
import { body, validationResult } from 'express-validator';
import multer from 'multer';
import fs from 'fs';
import voiceService from '../services/voiceService';
import { authenticate } from '../middleware/auth';

const router = Router();
const upload = multer({ dest: 'uploads/' });

const EMOTION_API_URL = process.env.EMOTION_API_URL || 'http://localhost:5002';

/**
 * POST /api/voice/trigger
 * Send voice input (transcribed text) to trigger SOS
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
 * POST /api/voice/analyze-emotion
 * Accepts audio clip upload and forwards to local SpeechBrain service
 */
router.post(
  '/analyze-emotion',
  authenticate,
  upload.single('audio'),
  async (req: Request, res: Response): Promise<void> => {
    try {
      if (!req.file) {
        res.status(400).json({ success: false, message: 'Audio file is required' });
        return;
      }

      const filePath = req.file.path;
      console.log(`🎙️ [Voice] Forwarding file ${req.file.originalname} (${req.file.size} bytes) to local SpeechBrain API...`);

      // Read file into Buffer
      const fileBuffer = fs.readFileSync(filePath);
      
      // Native Blob & FormData (available in Node 22+)
      const blob = new Blob([fileBuffer], { type: 'audio/wav' });
      const formData = new FormData();
      formData.append('audio', blob, req.file.originalname || 'emergency_clip.wav');

      // Forward request to local Python FastAPI container running SpeechBrain
      const response = await fetch(`${EMOTION_API_URL}/analyze`, {
        method: 'POST',
        body: formData
      });

      // Cleanup local temp file
      try {
        fs.unlinkSync(filePath);
      } catch (unlinkErr) {
        console.warn('⚠️ Failed to delete temporary uploaded file:', unlinkErr);
      }

      if (!response.ok) {
        res.status(response.status).json({
          success: false,
          message: `SpeechBrain API returned error status ${response.status}`
        });
        return;
      }

      const data = await response.json() as any;
      
      if (data.success) {
        res.json({
          success: true,
          emotions: data.emotions
        });
      } else {
        res.status(500).json({
          success: false,
          message: data.message || 'SpeechBrain emotion analysis failed'
        });
      }
    } catch (error: any) {
      console.error('❌ Emotion analysis route error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to analyze audio clip emotion',
        error: process.env.NODE_ENV === 'development' ? error.message : undefined,
      });
    }
  }
);

/**
 * GET /api/voice/health
 * Check voice service status and get trigger phrases
 */
router.get('/health', authenticate, (_req: Request, res: Response): void => {
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
