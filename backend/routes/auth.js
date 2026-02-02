const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const { sendOTP } = require('../utils/otpService');
const { generateToken } = require('../utils/jwt');

// @route   POST /api/auth/send-otp
// @desc    Send OTP to phone number
// @access  Public
router.post('/send-otp', 
  [
    body('phone').isLength({ min: 10, max: 10 }).withMessage('Phone must be 10 digits'),
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ success: false, errors: errors.array() });
      }

      const { phone } = req.body;
  // Emit OTP via Socket.IO (no SMS gateway)
  const io = req.app.get('io');
  const otp = await sendOTP(phone, io);
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

      // Update or create user OTP
      await User.findOneAndUpdate(
        { phone },
        { 
          'otp.code': otp.otp,
          'otp.expiresAt': expiresAt
        },
        { upsert: true, new: true }
      );

      res.json({
        success: true,
        message: 'OTP sent via Socket.IO',
        // In development, return OTP for testing
        ...(process.env.NODE_ENV === 'development' && { otp: otp.otp })
      });
    } catch (error) {
      console.error('Send OTP error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// @route   POST /api/auth/verify-otp
// @desc    Verify OTP and login
// @access  Public
router.post('/verify-otp',
  [
    body('phone').isLength({ min: 10, max: 10 }).withMessage('Phone must be 10 digits'),
    body('otp').isLength({ min: 6, max: 6 }).withMessage('OTP must be 6 digits'),
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ success: false, errors: errors.array() });
      }

      const { phone, otp } = req.body;

      const user = await User.findOne({ phone });
      if (!user) {
        return res.status(404).json({ success: false, message: 'User not found' });
      }

      // Check if OTP matches and is not expired
      if (!user.otp || user.otp.code !== otp) {
        return res.status(400).json({ success: false, message: 'Invalid OTP' });
      }

      if (user.otp.expiresAt < new Date()) {
        return res.status(400).json({ success: false, message: 'OTP expired' });
      }

      // Mark phone as verified and clear OTP
      user.isPhoneVerified = true;
      user.otp = undefined;
      await user.save();

      // Generate JWT token
      const token = generateToken(user._id);

      res.json({
        success: true,
        message: 'OTP verified successfully',
        token,
        user: {
          id: user._id,
          name: user.name,
          phone: user.phone,
          email: user.email
        }
      });
    } catch (error) {
      console.error('Verify OTP error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// @route   POST /api/auth/signup
// @desc    Register new user
// @access  Public
router.post('/signup',
  [
    body('name').notEmpty().withMessage('Name is required'),
    body('phone').isLength({ min: 10, max: 10 }).withMessage('Phone must be 10 digits'),
    body('email').isEmail().withMessage('Please enter a valid email'),
    body('age').isInt({ min: 13 }).withMessage('Age must be at least 13'),
    body('occupation').notEmpty().withMessage('Occupation is required'),
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ success: false, errors: errors.array() });
      }

      const { name, phone, email, age, occupation, emergencyContacts } = req.body;

      // Check if user already exists
      const existingUser = await User.findOne({ $or: [{ phone }, { email }] });
      if (existingUser) {
        return res.status(400).json({ 
          success: false, 
          message: 'User with this phone or email already exists' 
        });
      }

      // Send OTP
      const otpResult = await sendOTP(phone);
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

      // Create user
      const user = new User({
        name,
        phone,
        email,
        age,
        occupation,
        'otp.code': otpResult.otp,
        'otp.expiresAt': expiresAt
      });

      await user.save();

      res.status(201).json({
        success: true,
        message: 'User created. Please verify OTP.',
        userId: user._id,
        // In development, return OTP for testing
        ...(process.env.NODE_ENV === 'development' && { otp: otpResult.otp })
      });
    } catch (error) {
      console.error('Signup error:', error);
      res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
  }
);

module.exports = router;


