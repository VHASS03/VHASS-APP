const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const authMiddleware = require('../middleware/auth');
const EmergencyContact = require('../models/EmergencyContact');
const User = require('../models/User');

// @route   GET /api/contacts
// @desc    Get all emergency contacts
// @access  Private
router.get('/', authMiddleware, async (req, res) => {
  try {
    const contacts = await EmergencyContact.find({
      userId: req.user._id,
      isActive: true
    }).sort({ priority: 1 });

    res.json({
      success: true,
      contacts
    });
  } catch (error) {
    console.error('Get contacts error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @route   POST /api/contacts
// @desc    Add emergency contact
// @access  Private
router.post('/',
  authMiddleware,
  [
    body('name').notEmpty().withMessage('Name is required'),
    body('phone').isLength({ min: 10, max: 10 }).withMessage('Phone must be 10 digits'),
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ success: false, errors: errors.array() });
      }

      // Check if user already has 3 contacts
      const contactCount = await EmergencyContact.countDocuments({
        userId: req.user._id,
        isActive: true
      });

      if (contactCount >= 3) {
        return res.status(400).json({
          success: false,
          message: 'Maximum 3 emergency contacts allowed'
        });
      }

      const { name, phone } = req.body;

      // Check if contact already exists
      const existingContact = await EmergencyContact.findOne({
        userId: req.user._id,
        phone,
        isActive: true
      });

      if (existingContact) {
        return res.status(400).json({
          success: false,
          message: 'Contact with this phone number already exists'
        });
      }

      // Determine priority (next available priority)
      const priority = contactCount + 1;

      const contact = new EmergencyContact({
        userId: req.user._id,
        name,
        phone,
        priority
      });

      await contact.save();

      // Add to user's emergency contacts array
      await User.findByIdAndUpdate(req.user._id, {
        $push: { emergencyContacts: contact._id }
      });

      res.status(201).json({
        success: true,
        message: 'Emergency contact added successfully',
        contact
      });
    } catch (error) {
      console.error('Add contact error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// @route   PUT /api/contacts/:id
// @desc    Update emergency contact
// @access  Private
router.put('/:id',
  authMiddleware,
  [
    body('name').optional().notEmpty().withMessage('Name cannot be empty'),
    body('phone').optional().isLength({ min: 10, max: 10 }).withMessage('Phone must be 10 digits'),
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ success: false, errors: errors.array() });
      }

      const { name, phone } = req.body;
      const contactId = req.params.id;

      const contact = await EmergencyContact.findOne({
        _id: contactId,
        userId: req.user._id
      });

      if (!contact) {
        return res.status(404).json({
          success: false,
          message: 'Contact not found'
        });
      }

      if (name) contact.name = name;
      if (phone) contact.phone = phone;

      await contact.save();

      res.json({
        success: true,
        message: 'Contact updated successfully',
        contact
      });
    } catch (error) {
      console.error('Update contact error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// @route   DELETE /api/contacts/:id
// @desc    Delete emergency contact
// @access  Private
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    const contactId = req.params.id;

    const contact = await EmergencyContact.findOne({
      _id: contactId,
      userId: req.user._id
    });

    if (!contact) {
      return res.status(404).json({
        success: false,
        message: 'Contact not found'
      });
    }

    // Soft delete
    contact.isActive = false;
    await contact.save();

    // Remove from user's emergency contacts array
    await User.findByIdAndUpdate(req.user._id, {
      $pull: { emergencyContacts: contactId }
    });

    // Reorder remaining contacts
    const remainingContacts = await EmergencyContact.find({
      userId: req.user._id,
      isActive: true
    }).sort({ priority: 1 });

    for (let i = 0; i < remainingContacts.length; i++) {
      remainingContacts[i].priority = i + 1;
      await remainingContacts[i].save();
    }

    res.json({
      success: true,
      message: 'Contact deleted successfully'
    });
  } catch (error) {
    console.error('Delete contact error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @route   PUT /api/contacts/:id/priority
// @desc    Update contact priority
// @access  Private
router.put('/:id/priority', authMiddleware, async (req, res) => {
  try {
    const { priority } = req.body;
    const contactId = req.params.id;

    if (!priority || priority < 1 || priority > 3) {
      return res.status(400).json({
        success: false,
        message: 'Priority must be between 1 and 3'
      });
    }

    const contact = await EmergencyContact.findOne({
      _id: contactId,
      userId: req.user._id
    });

    if (!contact) {
      return res.status(404).json({
        success: false,
        message: 'Contact not found'
      });
    }

    // Swap priorities if needed
    const existingContact = await EmergencyContact.findOne({
      userId: req.user._id,
      priority,
      isActive: true,
      _id: { $ne: contactId }
    });

    if (existingContact) {
      existingContact.priority = contact.priority;
      await existingContact.save();
    }

    contact.priority = priority;
    await contact.save();

    res.json({
      success: true,
      message: 'Priority updated successfully',
      contact
    });
  } catch (error) {
    console.error('Update priority error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;


