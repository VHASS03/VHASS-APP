const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const User = require('../models/User');

// @route   GET /api/user/profile
// @desc    Get user profile
// @access  Private
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.user._id)
      .populate('emergencyContacts')
      .select('-otp -emergencyPin');

    res.json({
      success: true,
      user
    });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @route   PUT /api/user/profile
// @desc    Update user profile
// @access  Private
router.put('/profile', authMiddleware, async (req, res) => {
  try {
    const { name, email, age, occupation } = req.body;
    const updates = {};

    if (name) updates.name = name;
    if (email) updates.email = email;
    if (age) updates.age = age;
    if (occupation) updates.occupation = occupation;

    const user = await User.findByIdAndUpdate(
      req.user._id,
      { $set: updates },
      { new: true, runValidators: true }
    ).select('-otp -emergencyPin');

    res.json({
      success: true,
      message: 'Profile updated successfully',
      user
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @route   PUT /api/user/location
// @desc    Update user location
// @access  Private
router.put('/location', authMiddleware, async (req, res) => {
  try {
    const { latitude, longitude, address } = req.body;

    if (!latitude || !longitude) {
      return res.status(400).json({ 
        success: false, 
        message: 'Latitude and longitude are required' 
      });
    }

    const user = await User.findByIdAndUpdate(
      req.user._id,
      {
        $set: {
          'location.latitude': latitude,
          'location.longitude': longitude,
          'location.address': address || '',
          'location.lastUpdated': new Date()
        }
      },
      { new: true }
    ).select('-otp -emergencyPin');

    res.json({
      success: true,
      message: 'Location updated successfully',
      location: user.location
    });
  } catch (error) {
    console.error('Update location error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @route   POST /api/user/emergency-pin
// @desc    Set emergency PIN
// @access  Private
router.post('/emergency-pin', authMiddleware, async (req, res) => {
  try {
    const { pin } = req.body;

    if (!pin || pin.length < 4) {
      return res.status(400).json({ 
        success: false, 
        message: 'PIN must be at least 4 digits' 
      });
    }

    const user = await User.findByIdAndUpdate(
      req.user._id,
      { emergencyPin: pin },
      { new: true }
    ).select('-otp -emergencyPin');

    res.json({
      success: true,
      message: 'Emergency PIN set successfully'
    });
  } catch (error) {
    console.error('Set emergency PIN error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;


