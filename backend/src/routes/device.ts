import { Router, Request, Response } from 'express';
import { body, validationResult } from 'express-validator';
import Device from '../models/Device';
import { authenticate } from '../middleware/auth';
import Log from '../models/Log';
import { LogType } from '../types';

const router = Router();

/**
 * POST /api/device/pair
 * Pair BLE/IoT device
 * Backend validates, Flutter handles BLE communication
 */
router.post(
  '/pair',
  authenticate,
  [
    body('deviceId').notEmpty().withMessage('Device ID is required'),
    body('deviceType').isIn(['BLE_DEVICE', 'IOT_BUTTON', 'WEARABLE']).withMessage('Invalid device type'),
    body('deviceName').optional().isString(),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { userId } = req.user!;
      const { deviceId, deviceType, deviceName, metadata } = req.body;

      // Check if device already paired
      let device = await Device.findOne({ deviceId, userId });

      if (device) {
        device.isActive = true;
        device.lastSeenAt = new Date();
        await device.save();
      } else {
        device = await Device.create({
          deviceId,
          userId,
          deviceType,
          deviceName,
          metadata,
        });
      }

      // Log pairing
      await Log.create({
        userId,
        deviceId: device._id,
        logType: LogType.DEVICE_PAIR,
        message: `Device paired: ${deviceId}`,
        metadata: { deviceType, deviceName },
      });

      res.status(201).json({
        success: true,
        message: 'Device paired successfully',
        device: {
          id: device._id,
          deviceId: device.deviceId,
          deviceType: device.deviceType,
        },
      });
    } catch (error: any) {
      console.error('Pair device error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * POST /api/device/validate-trigger
 * Validate device trigger (e.g., IoT button press)
 */
router.post(
  '/validate-trigger',
  authenticate,
  [body('deviceId').notEmpty().withMessage('Device ID is required')],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { userId } = req.user!;
      const { deviceId } = req.body;

      const device = await Device.findOne({
        deviceId,
        userId,
        isActive: true,
      });

      if (!device) {
        res.status(404).json({
          success: false,
          message: 'Device not found or inactive',
        });
        return;
      }

      // Update last seen
      device.lastSeenAt = new Date();
      await device.save();

      res.json({
        success: true,
        message: 'Device trigger validated',
        device: {
          id: device._id,
          deviceId: device.deviceId,
          deviceType: device.deviceType,
        },
      });
    } catch (error: any) {
      console.error('Validate trigger error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * GET /api/device/list
 * Get all paired devices for user
 */
router.get('/list', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId } = req.user!;

    const devices = await Device.find({
      userId,
      isActive: true,
    }).sort({ pairedAt: -1 });

    res.json({
      success: true,
      devices,
    });
  } catch (error: any) {
    console.error('List devices error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

export default router;

