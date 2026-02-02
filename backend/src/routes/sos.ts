import { Router, Request, Response } from 'express';
import { body, validationResult } from 'express-validator';
import sosService from '../services/sosService';
import { authenticate } from '../middleware/auth';

const router = Router();

/**
 * POST /api/sos/trigger
 * Trigger new SOS event
 * Returns instructions for device to execute (CALL/SMS)
 */
router.post(
  '/trigger',
  authenticate,
  [
    body('latitude').optional().isFloat().withMessage('Invalid latitude'),
    body('longitude').optional().isFloat().withMessage('Invalid longitude'),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { latitude, longitude } = req.body;
      const { userId, deviceId } = req.user!;

      const result = await sosService.triggerSOS(
        userId,
        deviceId,
        latitude && longitude ? { latitude, longitude } : undefined
      );

      // Send alerts to emergency contacts asynchronously (don't wait for it)
      sosService.notifyEmergencyContacts(
        result.sosId,
        userId,
        result.userName,
        latitude,
        longitude
      ).catch((err) => console.error('Failed to notify contacts:', err));

      res.status(201).json({
        success: true,
        message: 'SOS triggered successfully',
        sosId: result.sosId,
        instructions: result.instructions, // Device executes these
      });
    } catch (error: any) {
      if (error.message === 'SOS already active') {
        // Return existing SOS ID so client can use it
        const existingSOS = await sosService.getActiveSOS(req.user!.userId);
        res.status(409).json({ 
          success: false, 
          message: error.message,
          sosId: existingSOS?.sosId || null
        });
        return;
      }
      if (error.message === 'No emergency contacts configured') {
        res.status(400).json({ success: false, message: error.message });
        return;
      }
      console.error('Trigger SOS error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * POST /api/sos/update-location
 * Update SOS location (called periodically during active SOS)
 */
router.post(
  '/update-location',
  authenticate,
  [
    body('sosId').notEmpty().withMessage('SOS ID is required'),
    body('latitude').isFloat().withMessage('Invalid latitude'),
    body('longitude').isFloat().withMessage('Invalid longitude'),
    body('accuracy').optional().isFloat(),
    body('address').optional().isString(),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { sosId, latitude, longitude, accuracy, address } = req.body;
      
      console.log(`[POST /update-location] Received update for SOS ${sosId}:`, { latitude, longitude, accuracy, address });

      await sosService.updateLocation(sosId, {
        latitude,
        longitude,
        accuracy,
        address,
      });

      res.json({
        success: true,
        message: 'Location updated',
      });
    } catch (error: any) {
      console.error('[POST /update-location] Error:', error.message, error.stack);
      res.status(500).json({ 
        success: false, 
        message: 'Server error',
        error: error.message 
      });
    }
  }
);

/**
 * POST /api/sos/report-call-result
 * Device reports result of CALL/SMS instruction
 */
router.post(
  '/report-call-result',
  authenticate,
  [
    body('sosId').notEmpty().withMessage('SOS ID is required'),
    body('contactId').notEmpty().withMessage('Contact ID is required'),
    body('instructionType').isIn(['CALL', 'SMS']).withMessage('Invalid instruction type'),
    body('success').isBoolean().withMessage('Success must be boolean'),
    body('responded').optional().isBoolean(),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { sosId, contactId, instructionType, success, responded } = req.body;

      await sosService.reportCallResult(sosId, contactId, instructionType, success, responded || false);

      res.json({
        success: true,
        message: 'Call result recorded',
      });
    } catch (error: any) {
      console.error('Report call result error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * POST /api/sos/end
 * End SOS (resolve or cancel)
 * Cancellation ONLY allowed from same device
 */
router.post(
  '/end',
  authenticate,
  [
    body('sosId').notEmpty().withMessage('SOS ID is required'),
    body('reason').isIn(['RESOLVED', 'CANCELLED']).withMessage('Invalid reason'),
    body('latitude').optional().isFloat(),
    body('longitude').optional().isFloat(),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { sosId, reason, latitude, longitude } = req.body;
      const { deviceId } = req.user!;

      await sosService.endSOS(
        sosId,
        deviceId,
        reason,
        latitude && longitude ? { latitude, longitude } : undefined
      );

      res.json({
        success: true,
        message: `SOS ${reason.toLowerCase()} successfully`,
      });
    } catch (error: any) {
      if (error.message === 'SOS can only be cancelled from the triggering device') {
        res.status(403).json({ success: false, message: error.message });
        return;
      }
      if (error.message === 'SOS not found') {
        res.status(404).json({ success: false, message: error.message });
        return;
      }
      console.error('End SOS error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * GET /api/sos/status/:sosId
 * Get current SOS status
 */
router.get('/status/:sosId', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const { sosId } = req.params;
    const status = await sosService.getSOSStatus(sosId);

    if (!status) {
      res.status(404).json({ success: false, message: 'SOS not found' });
      return;
    }

    res.json({
      success: true,
      status,
    });
  } catch (error: any) {
    console.error('Get SOS status error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * POST /api/sos/deactivate-with-pin
 * Deactivate SOS by verifying user's PIN
 */
router.post(
  '/deactivate-with-pin',
  authenticate,
  [
    body('sosId').notEmpty().withMessage('SOS ID is required'),
    body('pin').notEmpty().withMessage('PIN is required'),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { sosId, pin } = req.body;
      const { userId, deviceId } = req.user!;

      // Verify PIN and deactivate SOS
      const result = await sosService.deactivateWithPIN(sosId, userId, deviceId, pin);

      res.json({
        success: true,
        message: 'SOS deactivated successfully',
        sos: result,
      });
    } catch (error: any) {
      if (error.message === 'Invalid PIN') {
        res.status(401).json({ success: false, message: error.message });
        return;
      }
      if (error.message === 'SOS not found') {
        res.status(404).json({ success: false, message: error.message });
        return;
      }
      if (error.message === 'SOS already ended') {
        res.status(400).json({ success: false, message: error.message });
        return;
      }
      console.error('Deactivate with PIN error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * PUT /api/sos/set-pin
 * Set user's custom SOS deactivation PIN
 */
router.put(
  '/set-pin',
  authenticate,
  [
    body('pin').notEmpty().withMessage('PIN is required').isLength({ min: 4, max: 6 }).withMessage('PIN must be 4-6 digits'),
    body('pin').matches(/^\d+$/).withMessage('PIN must contain only digits'),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { pin } = req.body;
      const { userId } = req.user!;

      // Set custom PIN
      await sosService.setSosPin(userId, pin);

      res.json({
        success: true,
        message: 'SOS PIN updated successfully',
      });
    } catch (error: any) {
      console.error('Set SOS PIN error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

export default router;

