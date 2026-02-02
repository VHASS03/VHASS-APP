const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const EmergencyAlert = require('../models/EmergencyAlert');
const EmergencyContact = require('../models/EmergencyContact');
const User = require('../models/User');

// @route   POST /api/emergency/activate
// @desc    Activate emergency alert
// @access  Private
router.post('/activate', authMiddleware, async (req, res) => {
  try {
    const { latitude, longitude, address, batteryLevel } = req.body;
    const userId = req.user._id;

    // Check if user already has an active emergency
    const activeAlert = await EmergencyAlert.findOne({
      userId,
      status: 'active'
    });

    if (activeAlert) {
      return res.status(400).json({
        success: false,
        message: 'Emergency alert already active'
      });
    }

    // Get user's emergency contacts
    const contacts = await EmergencyContact.find({
      userId,
      isActive: true
    }).sort({ priority: 1 });

    if (contacts.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No emergency contacts found. Please add at least one contact.'
      });
    }

    // Create emergency alert
    const alert = new EmergencyAlert({
      userId,
      location: {
        latitude: latitude || req.user.location?.latitude || 0,
        longitude: longitude || req.user.location?.longitude || 0,
        address: address || ''
      },
      batteryLevel: batteryLevel || 100,
      contactsNotified: contacts.map(contact => ({
        contactId: contact._id,
        notifiedAt: new Date()
      }))
    });

    await alert.save();

    // Update user's emergency status
    await User.findByIdAndUpdate(userId, {
      isEmergencyActive: true,
      'location.latitude': latitude || req.user.location?.latitude,
      'location.longitude': longitude || req.user.location?.longitude,
      'location.lastUpdated': new Date()
    });

    // Emit real-time notification via Socket.IO
    const io = req.app.get('io');
    io.to(`user-${userId}`).emit('emergency-activated', {
      alertId: alert._id,
      location: alert.location,
      contactsNotified: contacts.length
    });

    // Notify emergency contacts (in a real app, you'd send SMS/call here)
    contacts.forEach(contact => {
      io.emit('emergency-notification', {
        userId,
        userName: req.user.name,
        userPhone: req.user.phone,
        location: alert.location,
        contactPhone: contact.phone
      });
    });

    res.status(201).json({
      success: true,
      message: 'Emergency alert activated',
      alert: {
        id: alert._id,
        location: alert.location,
        batteryLevel: alert.batteryLevel,
        contactsNotified: contacts.length,
        startedAt: alert.startedAt
      }
    });
  } catch (error) {
    console.error('Activate emergency error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @route   POST /api/emergency/update-location
// @desc    Update emergency alert location
// @access  Private
router.post('/update-location', authMiddleware, async (req, res) => {
  try {
    const { latitude, longitude, address, batteryLevel } = req.body;
    const userId = req.user._id;

    const alert = await EmergencyAlert.findOne({
      userId,
      status: 'active'
    });

    if (!alert) {
      return res.status(404).json({
        success: false,
        message: 'No active emergency alert found'
      });
    }

    alert.location = {
      latitude: latitude || alert.location.latitude,
      longitude: longitude || alert.location.longitude,
      address: address || alert.location.address
    };

    if (batteryLevel !== undefined) {
      alert.batteryLevel = batteryLevel;
    }

    await alert.save();

    // Update user location
    await User.findByIdAndUpdate(userId, {
      'location.latitude': alert.location.latitude,
      'location.longitude': alert.location.longitude,
      'location.lastUpdated': new Date()
    });

    // Emit location update
    const io = req.app.get('io');
    io.to(`user-${userId}`).emit('location-updated', {
      alertId: alert._id,
      location: alert.location
    });

    res.json({
      success: true,
      message: 'Location updated',
      location: alert.location
    });
  } catch (error) {
    console.error('Update location error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @route   POST /api/emergency/cancel
// @desc    Cancel emergency alert
// @access  Private
router.post('/cancel', authMiddleware, async (req, res) => {
  try {
    const { pin } = req.body;
    const userId = req.user._id;

    // Verify PIN if provided
    if (pin) {
      const user = await User.findById(userId).select('+emergencyPin');
      const isValidPin = await user.verifyEmergencyPin(pin);
      
      if (!isValidPin) {
        return res.status(401).json({
          success: false,
          message: 'Invalid PIN'
        });
      }
    }

    const alert = await EmergencyAlert.findOne({
      userId,
      status: 'active'
    });

    if (!alert) {
      return res.status(404).json({
        success: false,
        message: 'No active emergency alert found'
      });
    }

    alert.status = 'cancelled';
    alert.cancelledAt = new Date();
    await alert.save();

    // Update user's emergency status
    await User.findByIdAndUpdate(userId, {
      isEmergencyActive: false
    });

    // Emit cancellation notification
    const io = req.app.get('io');
    io.to(`user-${userId}`).emit('emergency-cancelled', {
      alertId: alert._id
    });

    res.json({
      success: true,
      message: 'Emergency alert cancelled'
    });
  } catch (error) {
    console.error('Cancel emergency error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @route   GET /api/emergency/status
// @desc    Get current emergency status
// @access  Private
router.get('/status', authMiddleware, async (req, res) => {
  try {
    const alert = await EmergencyAlert.findOne({
      userId: req.user._id,
      status: 'active'
    }).populate('contactsNotified.contactId', 'name phone');

    if (!alert) {
      return res.json({
        success: true,
        isActive: false,
        message: 'No active emergency'
      });
    }

    res.json({
      success: true,
      isActive: true,
      alert: {
        id: alert._id,
        location: alert.location,
        batteryLevel: alert.batteryLevel,
        contactsNotified: alert.contactsNotified,
        startedAt: alert.startedAt,
        elapsedTime: Math.floor((new Date() - alert.startedAt) / 1000) // seconds
      }
    });
  } catch (error) {
    console.error('Get emergency status error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @route   GET /api/emergency/history
// @desc    Get emergency alert history
// @access  Private
router.get('/history', authMiddleware, async (req, res) => {
  try {
    const alerts = await EmergencyAlert.find({
      userId: req.user._id
    })
      .sort({ createdAt: -1 })
      .limit(20)
      .populate('contactsNotified.contactId', 'name phone');

    res.json({
      success: true,
      alerts
    });
  } catch (error) {
    console.error('Get emergency history error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;


