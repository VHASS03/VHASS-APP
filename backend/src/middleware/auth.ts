import { Request, Response, NextFunction } from 'express';
import { verifyToken } from '../utils/jwt';
import Device from '../models/Device';

/**
 * Authentication Middleware
 * Verifies JWT token and ensures device binding
 */
export const authenticate = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        success: false,
        message: 'No token provided',
      });
      return;
    }

    const token = authHeader.substring(7);
    const decoded = verifyToken(token);

    if (!decoded) {
      res.status(401).json({
        success: false,
        message: 'Invalid or expired token',
      });
      return;
    }

    // Verify device exists and is active
    const device = await Device.findOne({
      deviceId: decoded.deviceId,
      userId: decoded.userId,
      isActive: true,
    });

    if (!device) {
      res.status(401).json({
        success: false,
        message: 'Device not found or inactive',
      });
      return;
    }

    // Update last seen
    device.lastSeenAt = new Date();
    await device.save();

    // Attach user info to request
    req.user = {
      userId: decoded.userId,
      deviceId: decoded.deviceId,
      phone: decoded.phone,
    };

    next();
  } catch (error) {
    console.error('Auth middleware error:', error);
    res.status(500).json({
      success: false,
      message: 'Authentication error',
    });
  }
};

// Extend Express Request type
declare global {
  namespace Express {
    interface Request {
      user?: {
        userId: string;
        deviceId: string;
        phone: string;
      };
    }
  }
}

