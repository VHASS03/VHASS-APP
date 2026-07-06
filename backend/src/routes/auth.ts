import { Router, Request, Response } from 'express';
import { body, validationResult } from 'express-validator';
import mongoose from 'mongoose';
import User from '../models/User';
import Device from '../models/Device';
import EmergencyContact from '../models/EmergencyContact';
import { DeviceType } from '../types';
import redisClient from '../config/redis';
import { generateOTP, validateOTPFormat } from '../utils/otp';
import { sendSms } from '../utils/sms';
import { generateToken } from '../utils/jwt';
import Log from '../models/Log';
import { LogType } from '../types';

const router = Router();

/**
 * POST /api/auth/signup
 * Register new user with details and emergency contacts
 * Creates user with unverified status and sends OTP
 */
router.post(
  '/signup',
  [
    body('name').notEmpty().withMessage('Name is required'),
    body('phone').isLength({ min: 10, max: 10 }).withMessage('Phone must be 10 digits'),
    body('email').optional().isEmail().withMessage('Please enter a valid email'),
    body('age').optional().isInt({ min: 13 }).withMessage('Age must be at least 13'),
    body('occupation').optional().notEmpty(),
    body('emergencyContacts').optional().isArray().withMessage('Emergency contacts must be an array'),
    body('emergencyContacts.*.name').optional().notEmpty(),
    body('emergencyContacts.*.phone').optional().isLength({ min: 10, max: 10 }),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { name, phone, email, age, occupation, emergencyContacts } = req.body;

      // Log incoming data for debugging
      console.log('📥 Signup request data:', {
        name,
        phone,
        email,
        age,
        occupation,
        emergencyContactsCount: emergencyContacts?.length || 0,
      });

      // Check database connection with explicit verification
      if (mongoose.connection.readyState !== 1) {
        console.error('❌ Database not connected. ReadyState:', mongoose.connection.readyState);
        res.status(503).json({
          success: false,
          message: 'Database connection error. Please try again.',
        });
        return;
      }

      // Verify MongoDB connection is actually working by running a test query
      try {
        await mongoose.connection.db.admin().ping();
        console.log('✅ MongoDB connection verified');
      } catch (pingError) {
        console.error('❌ MongoDB ping failed:', pingError);
        res.status(503).json({
          success: false,
          message: 'Database connection error. Please try again.',
        });
        return;
      }

      // Check if user already exists
      const existingUser = await User.findOne({ phone });
      if (existingUser) {
        res.status(400).json({
          success: false,
          message: 'User with this phone number already exists',
        });
        return;
      }

      // Validate emergency contacts (max 3)
      if (emergencyContacts && emergencyContacts.length > 3) {
        res.status(400).json({
          success: false,
          message: 'Maximum 3 emergency contacts allowed',
        });
        return;
      }

      // Generate OTP
      const otp = generateOTP(6);
      const expirySeconds = parseInt(process.env.OTP_EXPIRY_SECONDS || '600');

      // Store OTP in Redis (don't fail signup if Redis is unavailable)
      try {
        await redisClient.storeOTP(phone, otp, expirySeconds);
        console.log('✅ OTP stored in Redis');
      } catch (redisError: any) {
        console.warn('⚠️ Failed to store OTP in Redis (continuing anyway):', redisError.message);
        // Continue with signup even if Redis fails - OTP will be returned in response for development
      }

      // Create user with unverified status
      let user;
      try {
        const userData: any = {
          phone,
          name,
          isPhoneVerified: false,
        };

        // Only add optional fields if they have values
        if (email && email.trim()) {
          userData.email = email.trim();
        }
        if (age) {
          const parsedAge = typeof age === 'string' ? parseInt(age, 10) : age;
          if (!isNaN(parsedAge) && parsedAge > 0) {
            userData.age = parsedAge;
          }
        }
        if (occupation && occupation.trim()) {
          userData.occupation = occupation.trim();
        }

        console.log('📝 Creating user with data:', userData);
        console.log('📝 MongoDB connection state:', mongoose.connection.readyState);
        console.log('📝 MongoDB connection name:', mongoose.connection.name);
        
        user = await User.create(userData);
        console.log(`✅ User created successfully: ${user._id}`);
        
        // Force save to ensure data is persisted
        await user.save();
        console.log(`✅ User saved to database: ${user._id}`);
        
        // Verify user was saved by querying the database
        const savedUser = await User.findById(user._id);
        if (!savedUser) {
          throw new Error('User was not saved to database - verification query returned null');
        }
        console.log(`✅ Verified user exists in DB: ${savedUser._id}, phone: ${savedUser.phone}, name: ${savedUser.name}`);
      } catch (createError: any) {
        console.error('❌ User creation failed:', createError);
        console.error('❌ Error name:', createError.name);
        console.error('❌ Error code:', createError.code);
        console.error('❌ Error message:', createError.message);
        console.error('❌ MongoDB connection state:', mongoose.connection.readyState);
        
        // Handle MongoDB connection errors
        if (createError.name === 'MongoServerError' || createError.name === 'MongoNetworkError') {
          console.error('❌ MongoDB server/network error detected');
          res.status(503).json({
            success: false,
            message: 'Database connection error. Please try again.',
            error: process.env.NODE_ENV === 'development' ? createError.message : undefined,
          });
          return;
        }
        
        // Handle duplicate key error
        if (createError.code === 11000) {
          const duplicateField = Object.keys(createError.keyPattern || {})[0];
          res.status(400).json({
            success: false,
            message: `User with this ${duplicateField} already exists`,
          });
          return;
        }
        
        // Handle validation errors
        if (createError.name === 'ValidationError') {
          const validationErrors = Object.values(createError.errors).map((err: any) => err.message);
          res.status(400).json({
            success: false,
            message: 'Validation error',
            errors: validationErrors,
          });
          return;
        }
        
        throw createError; // Re-throw to be caught by outer catch
      }

      // Create emergency contacts (inactive until OTP verification)
      if (emergencyContacts && emergencyContacts.length > 0) {
        const contactPromises = emergencyContacts.map((contact: any, index: number) =>
          EmergencyContact.create({
            userId: user._id,
            name: contact.name,
            phone: contact.phone,
            priority: index + 1,
            isActive: false, // Will be activated after OTP verification
          })
        );

        const contacts = await Promise.all(contactPromises);
        user.emergencyContacts = contacts.map((c) => c._id);
        await user.save();
      }

      // Log signup
      await Log.create({
        userId: user._id,
        logType: LogType.AUTH,
        message: `User signed up: ${phone}`,
        metadata: { phone, name },
      });

      // Attempt SMS delivery from backend (e.g., Twilio)
      const otpMessage = `Your VHASS verification code is: ${otp}. Valid for ${expirySeconds / 60} minutes.`;
      const smsResult = await sendSms(phone, otpMessage);

      // IMPORTANT: Still return OTP for app fallback (dev/testing)
      console.log(`📱 Signup OTP for ${phone}: ${otp}`);
      res.status(201).json({
        success: true,
        message: 'User created. OTP sent via SMS and real-time Socket.IO',
        userId: user._id,
        data: {
          otp, // Return OTP for app fallback (dev/testing)
          smsSent: smsResult.sent,
          smsProvider: smsResult.provider,
        },
      });
    } catch (error: any) {
      console.error('❌ Signup error:', error);
      console.error('Error details:', {
        message: error.message,
        name: error.name,
        code: error.code,
        stack: error.stack,
      });
      res.status(500).json({
        success: false,
        message: 'Server error',
        error: process.env.NODE_ENV === 'development' ? error.message : undefined,
      });
    }
  }
);

/**
 * POST /api/auth/send-otp
 * Send OTP to phone number
 * OTP stored in Redis with expiry
 * OTP delivered via:
 * 1. Socket.IO in real-time (to specific device only, not all devices with same phone)
 * 2. SMS via app (as fallback for users without active Socket.IO)
 * 3. Returned in response (for development/testing)
 * 
 * IMPORTANT: Only send to requesting device, not all devices with same phone
 * This prevents OTP being sent to multiple devices on shared phone numbers
 */
router.post(
  '/send-otp',
  [
    body('phone').isLength({ min: 10, max: 10 }).withMessage('Phone must be 10 digits'),
    body('deviceId').optional().isString().withMessage('Device ID must be string'),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { phone, deviceId } = req.body;

      // Generate OTP
      const otp = generateOTP(6);
      const expirySeconds = parseInt(process.env.OTP_EXPIRY_SECONDS || '600');

      // Store in Redis (NOT MongoDB)
      await redisClient.storeOTP(phone, otp, expirySeconds);

      // Log OTP send (don't log the OTP itself)
      await Log.create({
        logType: LogType.AUTH,
        message: `OTP sent to ${phone}${deviceId ? ` (device: ${deviceId})` : ''}`,
        metadata: { phone, deviceId },
      });

      // Send OTP via Socket.IO to SPECIFIC device only (not all devices with same phone)
      const io = req.app.get('io');
      let socketIOSuccessful = false;
      
      if (io && deviceId) {
        // Send to specific device only to prevent multiple sends on shared numbers
        const deviceRoom = `device:${deviceId}`;
        io.to(deviceRoom).emit('auth:otp-received', {
          phone,
          otp,
          expiresIn: expirySeconds,
          message: `Your VHASS verification code is: ${otp}. Valid for ${expirySeconds / 60} minutes.`,
        });
        console.log(`📱 OTP sent via Socket.IO to device ${deviceId}: ${otp}`);
        socketIOSuccessful = true;
      } else if (io && !deviceId) {
        // Fallback: Send to phone room if no deviceId provided
        const otpRoom = `otp:${phone}`;
        io.to(otpRoom).emit('auth:otp-received', {
          phone,
          otp,
          expiresIn: expirySeconds,
          message: `Your VHASS verification code is: ${otp}. Valid for ${expirySeconds / 60} minutes.`,
        });
        console.log(`📱 OTP sent via Socket.IO to phone ${phone}: ${otp}`);
        socketIOSuccessful = true;
      } else {
        console.warn('⚠️  Socket.IO not available - OTP will be sent via SMS fallback only');
      }

      // Attempt SMS delivery from backend (e.g., Twilio)
      const otpMessage = `Your VHASS verification code is: ${otp}. Valid for ${expirySeconds / 60} minutes.`;
      const smsResult = await sendSms(phone, otpMessage);

      // Console log for server visibility
      console.log(`📱 OTP for ${phone}: ${otp}`);

      // IMPORTANT: Always return OTP for app to send via SMS
      // This ensures OTP delivery even if Socket.IO connection fails
      res.json({
        success: true,
        message: socketIOSuccessful 
          ? 'OTP sent successfully via Socket.IO and SMS fallback'
          : 'OTP sent via SMS (Socket.IO unavailable)',
        data: {
          otp, // Return OTP for app fallback (dev/testing)
          smsSent: smsResult.sent,
          smsProvider: smsResult.provider,
        },
      });
    } catch (error: any) {
      console.error('Send OTP error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * POST /api/auth/verify-otp
 * Verify OTP and create/login user
 * Requires deviceId for device binding
 */
router.post(
  '/verify-otp',
  [
    body('phone').isLength({ min: 10, max: 10 }).withMessage('Phone must be 10 digits'),
    body('otp').custom(validateOTPFormat).withMessage('OTP must be 6 digits'),
    body('deviceId').notEmpty().withMessage('Device ID is required'),
    body('deviceType').isIn(Object.values(DeviceType)).withMessage('Invalid device type'),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { phone, otp, deviceId, deviceType, deviceName, metadata } = req.body;

      // Verify OTP from Redis
      const isValid = await redisClient.verifyOTP(phone, otp);
      if (!isValid) {
        res.status(401).json({ success: false, message: 'Invalid or expired OTP' });
        return;
      }

      // Find user
      const user = await User.findOne({ phone });
      if (!user) {
        res.status(404).json({
          success: false,
          message: 'User not found. Please sign up first.',
        });
        return;
      }

      // Verify phone and activate emergency contacts if they exist
      user.isPhoneVerified = true;
      await user.save();

      // Activate only emergency contacts that were just created at signup (not user-deleted ones)
      // User-deleted contacts stay isActive: false; only activate if created in the last 15 minutes
      const signupWindowMs = 15 * 60 * 1000;
      const signupCutoff = new Date(Date.now() - signupWindowMs);
      if (user.emergencyContacts && user.emergencyContacts.length > 0) {
        await EmergencyContact.updateMany(
          {
            userId: user._id,
            isActive: false,
            createdAt: { $gte: signupCutoff },
          },
          { $set: { isActive: true } }
        );
      }

      // Find or create device
      let device = await Device.findOne({ deviceId, userId: user._id });
      if (!device) {
        device = await Device.create({
          deviceId,
          userId: user._id,
          deviceType,
          deviceName,
          metadata,
          lastSeenAt: new Date(),
        });

        // Add device to user
        user.devices.push(device._id);
        await user.save();

        // Log device pairing
        await Log.create({
          userId: user._id,
          deviceId: device._id,
          logType: LogType.DEVICE_PAIR,
          message: `Device paired: ${deviceId}`,
          metadata: { deviceType, deviceName },
        });
      } else {
        device.lastSeenAt = new Date();
        device.isActive = true;
        await device.save();
      }

      // Generate JWT token
      const token = generateToken({
        userId: user._id.toString(),
        deviceId,
        phone: user.phone,
      });

      // Store session in Redis
      await redisClient.setDeviceSession(user._id.toString(), deviceId, token, 2592000); // 30 days

      // Log successful login
      await Log.create({
        userId: user._id,
        deviceId: device._id,
        logType: LogType.AUTH,
        message: 'User logged in',
        metadata: { deviceId },
      });

      res.json({
        success: true,
        message: 'OTP verified successfully',
        token,
        user: {
          id: user._id,
          phone: user.phone,
          name: user.name,
          email: user.email,
        },
        device: {
          id: device._id,
          deviceId: device.deviceId,
          deviceType: device.deviceType,
        },
      });
    } catch (error: any) {
      console.error('Verify OTP error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

export default router;

